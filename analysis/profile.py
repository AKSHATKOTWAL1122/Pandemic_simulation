#!/usr/bin/env python3
"""Infection profile: Infected % against Susceptible % (one thin line per run, bold mean).

Time runs along each curve; the first point is marked with a dot.
Usage: python analysis/profile.py output/baseline [--out FILE]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from common import COLORS, plt, save, stack_runs, titled
from load import experiment_name, experiment_plots_dir, load_experiment


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="Infected vs Susceptible profile")
    ap.add_argument("experiment")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    runs = load_experiment(args.experiment)
    name = experiment_name(args.experiment)

    grid, s = stack_runs(runs, "S")
    _, i = stack_runs(runs, "I", grid)
    fig, ax = plt.subplots(figsize=(7, 6))
    if len(runs) > 1:
        for k in range(len(runs)):
            ax.plot(s[k], i[k], color=COLORS["S"], lw=0.8, alpha=0.5)
        ax.plot([], [], color=COLORS["S"], lw=0.8, alpha=0.5, label="single run")
    ms, mi = np.nanmean(s, axis=0), np.nanmean(i, axis=0)
    ax.plot(ms, mi, color=COLORS["I"], lw=2, label="mean" if len(runs) > 1 else name)
    ax.plot(ms[0], mi[0], "o", color=COLORS["I"], ms=8, label="day 0")
    peak = int(np.nanargmax(mi))
    ax.annotate(f"peak of mean: day {grid[peak]:.1f}", (ms[peak], mi[peak]), xytext=(8, 4),
                textcoords="offset points", fontsize=9, color="#333333")
    ax.set_xlabel("Susceptible (% of population)")
    ax.set_ylabel("Infected (% of population)")
    ax.set_xlim(0, 100)
    ax.set_ylim(0, max(5.0, float(np.nanmax(i)) * 1.15))
    n = len(runs)
    titled(ax, f"Infection profile — {name}",
           f"{n} runs · thin = one run, bold = mean · time runs right to left"
           if n > 1 else "1 run · time runs right to left")
    ax.legend(loc="upper left")
    out = Path(args.out) if args.out else experiment_plots_dir(args.experiment) / "profile.png"
    return save(fig, out)


if __name__ == "__main__":
    main()
