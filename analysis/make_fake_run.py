#!/usr/bin/env python3
"""Write one FAKE run in the exact spec 14 format, for building and testing the analysis.

The simulator does not export yet, so this is a small seeded agent model:
NPCs get households, homes, jobs and schools from data/buildings.json, follow an
hourly schedule (home / work / school / outings to restaurants, malls, nightclubs,
friends), meet each other inside buildings (busy, mobile places like malls meet more)
and on the street, and an SEIR process with the spec 11 timers runs on those contacts.

It is NOT the simulator: contacts are sampled per building-hour instead of measured
from positions. Only the file format and the internal consistency are exact:
  * seir.csv has one row per tick (ticks 0 .. days*ticks_per_day-1), S+E+I+R == population.
  * infections.csv has one row per S->E, plus patient zeros at tick 0 with infector = -1.
  * npcs.csv first_infected_tick == earliest infections.csv row for that NPC (else -1),
    contact_count == number of contacts.csv rows the NPC appears in.

Usage:
  python analysis/make_fake_run.py --out output/baseline/run_0 --days 30 --seed 1000
  python analysis/make_fake_run.py --out output/malls_closed/run_0 --days 30 --seed 1000 --close-malls
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
MAP_PATH = ROOT / "data" / "map.png"
BUILDINGS_PATH = ROOT / "data" / "buildings.json"

# Spec 02 tile colours in data/map.png.
ROAD_RGB = (0x3A, 0x3A, 0x3A)
SIDEWALK_RGB = (0xA0, 0xA0, 0xA0)

# Fake-model knobs (not simulator config; only shape the fake data).
HOUSEHOLD_WEIGHTS = [0.30, 0.30, 0.20, 0.15, 0.05]  # sizes 1..5 (spec 05)
OCCUPATIONS = ["STUDENT", "WORKER", "NONE"]
OCCUPATION_SHARES = [0.15, 0.65, 0.20]               # spec 05
CAR_SHARE = 0.6                                      # spec 05
# New encounters per pair per hour = ENCOUNTER_RATE * mobility / area_in_tiles (capped).
ENCOUNTER_RATE = 30.0
PAIR_RATE_CAP = 1.5
MOBILITY = {"home": 1.0, "workplace": 1.0, "school": 1.5, "restaurant": 2.0,
            "nightclub": 4.0, "mall": 4.0, "outside": 0.25}
SLEEP_MOBILITY = 0.05
OUTSIDE_CELL = 8  # tiles; street encounters are grouped per 8x8 cell
# Mean minutes a fake encounter stays in range (drives the infection probability).
ENCOUNTER_MINUTES = {"home": 40.0, "workplace": 35.0, "school": 30.0, "restaurant": 35.0,
                     "nightclub": 40.0, "mall": 35.0, "outside": 5.0}
CAR_TRIP_MIN_TILES = 30.0


def default_config(args: argparse.Namespace, name: str) -> dict:
    """Fully resolved config (spec 14 config.json), keys as in config/default.json + spec 13."""
    return {
        "name": name,
        "seed": args.seed,
        "tick_seconds": args.tick_seconds,
        "days": args.days,
        "population": args.population,
        "ticks_per_frame": 1,
        "map_path": "res://data/map.png",
        "buildings_path": "res://data/buildings.json",
        "virus": {
            "infection_radius_m": 2.0,
            "transmission_prob_per_min": args.p,
            "incubation_days": 1,
            "infection_days": 3,
            "immunity_days": 5,
            "car_transmission_multiplier": 0.1,
        },
        "patient_zero": {"mode": "random", "count": args.patient_zeros},
        "closed_buildings": {"ids": [], "purposes": ["mall"] if args.close_malls else []},
        "immune_share": args.immune_share,
        "fake": True,
    }


class City:
    def __init__(self) -> None:
        data = json.loads(BUILDINGS_PATH.read_text())
        self.buildings = data["buildings"]
        n = len(self.buildings)
        self.rect = np.array([b["rect"] for b in self.buildings], dtype=float)  # x, y, w, h
        self.entrance = np.array([b["entrance"] for b in self.buildings], dtype=float) + 0.5
        self.area = self.rect[:, 2] * self.rect[:, 3]
        self.island = np.array([b["island"] for b in self.buildings])
        self.home_cap = np.array([b["home_capacity"] for b in self.buildings])
        self.jobs = np.array([b["jobs"] for b in self.buildings])
        # Main purpose decides the fake mobility; mixed home+restaurant counts as restaurant.
        main = []
        for b in self.buildings:
            p = b["purposes"]
            main.append(next((q for q in ("mall", "nightclub", "restaurant", "school", "workplace")
                              if q in p), "home"))
        self.main = np.array(main)
        self.ids_with = lambda purpose: np.array(
            [b["id"] for b in self.buildings if purpose in b["purposes"]], dtype=int)
        self.mobility = np.array([MOBILITY[m] for m in main])
        self.minutes = np.array([ENCOUNTER_MINUTES[m] for m in main])
        assert n == len(main)
        # Nearest road / sidewalk tile for every tile (to keep street events on the street).
        import matplotlib.image as mpimg
        img = (mpimg.imread(MAP_PATH)[:, :, :3] * 255).round().astype(int)  # [y, x, rgb]
        road = np.all(img == ROAD_RGB, axis=2)
        side = np.all(img == SIDEWALK_RGB, axis=2)
        _, self.near_road = ndimage.distance_transform_edt(~road, return_indices=True)
        _, self.near_side = ndimage.distance_transform_edt(~side, return_indices=True)


def build_population(city: City, rng: np.random.Generator, population: int) -> dict:
    sizes = []
    while sum(sizes) < population:
        sizes.append(int(rng.choice(5, p=HOUSEHOLD_WEIGHTS)) + 1)
    sizes[-1] -= sum(sizes) - population
    free = city.home_cap.copy()
    household_home = []
    for s in sizes:
        cand = np.flatnonzero(free >= s)
        if len(cand) == 0:
            cand = np.flatnonzero(free > 0)
        h = int(rng.choice(cand))
        free[h] -= s
        household_home.append(h)
    household = np.repeat(np.arange(len(sizes)), sizes)
    home = np.array(household_home)[household]
    occupation = rng.choice(OCCUPATIONS, size=population, p=OCCUPATION_SHARES)
    work = np.full(population, -1)
    free_jobs = city.jobs.copy()
    for i in np.flatnonzero(occupation == "WORKER"):
        cand = np.flatnonzero(free_jobs > 0)
        w = int(rng.choice(cand))
        free_jobs[w] -= 1
        work[i] = w
    schools = city.ids_with("school")
    school = np.full(population, -1)
    for i in np.flatnonzero(occupation == "STUDENT"):
        d = np.linalg.norm(city.entrance[schools] - city.entrance[home[i]], axis=1)
        school[i] = schools[int(np.argmin(d))]
    household_car = rng.random(len(sizes)) < CAR_SHARE
    return {"household": household, "home": home, "occupation": occupation,
            "work": work, "school": school, "has_car": household_car[household]}


def day_schedule(city: City, pop: dict, rng: np.random.Generator, day: int,
                 closed: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Per NPC and hour: building id (-1 = outside), and for outside hours the trip src/dst."""
    n = len(pop["home"])
    home = pop["home"]
    loc = np.repeat(home[:, None], 24, axis=1)
    src = np.full((n, 24), -1)
    dst = np.full((n, 24), -1)
    weekday = day % 7 < 5

    def go(mask: np.ndarray, start: np.ndarray, length: np.ndarray, where: np.ndarray) -> None:
        for i in np.flatnonzero(mask):
            s, e, b = int(start[i]), int(min(24, start[i] + length[i])), int(where[i])
            if s - 1 >= 0 and loc[i, s - 1] == home[i]:
                loc[i, s - 1], src[i, s - 1], dst[i, s - 1] = -1, home[i], b
            loc[i, s:e] = b
            if e < 24:
                loc[i, e], src[i, e], dst[i, e] = -1, b, home[i]

    occ = pop["occupation"]
    if weekday:
        w = (occ == "WORKER") & ~closed[np.maximum(pop["work"], 0)]
        go(w, np.full(n, 8), np.full(n, 9), pop["work"])
        s = (occ == "STUDENT") & ~closed[np.maximum(pop["school"], 0)]
        go(s, np.full(n, 8), np.full(n, 7), pop["school"])

    malls = city.ids_with("mall")
    restaurants = city.ids_with("restaurant")
    clubs = city.ids_with("nightclub")
    homes = city.ids_with("home")

    def outing(free_mask: np.ndarray, starts: tuple[int, int], weights: dict) -> None:
        kinds = list(weights)
        options = {"mall": malls, "restaurant": restaurants, "nightclub": clubs, "friend": homes}
        options = {k: v[~closed[v]] for k, v in options.items()}
        wts = np.array([weights[k] for k in kinds])
        kind = rng.choice(len(kinds), size=n, p=wts / wts.sum())
        where = np.zeros(n, dtype=int)
        free_mask = free_mask.copy()
        for k_i, k in enumerate(kinds):
            m = kind == k_i
            if not m.any():
                continue
            if len(options[k]):
                where[m] = rng.choice(options[k], size=int(m.sum()))
            else:
                free_mask[m] = False  # every building of that kind is closed: stay home
        start = rng.integers(starts[0], starts[1] + 1, size=n)
        length = rng.integers(2, 4, size=n)
        # Only if the whole outing (plus travel) fits in free time at home.
        ok = free_mask.copy()
        for i in np.flatnonzero(ok):
            s, e = start[i] - 1, min(24, start[i] + length[i] + 1)
            if np.any(loc[i, s:e] != home[i]):
                ok[i] = False
        go(ok, start, length, where)

    all_npcs = np.ones(n, dtype=bool)
    if not weekday:
        outing(all_npcs & (rng.random(n) < 0.55), (11, 15),
               {"mall": 0.45, "restaurant": 0.25, "friend": 0.30})
    else:
        outing((occ == "NONE") & (rng.random(n) < 0.5), (10, 14),
               {"mall": 0.40, "restaurant": 0.30, "friend": 0.30})
    outing(all_npcs & (rng.random(n) < 0.45), (18, 20),
           {"restaurant": 0.35, "mall": 0.25, "friend": 0.25,
            "nightclub": 0.15 if not weekday else 0.06})
    return loc, src, dst


def sample_pairs(rng: np.random.Generator, group: np.ndarray, rate: np.ndarray
                 ) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Members (indices into `group`'s source array) grouped by key; returns (gidx, i, j)."""
    order = np.argsort(group, kind="stable")
    keys, starts, counts = np.unique(group[order], return_index=True, return_counts=True)
    pairs = counts * (counts - 1) / 2.0
    lam = pairs * rate[order][starts]
    k = rng.poisson(lam)
    g = np.repeat(np.arange(len(keys)), k)
    nn = counts[g]
    il = np.floor(rng.random(len(g)) * nn).astype(int)
    jl = (il + 1 + np.floor(rng.random(len(g)) * (nn - 1)).astype(int)) % nn
    a = order[starts[g] + il]
    b = order[starts[g] + jl]
    return g, a, b


def simulate(args: argparse.Namespace) -> dict:
    rng = np.random.default_rng(args.seed)
    city = City()
    pop = build_population(city, rng, args.population)
    n = args.population
    tick_seconds = args.tick_seconds
    tph = 3600 // tick_seconds
    tpd = 24 * tph
    total_ticks = args.days * tpd

    closed = np.zeros(len(city.buildings), dtype=bool)
    if args.close_malls:
        closed[city.main == "mall"] = True

    # Seeded steps in spec 13 order: population -> immune share -> patient zero.
    immune = np.zeros(n, dtype=bool)
    n_imm = int(round(args.immune_share * n))
    if n_imm:
        immune[rng.choice(n, size=n_imm, replace=False)] = True
    pz = np.sort(rng.choice(np.flatnonzero(~immune), size=args.patient_zeros, replace=False))

    # SEIR state: 0 S, 1 E, 2 I, 3 R. Durations in ticks; S never times out.
    S, E, I, R = 0, 1, 2, 3
    v = default_config(args, "")["virus"]
    inf_dur = [10**12, v["incubation_days"] * tpd, v["infection_days"] * tpd,
               v["immunity_days"] * tpd]
    nxt = [S, I, R, S]
    state = [S] * n
    since = [0] * n
    for i in np.flatnonzero(immune):
        state[i] = R
    delta = np.zeros((total_ticks + 1, 4), dtype=np.int64)
    init = np.zeros(4, dtype=np.int64)

    def due(i: int) -> int:
        if state[i] == R and immune[i]:
            return 10**12
        return since[i] + inf_dur[state[i]]

    def advance(i: int, upto: int) -> None:
        """Apply every timer of NPC i due at a tick <= upto (recorded at its exact tick)."""
        d = due(i)
        while d <= upto:
            s = state[i]
            delta[d, s] -= 1
            delta[d, nxt[s]] += 1
            state[i], since[i] = nxt[s], d
            d = due(i)

    p = v["transmission_prob_per_min"]
    car_mult = v["car_transmission_multiplier"]

    inf_rows: list[tuple] = []
    for i in pz:
        state[i], since[i] = I, 0
        bx, by, bw, bh = city.rect[pop["home"][i]]
        inf_rows.append((0, -1, int(i), round(bx + rng.random() * bw, 2),
                         round(by + rng.random() * bh, 2), int(pop["home"][i]), 0))
    for s in state:
        init[s] += 1

    contact_chunks = []
    all_idx = np.arange(n)
    for day in range(args.days):
        loc, src, dst = day_schedule(city, pop, rng, day, closed)
        # --- indoor groups: key = hour * B + building
        B = len(city.buildings)
        hh = np.repeat(np.arange(24)[None, :], n, axis=0)
        npc = np.repeat(all_idx[:, None], 24, axis=1)
        inside = loc >= 0
        bl, hl, nl = loc[inside], hh[inside], npc[inside]
        sleep = (hl < 7) | (hl >= 23)
        mob = city.mobility[bl] * np.where(sleep & (city.main[bl] == "home"), SLEEP_MOBILITY, 1.0)
        rate = np.minimum(PAIR_RATE_CAP, ENCOUNTER_RATE * mob / city.area[bl])
        g, ia, ib = sample_pairs(rng, hl * B + bl, rate)
        ev_b = bl[ia]
        ev_h = hl[ia]
        ev_a, ev_b_npc = nl[ia], nl[ib]
        rx, ry, rw, rh = (city.rect[ev_b, k] for k in range(4))
        ux, uy = rng.random(len(ev_b)), rng.random(len(ev_b))
        # Malls have a busy central court: half the events cluster near the middle.
        court = (city.main[ev_b] == "mall") & (rng.random(len(ev_b)) < 0.5)
        ux = np.where(court, np.clip(0.5 + rng.normal(0, 0.08, len(ev_b)), 0, 0.999), ux)
        uy = np.where(court, np.clip(0.5 + rng.normal(0, 0.08, len(ev_b)), 0, 0.999), uy)
        in_x, in_y = rx + ux * rw, ry + uy * rh
        in_car = np.zeros(len(ev_b), dtype=bool)
        in_minutes = city.minutes[ev_b]

        # --- outdoor groups: position along the trip, snapped to sidewalk / road.
        out = loc < 0
        ho, no = hh[out], npc[out]
        s_b, d_b = src[out], dst[out]
        a_xy, b_xy = city.entrance[s_b], city.entrance[d_b]
        dist = np.linalg.norm(b_xy - a_xy, axis=1)
        car = pop["has_car"][no] & (dist > CAR_TRIP_MIN_TILES)
        t = rng.random(len(no))[:, None]
        pos = a_xy + t * (b_xy - a_xy)
        tx = np.clip(pos[:, 0].astype(int), 0, 255)
        ty = np.clip(pos[:, 1].astype(int), 0, 255)
        sy = np.where(car, city.near_road[0][ty, tx], city.near_side[0][ty, tx])
        sx = np.where(car, city.near_road[1][ty, tx], city.near_side[1][ty, tx])
        ox = sx + rng.random(len(no))
        oy = sy + rng.random(len(no))
        cell = (sy // OUTSIDE_CELL) * (256 // OUTSIDE_CELL) + sx // OUTSIDE_CELL
        orate = np.full(len(no), min(PAIR_RATE_CAP, ENCOUNTER_RATE * MOBILITY["outside"]
                                     / OUTSIDE_CELL**2))
        if len(no) > 1:
            _, oa, ob = sample_pairs(rng, ho * 10**6 + cell, orate)
        else:
            oa = ob = np.zeros(0, dtype=int)
        out_x = (ox[oa] + ox[ob]) / 2
        out_y = (oy[oa] + oy[ob]) / 2
        out_car = car[oa] | car[ob]

        a = np.concatenate([ev_a, no[oa]])
        b = np.concatenate([ev_b_npc, no[ob]])
        hour = np.concatenate([ev_h, ho[oa]])
        x = np.concatenate([in_x, out_x])
        y = np.concatenate([in_y, out_y])
        bid = np.concatenate([ev_b, np.full(len(oa), -1)])
        incar = np.concatenate([in_car, out_car])
        mins = np.concatenate([in_minutes, np.full(len(oa), ENCOUNTER_MINUTES["outside"])])
        tick = day * tpd + hour * tph + rng.integers(0, tph, size=len(a))
        lo, hi = np.minimum(a, b), np.maximum(a, b)
        order = np.lexsort((hi, lo, tick))
        lo, hi, tick, x, y, bid, incar, mins = (arr[order] for arr in
                                               (lo, hi, tick, x, y, bid, incar, mins))
        dur = np.maximum(1.0, rng.exponential(mins))
        p_eff = np.where(incar, p * car_mult, p)
        p_inf = 1.0 - (1.0 - p_eff) ** dur  # p is per minute, dur in minutes
        draw = rng.random(len(lo))
        contact_chunks.append((tick, lo, hi, x, y, bid, incar))

        # --- SEIR over this day's contacts, hour by hour (only possible I-S pairs in Python).
        st = np.array(state)
        sn = np.array(since)
        for h in range(24):
            h0 = day * tpd + h * tph
            h1 = h0 + tph - 1
            sel = np.flatnonzero((tick >= h0) & (tick <= h1))
            if not len(sel):
                continue
            d_all = sn + np.array(inf_dur)[st]
            d_all = np.where((st == R) & immune, 10**12, d_all)
            could_i = (st == I) | ((st == E) & (d_all <= h1))
            could_s = (st == S) | ((st == R) & (d_all <= h1))
            la, lb = lo[sel], hi[sel]
            cand = sel[(could_i[la] & could_s[lb]) | (could_i[lb] & could_s[la])]
            changed = False
            for e in cand:
                t_e = int(tick[e])
                ia_, ib_ = int(lo[e]), int(hi[e])
                advance(ia_, t_e - 1)  # transmission happens before this tick's timers
                advance(ib_, t_e - 1)
                if state[ia_] == I and state[ib_] == S:
                    src_i, dst_i = ia_, ib_
                elif state[ib_] == I and state[ia_] == S:
                    src_i, dst_i = ib_, ia_
                else:
                    continue
                if draw[e] < p_inf[e]:
                    delta[t_e, S] -= 1
                    delta[t_e, E] += 1
                    state[dst_i], since[dst_i] = E, t_e
                    inf_rows.append((t_e, src_i, dst_i, round(float(x[e]), 2),
                                     round(float(y[e]), 2), int(bid[e]), int(incar[e])))
                    changed = True
            # Refresh the vectorized snapshot for the next hour (timers up to h1).
            st_now, sn_now = np.array(state), np.array(since)
            d_now = sn_now + np.array(inf_dur)[st_now]
            d_now = np.where((st_now == R) & immune, 10**12, d_now)
            for i in np.flatnonzero(d_now <= h1):
                advance(int(i), h1)
                changed = True
            if changed:
                st = np.array(state)
                sn = np.array(since)
    for i in range(n):
        advance(i, total_ticks - 1)

    counts = init[None, :] + np.cumsum(delta[:total_ticks], axis=0)
    ticks = np.arange(total_ticks)
    seconds = ticks * tick_seconds
    seir = pd.DataFrame({
        "tick": ticks, "day": seconds // 86400, "hour": (seconds % 86400) // 3600,
        "S": counts[:, 0], "E": counts[:, 1], "I": counts[:, 2], "R": counts[:, 3],
        "immune_forever": np.full(total_ticks, int(immune.sum())),
    })

    cols = list(zip(*contact_chunks)) if contact_chunks else [[]] * 7
    contacts = pd.DataFrame({
        "tick": np.concatenate(cols[0]), "a": np.concatenate(cols[1]),
        "b": np.concatenate(cols[2]), "x": np.concatenate(cols[3]).round(2),
        "y": np.concatenate(cols[4]).round(2), "building_id": np.concatenate(cols[5]),
        "in_car": np.concatenate(cols[6]).astype(int),
    })
    infections = pd.DataFrame(inf_rows, columns=["tick", "infector", "infected", "x", "y",
                                                 "building_id", "in_car"])
    infections = infections.sort_values("tick", kind="stable").reset_index(drop=True)

    contact_count = np.bincount(contacts["a"], minlength=n) + np.bincount(contacts["b"], minlength=n)
    first = np.full(n, -1)
    firsts = infections.groupby("infected")["tick"].min()
    first[firsts.index.to_numpy()] = firsts.to_numpy()
    npcs = pd.DataFrame({
        "id": np.arange(n), "household_id": pop["household"], "home_id": pop["home"],
        "occupation": pop["occupation"], "work_id": pop["work"], "school_id": pop["school"],
        "has_car": pop["has_car"].astype(int), "immune_forever": immune.astype(int),
        "contact_count": contact_count, "first_infected_tick": first,
    })
    return {"seir": seir, "contacts": contacts, "infections": infections, "npcs": npcs}


def write_run(out: Path, config: dict, tables: dict) -> None:
    out.mkdir(parents=True, exist_ok=True)
    (out / "config.json").write_text(json.dumps(config, indent="\t") + "\n")
    for name in ("seir", "contacts", "infections", "npcs"):
        tables[name].to_csv(out / f"{name}.csv", index=False, lineterminator="\n",
                            float_format="%.2f")


def main(argv: list[str] | None = None) -> Path:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", required=True, help="run folder, e.g. output/baseline/run_0")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--seed", type=int, default=1000)
    ap.add_argument("--population", type=int, default=1000)
    ap.add_argument("--patient-zeros", type=int, default=1)
    ap.add_argument("--immune-share", type=float, default=0.0)
    ap.add_argument("--close-malls", action="store_true")
    ap.add_argument("--p", type=float, default=0.001, help="transmission_prob_per_min")
    ap.add_argument("--tick-seconds", type=int, default=60)
    ap.add_argument("--name", default=None, help="experiment name (default: parent folder)")
    args = ap.parse_args(argv)
    if 3600 % args.tick_seconds:
        ap.error("--tick-seconds must divide 3600")
    out = Path(args.out)
    name = args.name or out.resolve().parent.name
    tables = simulate(args)
    write_run(out, default_config(args, name), tables)
    s = tables["seir"]
    peak = s["I"].idxmax()
    print(f"{out}: {len(s)} ticks, {len(tables['contacts'])} contacts, "
          f"{len(tables['infections'])} infections, peak I {s['I'].max()} on day "
          f"{s['tick'][peak] * args.tick_seconds / 86400:.1f}")
    return out


if __name__ == "__main__":
    main()
