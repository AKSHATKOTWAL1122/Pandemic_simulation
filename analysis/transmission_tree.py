#!/usr/bin/env python3
"""Transmission tree of one run from patient zero(s), hierarchical layout.

Each infections.csv row is one node (an NPC infected twice after losing immunity
appears twice). Its parent is the infector's latest infection before that tick.
Patient zeros (infector = -1) are roots; several roots give a forest, one colour per tree.
y = generation (patient zero = 0, at the top). Prints the max depth (generations).

Usage: python analysis/transmission_tree.py output/baseline/run_0 [--out FILE]
Default PNG: <experiment>/plots/transmission_tree_<run>.png
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import networkx as nx
import numpy as np
import pandas as pd

from common import plt, save
from load import load_run

TREE_COLORS = ["#D7263D", "#2E86AB", "#3BB273", "#F2C14E", "#7A5195", "#EF7B45",
               "#5C6B7A", "#A0522D"]


def build_tree(infections: pd.DataFrame) -> nx.DiGraph:
    """Nodes = infection row index; attributes npc, tick, depth, root."""
    inf = infections.sort_values("tick", kind="stable").reset_index(drop=True)
    g = nx.DiGraph()
    latest: dict[int, int] = {}  # npc -> node of its latest infection
    for k, row in enumerate(inf.itertuples(index=False)):
        infector, infected, tick = int(row.infector), int(row.infected), int(row.tick)
        parent = latest.get(infector) if infector >= 0 else None
        if parent is None:
            depth, root = 0, k
            if infector >= 0:
                print(f"warning: infector {infector} of npc {infected} at tick {tick} has no "
                      f"earlier infection; treating as a root", file=sys.stderr)
        else:
            depth, root = g.nodes[parent]["depth"] + 1, g.nodes[parent]["root"]
        g.add_node(k, npc=infected, tick=tick, depth=depth, root=root)
        if parent is not None:
            g.add_edge(parent, k)
        latest[infected] = k
    return g


def layered_layout(g: nx.DiGraph) -> dict[int, tuple[float, float]]:
    """Leaves get consecutive x; a parent sits at the middle of its children; y = -depth."""
    pos: dict[int, tuple[float, float]] = {}
    next_x = [0.0]
    roots = sorted(n for n in g.nodes if g.in_degree(n) == 0)

    for r in roots:
        stack = [(r, False)]
        while stack:
            n, done = stack.pop()
            kids = sorted(g.successors(n), key=lambda c: g.nodes[c]["tick"])
            if not kids:
                pos[n] = (next_x[0], -g.nodes[n]["depth"])
                next_x[0] += 1.0
            elif done:
                xs = [pos[c][0] for c in kids]
                pos[n] = ((min(xs) + max(xs)) / 2.0, -g.nodes[n]["depth"])
            else:
                stack.append((n, True))
                stack.extend((c, False) for c in reversed(kids))
        next_x[0] += 2.0  # gap between trees
    return pos


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="Transmission tree")
    ap.add_argument("run")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    run = load_run(args.run)
    g = build_tree(run.infections)
    roots = sorted(n for n in g.nodes if g.in_degree(n) == 0)
    max_depth = max((g.nodes[n]["depth"] for n in g.nodes), default=0)
    print(f"{len(roots)} patient zero(s), {g.number_of_nodes()} infections, max depth {max_depth}")
    for r in roots:
        size = len(nx.descendants(g, r)) + 1
        print(f"  tree of npc {g.nodes[r]['npc']}: {size} infections")

    pos = layered_layout(g)
    n = g.number_of_nodes()
    width = float(np.clip(n / 40.0, 8, 30))
    height = float(np.clip(max_depth * 0.5 + 2, 4, 16))
    fig, ax = plt.subplots(figsize=(width, height))
    ax.grid(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_visible(False)
    root_color = {r: TREE_COLORS[i % len(TREE_COLORS)] for i, r in enumerate(roots)}
    colors = [root_color[g.nodes[k]["root"]] for k in g.nodes]
    nx.draw_networkx_edges(g, pos, ax=ax, arrows=False, width=0.5, edge_color="#AAAAAA")
    size = 10 if n > 300 else 30
    nx.draw_networkx_nodes(g, pos, ax=ax, node_size=size, node_color=colors, linewidths=0)
    nx.draw_networkx_nodes(g, pos, nodelist=roots, ax=ax, node_size=size * 4, node_shape="*",
                           node_color=[root_color[r] for r in roots], edgecolors="#333333",
                           linewidths=0.6)
    if n <= 60:
        nx.draw_networkx_labels(g, {k: (x, y + 0.25) for k, (x, y) in pos.items()},
                                labels={k: str(g.nodes[k]["npc"]) for k in g.nodes},
                                ax=ax, font_size=7, font_color="#333333")
    for r in roots[:8]:
        ax.scatter([], [], marker="*", s=80, color=root_color[r],
                   label=f"patient zero npc {g.nodes[r]['npc']}")
    ax.legend(loc="lower right" if max_depth else "upper right")
    ax.set_axis_on()
    ax.tick_params(left=True, labelleft=True, bottom=False, labelbottom=False)
    ax.set_xticks([])
    ax.set_yticks([-d for d in range(0, max_depth + 1, max(1, max_depth // 15 + 1))])
    ax.set_yticklabels([str(d) for d in range(0, max_depth + 1, max(1, max_depth // 15 + 1))])
    ax.set_ylabel("Generation (patient zero = 0)")
    ax.set_ylim(-max_depth - 0.6, 0.8)
    ax.tick_params(axis="y", length=0)
    ax.set_title(f"Transmission tree — {run.experiment} / {run.name} ({n} infections, "
                 f"{len(roots)} root{'s' if len(roots) != 1 else ''}, max depth {max_depth})")
    out = Path(args.out) if args.out else run.plots_dir / f"transmission_tree_{run.name}.png"
    return save(fig, out)


if __name__ == "__main__":
    main()
