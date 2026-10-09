#!/usr/bin/env python3
"""Tests for the spec 15 analysis, on fake runs from make_fake_run.py.

Run:  analysis/.venv/bin/python analysis/test_analysis.py      (plain runner)
 or:  analysis/.venv/bin/python -m pytest analysis/test_analysis.py   (if pytest is installed)

Generated runs and PNGs go to a temporary folder that is deleted afterwards
(set KEEP_TEST_OUTPUT=1 to keep it and print its path).
"""
from __future__ import annotations

import atexit
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

import common  # noqa: E402,F401  (sets the Agg backend before pyplot is used)
import heatmap  # noqa: E402
import make_fake_run  # noqa: E402
from load import load_experiment, load_run  # noqa: E402

HEADERS = {
    "seir.csv": "tick,day,hour,S,E,I,R,immune_forever",
    "contacts.csv": "tick,a,b,x,y,building_id,in_car",
    "infections.csv": "tick,infector,infected,x,y,building_id,in_car",
    "npcs.csv": "id,household_id,home_id,occupation,work_id,school_id,has_car,"
                "immune_forever,contact_count,first_infected_tick",
}
DAYS = 2
POP = 1000
SEEDS = (1000, 1001)

_TMP: Path | None = None


def tmp() -> Path:
    """Shared fixture: baseline + malls_closed, 2 runs each, 2 days, same seeds."""
    global _TMP
    if _TMP is None:
        _TMP = Path(tempfile.mkdtemp(prefix="npc_analysis_test_"))
        if os.environ.get("KEEP_TEST_OUTPUT"):
            print(f"test output kept in {_TMP}")
        else:
            atexit.register(shutil.rmtree, _TMP, True)
        for exp, extra in (("baseline", []), ("malls_closed", ["--close-malls"])):
            for i, seed in enumerate(SEEDS):
                make_fake_run.main(["--out", str(_TMP / exp / f"run_{i}"), "--days", str(DAYS),
                                    "--seed", str(seed), "--population", str(POP),
                                    "--patient-zeros", "3", "--p", "0.005", *extra])
    return _TMP


def run_script(name: str, *args: str) -> str:
    cmd = [sys.executable, str(HERE / f"{name}.py"), *args]
    res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    assert res.returncode == 0, f"{name} failed:\n{res.stdout}\n{res.stderr}"
    return res.stdout


def new_pngs(folder: Path, since: float) -> list[Path]:
    return [p for p in folder.glob("*.png") if p.stat().st_mtime >= since]


# ---------------------------------------------------------------- generator / spec 14 format

def test_fake_run_format_and_consistency():
    run_dir = tmp() / "baseline" / "run_0"
    for f in ("config.json", *HEADERS):
        assert (run_dir / f).exists(), f
    for f, header in HEADERS.items():
        raw = (run_dir / f).read_bytes()
        assert b"\r" not in raw, f"{f}: must use \\n line endings"
        assert raw.decode().split("\n", 1)[0] == header, f"{f}: header"
        assert raw.endswith(b"\n")
    cfg = json.loads((run_dir / "config.json").read_text())
    assert cfg["seed"] == SEEDS[0] and cfg["population"] == POP

    run = load_run(run_dir)
    tpd = 86400 // cfg["tick_seconds"]
    s = run.seir
    assert len(s) == DAYS * tpd, "seir.csv rows == ticks run"
    assert (s["tick"].to_numpy() == np.arange(len(s))).all()
    assert (s[["S", "E", "I", "R"]].sum(axis=1) == POP).all()
    assert (s["day"] == s["tick"] // tpd).all() and s["hour"].between(0, 23).all()

    n, inf, c = run.npcs, run.infections, run.contacts
    assert len(n) == POP and (n["id"].to_numpy() == np.arange(POP)).all()
    pz = inf[inf["infector"] == -1]
    assert len(pz) == cfg["patient_zero"]["count"] and (pz["tick"] == 0).all()
    # Every non-patient-zero row is one S->E: E rises by exactly those at each tick
    # (E only drops by timers, which can't fire within 1 day of an infection).
    se = inf[inf["infector"] >= 0].groupby("tick").size()
    e = s["E"].to_numpy()
    first_day = se[se.index < tpd]  # E->I timers start at tick tpd
    for t, k in first_day.items():
        assert e[t] - (e[t - 1] if t else 0) == k, f"E jump at tick {t}"
    assert s["I"].iloc[0] == len(pz)
    # npcs.csv <-> infections.csv <-> contacts.csv
    first = inf.groupby("infected")["tick"].min()
    expect = np.full(POP, -1)
    expect[first.index] = first.to_numpy()
    assert (n["first_infected_tick"].to_numpy() == expect).all()
    cc = np.bincount(c["a"], minlength=POP) + np.bincount(c["b"], minlength=POP)
    assert (n["contact_count"].to_numpy() == cc).all()
    assert (c["a"] < c["b"]).all() and c["tick"].is_monotonic_increasing
    for df, cols in ((c, ["in_car"]), (inf, ["in_car"]), (n, ["has_car", "immune_forever"])):
        for col in cols:
            assert set(df[col].unique()) <= {0, 1}, col
    assert set(n["occupation"]) <= {"WORKER", "STUDENT", "NONE"}
    assert c["x"].between(0, 256).all() and c["y"].between(0, 256).all()
    # Every infector was infected (I) before infecting.
    infected_at = inf.groupby("infected")["tick"].min()
    for row in inf[inf["infector"] >= 0].itertuples():
        assert infected_at[row.infector] < row.tick


def test_fake_run_deterministic():
    a, b = tmp() / "det_a", tmp() / "det_b"
    for out in (a, b):
        make_fake_run.main(["--out", str(out), "--days", "1", "--seed", "42",
                            "--population", "300"])
    for f in HEADERS:
        assert (a / f).read_bytes() == (b / f).read_bytes(), f


def test_immune_share_exact():
    out = tmp() / "imm" / "run_0"
    make_fake_run.main(["--out", str(out), "--days", "1", "--seed", "5", "--population", "1000",
                        "--immune-share", "0.2", "--patient-zeros", "4"])
    run = load_run(out)
    assert run.npcs["immune_forever"].sum() == 200
    pz = run.infections.loc[run.infections["infector"] == -1, "infected"]
    assert not run.npcs.loc[pz, "immune_forever"].any(), "patient zero is never immune"
    assert (run.seir["immune_forever"] == 200).all()
    assert (run.seir["R"] >= 200).all(), "immune_forever NPCs are counted in R"


def test_load_experiment_order():
    runs = load_experiment(tmp() / "baseline")
    assert [r.name for r in runs] == ["run_0", "run_1"]
    assert load_experiment(tmp() / "baseline" / "run_1")[0].name == "run_1"


# ---------------------------------------------------------------- heatmap alignment

def test_heatmap_tile_10_10_numeric():
    for x, y in ((10.5, 10.5), (10.0, 10.0), (10.99, 10.99)):
        d = heatmap.density(np.array([x]), np.array([y]), sigma=2.0)
        assert d.shape == (256, 256)
        assert np.unravel_index(d.argmax(), d.shape) == (10, 10), (x, y)
        assert abs(d.sum() - 1.0) < 1e-6
    # Asymmetric point catches an x/y transpose: array is [row = y, col = x].
    counts = heatmap.tile_counts(np.array([10.5]), np.array([200.5]))
    assert counts[200, 10] == 1 and counts.sum() == 1
    assert heatmap.hotspots(heatmap.tile_counts(np.full(3, 10.5), np.full(3, 10.5)))[0] == (10, 10, 3)


def test_heatmap_tile_10_10_on_map():
    import matplotlib.image as mpimg
    map_img = mpimg.imread(ROOT / "data" / "map.png")
    assert map_img.shape[:2] == (256, 256)
    fig, ax, map_im, heat_im, dens = heatmap.plot_heatmap(
        map_img, np.array([10.5]), np.array([10.5]), sigma=0.6)
    # Same extent/origin for both layers, y pointing down like the map.
    assert tuple(map_im.get_extent()) == tuple(heat_im.get_extent()) == (0, 256, 256, 0)
    assert map_im.origin == heat_im.origin == "upper"
    assert ax.get_ylim() == (256, 0) and ax.get_xlim() == (0, 256)
    for im in (map_im, heat_im):
        arr = im.get_array()
        assert heatmap.image_index(im.get_extent(), arr.shape, 10.5, 10.5, im.origin) == (10, 10)
    assert np.unravel_index(np.asarray(heat_im.get_array()).argmax(), dens.shape) == (10, 10)
    # The map pixel drawn under data (10.5, 10.5) is map.png pixel (x=10, y=10).
    r, cidx = heatmap.image_index(map_im.get_extent(), map_img.shape, 10.5, 10.5)
    assert np.array_equal(map_im.get_array()[r, cidx], map_img[10, 10])

    # Rendered check: the hottest rendered pixel sits on tile (10, 10).
    fig.canvas.draw()
    rgba = np.asarray(fig.canvas.buffer_rgba()).astype(int)
    h = rgba.shape[0]
    bbox = ax.get_window_extent()
    sub = rgba[int(h - bbox.y1):int(h - bbox.y0), int(bbox.x0):int(bbox.x1)]
    # "hot" = dark red of the top of the colormap: high R, low G and B.
    redness = sub[:, :, 0] - (sub[:, :, 1] + sub[:, :, 2]) / 2
    py, px = np.unravel_index(redness.argmax(), redness.shape)
    dx, dy = ax.transData.inverted().transform((bbox.x0 + px + 0.5, bbox.y1 - py - 0.5))
    assert int(np.floor(dx)) in (9, 10, 11) and int(np.floor(dy)) in (9, 10, 11), (dx, dy)
    assert abs(dx - 10.5) <= 1.0 and abs(dy - 10.5) <= 1.0, (dx, dy)
    common.plt.close(fig)


# ---------------------------------------------------------------- every script runs

def test_scripts_make_pngs():
    base = tmp() / "baseline"
    plots = base / "plots"
    run = str(base / "run_0")
    t0 = time.time() - 1
    run_script("seir_curves", str(base))
    run_script("profile", str(base))
    run_script("stacked", str(base))
    run_script("herd_immunity", str(base), str(tmp() / "malls_closed"), str(tmp() / "imm"))
    run_script("contact_distribution", run)
    run_script("contact_graph", run, "--from-day", "0", "--to-day", "1")
    out = run_script("transmission_tree", run)
    assert "max depth" in out
    out = run_script("heatmap", run, "--events", "contacts", "--hours", "0-24")
    assert out.count("tile (") == 5, out
    run_script("heatmap", run, "--events", "infections", "--hours", "8-18")
    run_script("heatmap", run, "--events", "contacts", "--hours", "22-6")
    made = {p.name for p in new_pngs(plots, t0)}
    expected = {"seir_curves.png", "profile.png", "stacked.png", "herd_immunity.png",
                "contact_distribution_run_0.png", "contact_graph_run_0_d0-1.png",
                "transmission_tree_run_0.png", "heatmap_contacts_run_0_h0-24.png",
                "heatmap_infections_run_0_h8-18.png", "heatmap_contacts_run_0_h22-6.png"}
    assert expected <= made, expected - made
    assert (plots / "contact_graph_run_0_d0-1.gexf").exists()
    for p in expected:
        assert (plots / p).read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"


def test_compare_prints_both_peaks():
    t0 = time.time() - 1
    out = run_script("compare", str(tmp() / "baseline"), str(tmp() / "malls_closed"))
    assert "baseline: 2 runs" in out and "malls_closed: 2 runs" in out, out
    assert out.count("peak day") == 2 and out.count("peak infected %") == 2, out
    assert "compare_baseline_vs_malls_closed.png" in {
        p.name for p in new_pngs(tmp() / "baseline" / "plots", t0)}


def test_transmission_forest():
    sys.path.insert(0, str(HERE))
    import transmission_tree as tt
    inf = pd.DataFrame({"tick": [0, 0, 5, 6, 7, 9000], "infector": [-1, -1, 1, 2, 7, 1],
                        "infected": [1, 2, 7, 8, 9, 3], "x": 0.0, "y": 0.0,
                        "building_id": -1, "in_car": 0})
    g = tt.build_tree(inf)
    roots = [n for n in g.nodes if g.in_degree(n) == 0]
    assert len(roots) == 2
    assert max(g.nodes[n]["depth"] for n in g.nodes) == 2  # 1 -> 7 -> 9
    pos = tt.layered_layout(g)
    assert len(pos) == len(inf)


def main() -> int:
    tests = [(k, v) for k, v in globals().items() if k.startswith("test_") and callable(v)]
    failed = 0
    for name, fn in tests:
        t = time.time()
        try:
            fn()
            print(f"PASS {name} ({time.time() - t:.1f}s)")
        except Exception as e:  # noqa: BLE001
            failed += 1
            import traceback
            traceback.print_exc()
            print(f"FAIL {name}: {e}")
    print(f"\n{len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
