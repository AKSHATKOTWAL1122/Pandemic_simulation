#!/usr/bin/env python3
"""% of population ever infected against immune share, one point per experiment
(mean over runs, error bar = 10-90 % range).

Immune share comes from config.json `immune_share` (fallback: share of immune_forever
NPCs in npcs.csv). "Ever infected" = npcs.csv first_infected_tick >= 0, patient zeros included.
Usage: python analysis/herd_immunity.py output/baseline output/immune_25 output/immune_50 [--out FILE]
Default PNG: <first experiment>/plots/herd_immunity.png
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from common import COLORS, plt, save, spread
from load import experiment_name, experiment_plots_dir, load_experiment


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="Herd immunity: ever infected vs immune share")
    ap.add_argument("experiments", nargs="+")
    ap.add_argument("--out")
    args = ap.parse_args(argv)

    pts = []
    for p in args.experiments:
        runs = load_experiment(p)
        share = 100.0 * float(np.mean([r.immune_share for r in runs]))
        ever = [r.ever_infected_pct() for r in runs]
        pts.append((share, ever, experiment_name(p)))
        print(f"{experiment_name(p)}: immune {share:.0f} % · ever infected % {spread(ever)}")
    pts.sort(key=lambda t: t[0])

    fig, ax = plt.subplots(figsize=(7, 5))
    x = np.array([p[0] for p in pts])
    y = np.array([np.mean(p[1]) for p in pts])
    lo = np.array([np.percentile(p[1], 10) for p in pts])
    hi = np.array([np.percentile(p[1], 90) for p in pts])
    ax.plot(x, y, color=COLORS["immune_forever"], lw=1.2, alpha=0.6)
    ax.errorbar(x, y, yerr=[y - lo, hi - y], fmt="o", ms=8, color=COLORS["I"],
                ecolor="#999999", elinewidth=1.5, capsize=4, label="mean, bar = 10–90 %")
    ax.plot(x, 100 - x, ls="--", lw=1, color="#AAAAAA", label="all non-immune infected")
    for xi, yi, (_, _, name) in zip(x, y, pts):
        ax.annotate(name, (xi, yi), xytext=(6, 6), textcoords="offset points", fontsize=9,
                    color="#333333")
    ax.set_xlabel("Immune share (% of population)")
    ax.set_ylabel("Ever infected (% of population)")
    ax.set_xlim(-2, 102)
    ax.set_ylim(0, 105)
    ax.set_title("Herd immunity")
    ax.legend(loc="upper right")
    out = Path(args.out) if args.out else experiment_plots_dir(args.experiments[0]) / "herd_immunity.png"
    return save(fig, out)


if __name__ == "__main__":
    main()
