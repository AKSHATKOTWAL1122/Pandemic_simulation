#!/usr/bin/env python3
"""contact_count distribution of one run: histogram (bins of 100) + ranked plot.

Usage: python analysis/contact_distribution.py output/baseline/run_0 [--bin 100] [--out FILE]
Default PNG: <experiment>/plots/contact_distribution_<run>.png
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from common import COLORS, plt, save
from load import load_run


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="contact_count histogram + ranked plot")
    ap.add_argument("run", help="output/<experiment>/run_<i>")
    ap.add_argument("--bin", type=int, default=100, help="histogram bin width (contacts)")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    run = load_run(args.run)
    cc = run.npcs["contact_count"].to_numpy()

    fig, (a1, a2) = plt.subplots(1, 2, figsize=(12, 4.8))
    edges = np.arange(0, max(int(cc.max()), 1) + args.bin, args.bin)
    a1.hist(cc, bins=edges, color=COLORS["S"], edgecolor="white", linewidth=1)
    a1.set_xlabel(f"Contacts per NPC over the run (bins of {args.bin})")
    a1.set_ylabel("NPCs")
    a1.set_title("Contact count distribution")
    a1.axvline(np.median(cc), color=COLORS["I"], lw=1.2, ls="--")
    a1.text(np.median(cc), a1.get_ylim()[1] * 0.95, f" median {np.median(cc):.0f}",
            color="#333333", fontsize=9, va="top")

    ranked = np.sort(cc)[::-1]
    a2.plot(np.arange(1, len(ranked) + 1), ranked, color=COLORS["immune_forever"], lw=2)
    a2.set_xlabel("NPC rank (1 = most contacts)")
    a2.set_ylabel("Contacts over the run")
    a2.set_title("Ranked contacts")
    a2.set_xlim(1, len(ranked))
    a2.set_ylim(0, None)
    top10 = ranked[: max(1, len(ranked) // 10)].sum() / max(1, ranked.sum()) * 100
    a2.text(0.98, 0.95, f"top 10 % of NPCs: {top10:.0f} % of contacts",
            transform=a2.transAxes, ha="right", va="top", fontsize=9, color="#333333")
    days = len(run.seir) / run.ticks_per_day
    fig.suptitle(f"{run.experiment} / {run.name} — {len(cc)} NPCs, {days:g} days, "
                 f"mean {cc.mean():.0f} contacts", fontsize=11, color="#333333")
    print(f"contact_count: mean {cc.mean():.1f}, median {np.median(cc):.0f}, max {cc.max()}")
    out = Path(args.out) if args.out else run.plots_dir / f"contact_distribution_{run.name}.png"
    return save(fig, out)


if __name__ == "__main__":
    main()
