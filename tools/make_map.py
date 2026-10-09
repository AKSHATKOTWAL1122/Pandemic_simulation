#!/usr/bin/env python3
"""Generate the city once: data/map.png (one pixel per tile) and data/buildings.json.

The outputs are committed and may be hand-edited afterwards.
Usage: python3 tools/make_map.py [--seed N]
"""
import argparse
import json
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SIZE = 256
WATER, ROAD, SIDEWALK, BUILDING = 0, 1, 2, 3
COLOURS = {
    WATER: (0x1E, 0x4A, 0x8C),
    ROAD: (0x3A, 0x3A, 0x3A),
    SIDEWALK: (0xA0, 0xA0, 0xA0),
    BUILDING: (0xC8, 0xB4, 0x8C),
}

# Inclusive bounds (x0, y0, x1, y1). Border water is 6 tiles; channels are 8 tiles wide.
ISLANDS = [
    (6, 6, 123, 249),     # 0: west
    (132, 6, 249, 123),   # 1: north-east
    (132, 132, 249, 249), # 2: south-east
]
V_CHANNEL = (124, 131)  # x range between island 0 and islands 1-2
H_CHANNEL = (124, 131)  # y range between islands 1 and 2

STREET = "SRRS"  # sidewalk, road, road, sidewalk
BLOCK_MIN, BLOCK_MAX = 12, 24
LOT_W_MIN, LOT_W_MAX = 5, 9

RESTAURANTS = 15
NIGHTCLUBS = 6
MIXED_HOME_RESTAURANT = 4
WORKPLACE_SHARE = 0.35
WORKER_SHARE = 0.65  # spec 05 occupation share


def axis_layout(start, end, rng):
    """Kinds per coordinate ('S', 'R', 'B') and block ranges, from start to end inclusive."""
    total = end - start + 1
    for _ in range(10000):
        sizes = []
        remaining = total - len(STREET)
        ok = False
        while True:
            if BLOCK_MIN + len(STREET) <= remaining <= BLOCK_MAX + len(STREET):
                sizes.append(remaining - len(STREET))
                ok = True
                break
            hi = min(BLOCK_MAX, remaining - len(STREET) - (BLOCK_MIN + len(STREET)))
            if hi < BLOCK_MIN:
                break
            b = rng.randint(BLOCK_MIN, hi)
            sizes.append(b)
            remaining -= b + len(STREET)
        if ok:
            break
    else:
        raise SystemExit(f"cannot lay out axis {start}..{end}")

    kinds = {}
    blocks = []
    pos = start
    for i, c in enumerate(STREET):
        kinds[pos + i] = c
    pos += len(STREET)
    for b in sizes:
        for i in range(b):
            kinds[pos + i] = "B"
        blocks.append((pos, pos + b - 1))
        pos += b
        for i, c in enumerate(STREET):
            kinds[pos + i] = c
        pos += len(STREET)
    assert pos == end + 1
    return kinds, blocks


def road_pairs(kinds, lo, hi):
    """First coordinate of each 2-wide road whose whole street lies within lo..hi."""
    return [p for p in sorted(kinds) if kinds[p] == "R" and kinds.get(p + 1) == "R" and lo <= p - 1 and p + 2 <= hi]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()
    rng = random.Random(args.seed)

    config = json.loads((ROOT / "config/default.json").read_text())
    population = int(config["population"])

    grid = [[WATER] * SIZE for _ in range(SIZE)]
    layouts = []
    for x0, y0, x1, y1 in ISLANDS:
        kx, bx = axis_layout(x0, x1, rng)
        ky, by = axis_layout(y0, y1, rng)
        layouts.append((kx, ky, bx, by))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                a, b = kx[x], ky[y]
                if a == "R" or b == "R":
                    grid[y][x] = ROAD
                elif a == "S" or b == "S":
                    grid[y][x] = SIDEWALK
                else:
                    grid[y][x] = BUILDING

    # Bridges: straight 2-wide road with a sidewalk on each side, spanning a channel.
    bridges = []

    def horizontal_bridge(y):
        for x in range(V_CHANNEL[0] - 1, V_CHANNEL[1] + 2):
            grid[y - 1][x] = SIDEWALK
            grid[y][x] = ROAD
            grid[y + 1][x] = ROAD
            grid[y + 2][x] = SIDEWALK
        bridges.append([V_CHANNEL[0], y - 1, V_CHANNEL[1] - V_CHANNEL[0] + 1, 4])

    def vertical_bridge(x):
        for y in range(H_CHANNEL[0] - 1, H_CHANNEL[1] + 2):
            grid[y][x - 1] = SIDEWALK
            grid[y][x] = ROAD
            grid[y][x + 1] = ROAD
            grid[y][x + 2] = SIDEWALK
        bridges.append([x - 1, H_CHANNEL[0], 4, H_CHANNEL[1] - H_CHANNEL[0] + 1])

    west_rows = layouts[0][1]
    north_rows = [p for p in road_pairs(west_rows, 16, 113)]
    south_rows = [p for p in road_pairs(west_rows, 142, 239)]
    ne_cols = [p for p in road_pairs(layouts[1][0], 142, 239)]
    for y in pick_spread(rng, north_rows, 2):
        horizontal_bridge(y)
    for y in pick_spread(rng, south_rows, 1):
        horizontal_bridge(y)
    for x in pick_spread(rng, ne_cols, 2):
        vertical_bridge(x)

    # Blocks -> buildings.
    island_blocks = []
    for island_id, (kx, ky, bx, by) in enumerate(layouts):
        for (ya, yb) in by:
            for (xa, xb) in bx:
                island_blocks.append((island_id, xa, ya, xb, yb))

    def block_area(b):
        return (b[3] - b[1] + 1) * (b[4] - b[2] + 1)

    malls = []
    for island_id in (0, 2):
        candidates = [b for b in island_blocks if b[0] == island_id and block_area(b) >= 256]
        malls.append(rng.choice(candidates))
    schools = []
    for island_id in (0, 1, 2):
        candidates = [b for b in island_blocks if b[0] == island_id and b not in malls and block_area(b) >= 196]
        schools.append(rng.choice(candidates))

    buildings = []

    def add(island_id, xa, ya, xb, yb, entrance, purposes):
        buildings.append({
            "island": island_id,
            "rect": [xa, ya, xb - xa + 1, yb - ya + 1],
            "entrance": list(entrance),
            "purposes": purposes,
        })

    for block in island_blocks:
        island_id, xa, ya, xb, yb = block
        if block in malls or block in schools:
            purpose = "mall" if block in malls else "school"
            add(island_id, xa, ya, xb, yb, ((xa + xb) // 2, ya), [purpose])
            continue
        mid = ya + (yb - ya + 1) // 2
        for (ra, rb, top) in ((ya, mid - 1, True), (mid, yb, False)):
            for (la, lb) in split_lots(xa, xb, rng):
                entrance = ((la + lb) // 2, ra if top else rb)
                add(island_id, la, ra, lb, rb, entrance, None)

    lots = [b for b in buildings if b["purposes"] is None]
    rng.shuffle(lots)
    i = 0
    for count, purposes in ((RESTAURANTS, ["restaurant"]), (NIGHTCLUBS, ["nightclub"]),
                            (MIXED_HOME_RESTAURANT, ["home", "restaurant"])):
        for b in lots[i:i + count]:
            b["purposes"] = purposes
        i += count
    rest = lots[i:]
    n_work = round(len(rest) * WORKPLACE_SHARE)
    for b in rest[:n_work]:
        b["purposes"] = ["workplace"]
    for b in rest[n_work:]:
        b["purposes"] = ["home"]

    for b in buildings:
        w, h = b["rect"][2], b["rect"][3]
        area = w * h
        p = b["purposes"]
        b["home_capacity"] = max(2, area // 10) if "home" in p else 0
        if "mall" in p:
            jobs = 60
        elif "school" in p:
            jobs = 25
        elif "nightclub" in p:
            jobs = 10
        elif "restaurant" in p:
            jobs = 8
        elif "workplace" in p:
            jobs = max(4, area // 5)
        else:
            jobs = 0
        b["jobs"] = jobs

    buildings.sort(key=lambda b: (b["rect"][1], b["rect"][0]))
    out_buildings = []
    for new_id, b in enumerate(buildings):
        out_buildings.append({
            "id": new_id,
            "island": b["island"],
            "rect": b["rect"],
            "entrance": b["entrance"],
            "purposes": b["purposes"],
            "home_capacity": b["home_capacity"],
            "jobs": b["jobs"],
        })

    homes = sum(b["home_capacity"] for b in out_buildings)
    jobs = sum(b["jobs"] for b in out_buildings)
    assert homes >= 1.2 * population, f"home capacity {homes} < 1.2 x {population}"
    assert jobs >= WORKER_SHARE * population, f"jobs {jobs} < workers {WORKER_SHARE * population}"

    img = Image.new("RGB", (SIZE, SIZE))
    img.putdata([COLOURS[grid[y][x]] for y in range(SIZE) for x in range(SIZE)])
    (ROOT / "data").mkdir(exist_ok=True)
    img.save(ROOT / "data/map.png")

    meta = {
        "seed": args.seed,
        "islands": [{"id": i, "rect": [x0, y0, x1 - x0 + 1, y1 - y0 + 1]} for i, (x0, y0, x1, y1) in enumerate(ISLANDS)],
        "bridges": [{"id": i, "rect": r} for i, r in enumerate(bridges)],
        "buildings": out_buildings,
    }
    (ROOT / "data/buildings.json").write_text(json.dumps(meta, indent=1) + "\n")

    counts = {}
    for b in out_buildings:
        key = "+".join(b["purposes"])
        counts[key] = counts.get(key, 0) + 1
    print(f"{len(out_buildings)} buildings, home capacity {homes}, jobs {jobs}, bridges {len(bridges)}")
    print("by purpose:", dict(sorted(counts.items())))


def split_lots(xa, xb, rng):
    """Split xa..xb into lots LOT_W_MIN..LOT_W_MAX wide."""
    lots = []
    pos = xa
    while pos <= xb:
        remaining = xb - pos + 1
        if remaining <= LOT_W_MAX:
            w = remaining
        else:
            w = rng.randint(LOT_W_MIN, min(LOT_W_MAX, remaining - LOT_W_MIN))
        lots.append((pos, pos + w - 1))
        pos += w
    return lots


def pick_spread(rng, options, count):
    """Pick count options spread out: the middle of each equal slice of the sorted list."""
    options = sorted(options)
    assert len(options) >= count, "not enough road rows for bridges"
    picks = []
    for i in range(count):
        part = options[i * len(options) // count:(i + 1) * len(options) // count]
        picks.append(part[len(part) // 2])
    return picks


if __name__ == "__main__":
    main()
