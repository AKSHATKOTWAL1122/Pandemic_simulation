#!/usr/bin/env python3
"""Stacked area of the mean over runs: S at the bottom, E + I in the middle,
R (recovered) and immune_forever on top.

seir.csv R counts every NPC in state R, including immune_forever ones, so the top
zone is split into R − immune_forever ("recovered") and immune_forever.
Usage: python analysis/stacked.py output/baseline [--out FILE]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from common import COLORS, day_axis, pct_axis, plt, save, stack_runs, titled
from load import experiment_name, experiment_plots_dir, load_experiment


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="Stacked SEIR area")
    ap.add_argument("experiment")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    runs = load_experiment(args.experiment)
    name = experiment_name(args.experiment)

    grid = None
    mean = {}
    for col in ("S", "E", "I", "R", "immune_forever"):
        grid, m = stack_runs(runs, col, grid)
        mean[col] = np.nanmean(m, axis=0)
    layers = [
        (mean["S"], COLORS["S"], "Susceptible"),
        (mean["E"] + mean["I"], COLORS["I"], "Exposed + Infected"),
        (mean["R"] - mean["immune_forever"], COLORS["R"], "Recovered"),
        (mean["immune_forever"], COLORS["immune_forever"], "Immune forever"),
    ]
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.stackplot(grid, *[l[0] for l in layers], colors=[l[1] for l in layers],
                 labels=[l[2] for l in layers], edgecolor="white", linewidth=0.3)
    day_axis(ax, grid[-1])
    pct_axis(ax)
    ax.grid(False)
    titled(ax, f"Population by state — {name}",
           f"mean of {len(runs)} runs" if len(runs) > 1 else "1 run")
    handles, labels = ax.get_legend_handles_labels()
    ax.legend(handles[::-1], labels[::-1], loc="center left", bbox_to_anchor=(1.01, 0.5))
    out = Path(args.out) if args.out else experiment_plots_dir(args.experiment) / "stacked.png"
    return save(fig, out)


if __name__ == "__main__":
    main()
