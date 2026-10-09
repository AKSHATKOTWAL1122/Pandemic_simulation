#!/usr/bin/env python3
"""Contact graph of one run for a time window; also writes a .gexf for Gephi.

Nodes = NPCs with at least one contact in the window, edges = pairs that met, edge
weight = number of contact events. Node colour = occupation, size = degree.
Window: [from_day, to_day) in days since the start (fractions allowed).

Usage: python analysis/contact_graph.py output/baseline/run_0 --from-day 0 --to-day 1 [--out FILE]
Default: <experiment>/plots/contact_graph_<run>_d<from>-<to>.png and .gexf
"""
from __future__ import annotations

import argparse
from pathlib import Path

import networkx as nx
import numpy as np

from common import plt, save
from load import load_run

OCC_COLORS = {"WORKER": "#2E86AB", "STUDENT": "#F2C14E", "NONE": "#7A8CA5"}


def build_graph(run, from_day: float, to_day: float) -> nx.Graph:
    c = run.contacts
    d = run.days(c["tick"])
    w = c[(d >= from_day) & (d < to_day)]
    counts = w.groupby(["a", "b"]).size()
    g = nx.Graph()
    npcs = run.npcs.set_index("id")
    nodes = np.union1d(w["a"].unique(), w["b"].unique())
    for n in nodes:
        r = npcs.loc[n]
        g.add_node(int(n), occupation=str(r["occupation"]), household_id=int(r["household_id"]),
                   home_id=int(r["home_id"]), immune_forever=int(r["immune_forever"]),
                   ever_infected=int(r["first_infected_tick"] >= 0))
    for (a, b), k in counts.items():
        g.add_edge(int(a), int(b), weight=int(k))
    return g


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="Contact graph for a time window")
    ap.add_argument("run")
    ap.add_argument("--from-day", type=float, default=0.0)
    ap.add_argument("--to-day", type=float, default=1.0)
    ap.add_argument("--out", help="PNG path; the .gexf goes next to it")
    args = ap.parse_args(argv)
    if args.to_day <= args.from_day:
        ap.error("--to-day must be greater than --from-day")
    run = load_run(args.run)
    g = build_graph(run, args.from_day, args.to_day)

    tag = f"{run.name}_d{args.from_day:g}-{args.to_day:g}"
    out = Path(args.out) if args.out else run.plots_dir / f"contact_graph_{tag}.png"
    gexf = out.with_suffix(".gexf")
    nx.write_gexf(g, gexf)
    print(f"saved {gexf}")
    deg = dict(g.degree())
    print(f"contact graph days [{args.from_day:g}, {args.to_day:g}): {g.number_of_nodes()} nodes, "
          f"{g.number_of_edges()} edges, mean degree "
          f"{(np.mean(list(deg.values())) if deg else 0):.1f}")

    fig, ax = plt.subplots(figsize=(10, 10))
    ax.grid(False)
    ax.set_axis_off()
    if g.number_of_nodes():
        pos = nx.spring_layout(g, seed=1, k=1.5 / np.sqrt(g.number_of_nodes()), iterations=60)
        nx.draw_networkx_edges(g, pos, ax=ax, width=0.3, alpha=0.25, edge_color="#888888")
        dv = np.array([deg[n] for n in g.nodes])
        nx.draw_networkx_nodes(
            g, pos, ax=ax, node_size=6 + 40 * dv / max(1, dv.max()),
            node_color=[OCC_COLORS.get(g.nodes[n]["occupation"], "#999999") for n in g.nodes],
            linewidths=0.4, edgecolors="white")
        for occ, col in OCC_COLORS.items():
            ax.scatter([], [], s=40, color=col, label=occ.lower())
        ax.legend(loc="upper left", title="Occupation")
    ax.set_title(f"Contact graph — {run.experiment} / {run.name}, days "
                 f"{args.from_day:g}–{args.to_day:g} ({g.number_of_nodes()} NPCs, "
                 f"{g.number_of_edges()} pairs)")
    return save(fig, out)


if __name__ == "__main__":
    main()
