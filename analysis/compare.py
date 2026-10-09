#!/usr/bin/env python3
"""Infected % of two experiments on one chart (e.g. malls open vs closed).

Prints, for each experiment, peak day and peak infected % as mean ± sd with the
10-90 % range over runs. Give both experiments the same base_seed and runs (spec 13)
so run i of each shares a seed; paired differences are printed for matching run names.

Usage: python analysis/compare.py output/baseline output/malls_closed [--out FILE]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from common import band, day_axis, plt, runs_note, save, spread, stack_runs, titled
from load import experiment_name, experiment_plots_dir, load_experiment

PAIR_COLORS = ("#D7263D", "#2E86AB")  # spec 11 I red vs immune blue: distinct, CVD-safe


def peaks(runs) -> tuple[list[float], list[float]]:
    days, pct = [], []
    for r in runs:
        s = r.seir_pct()
        i = int(s["I"].to_numpy().argmax())
        days.append(float(s["days"].iloc[i]))
        pct.append(float(s["I"].iloc[i]))
    return days, pct


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="Compare infected % of two experiments")
    ap.add_argument("exp_a")
    ap.add_argument("exp_b")
    ap.add_argument("--out", help="PNG path (default <exp_a>/plots/compare_<a>_vs_<b>.png)")
    args = ap.parse_args(argv)

    exps = [(experiment_name(p), load_experiment(p)) for p in (args.exp_a, args.exp_b)]
    fig, ax = plt.subplots(figsize=(9, 5))
    grid = None
    top = 0.0
    results = {}
    for (name, runs), color in zip(exps, PAIR_COLORS):
        grid, m = stack_runs(runs, "I", grid)
        d, p = peaks(runs)
        results[name] = (runs, d, p)
        band(ax, grid, m, color,
             f"{name}: peak {np.mean(p):.1f} % on day {np.mean(d):.1f} (mean over {len(runs)} runs)")
        top = max(top, float(np.nanmax(m)))
    day_axis(ax, grid[-1])
    ax.set_ylabel("Infected (% of population)")
    ax.set_ylim(0, max(5.0, top * 1.15))
    names = list(results)
    titled(ax, f"Infected — {names[0]} vs {names[1]}",
           runs_note(exps[0][1]) if len(exps[0][1]) > 1 else "")
    ax.legend(loc="upper right")

    for name, (runs, d, p) in results.items():
        print(f"{name}: {len(runs)} runs")
        print(f"  peak day        {spread(d)}")
        print(f"  peak infected % {spread(p)}")
    (ra, da, pa), (rb, db, pb) = results[names[0]][0:3], results[names[1]][0:3]
    pa_by = {r.name: (x, y) for r, x, y in zip(ra, da, pa)}
    paired = [(pa_by[r.name][1] - y) for r, x, y in zip(rb, db, pb) if r.name in pa_by]
    if paired:
        print(f"paired peak % difference ({names[0]} − {names[1]}, {len(paired)} pairs): "
              f"{spread(paired)}")

    out = Path(args.out) if args.out else (experiment_plots_dir(args.exp_a)
                                           / f"compare_{names[0]}_vs_{names[1]}.png")
    return save(fig, out)


if __name__ == "__main__":
    main()
