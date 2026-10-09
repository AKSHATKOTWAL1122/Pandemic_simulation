#!/usr/bin/env python3
"""S/E/I/R as % of population over days. Many runs: mean line + 10-90 % band.

Usage: python analysis/seir_curves.py output/baseline [--out FILE]
"""
from __future__ import annotations

import argparse
from pathlib import Path

from common import COLORS, LABELS, band, day_axis, pct_axis, plt, runs_note, save, stack_runs, titled
from load import experiment_name, experiment_plots_dir, load_experiment


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="SEIR curves of an experiment")
    ap.add_argument("experiment", help="output/<experiment> (or one run folder)")
    ap.add_argument("--out", help="PNG path (default <experiment>/plots/seir_curves.png)")
    args = ap.parse_args(argv)
    runs = load_experiment(args.experiment)
    name = experiment_name(args.experiment)

    fig, ax = plt.subplots(figsize=(9, 5))
    grid = None
    for col in ("S", "E", "I", "R"):
        grid, m = stack_runs(runs, col, grid)
        band(ax, grid, m, COLORS[col], LABELS[col])
    day_axis(ax, grid[-1])
    pct_axis(ax)
    titled(ax, f"SEIR — {name}", runs_note(runs))
    ax.legend(loc="center left", bbox_to_anchor=(1.01, 0.5))
    out = Path(args.out) if args.out else experiment_plots_dir(args.experiment) / "seir_curves.png"
    return save(fig, out)


if __name__ == "__main__":
    main()
