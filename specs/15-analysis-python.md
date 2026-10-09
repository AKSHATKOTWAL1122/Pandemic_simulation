# 15 — Analysis (Python)

**Goal:** the reference's charts and comparisons, drawn from the CSVs.
**Depends on:** 14.

## Build
`analysis/requirements.txt`: pandas, numpy, matplotlib, networkx, scipy. Python 3.11+.
`analysis/load.py`: `load_run(path)`, `load_experiment(path) -> list of runs`.

Scripts. Each saves PNGs to `output/<experiment>/plots/`:
| Script | Chart |
|---|---|
| `seir_curves.py <exp>` | S/E/I/R % over days. With many runs: mean line + 10–90 % band. |
| `compare.py <exp_a> <exp_b>` | Infected % for both on one chart (e.g. malls open vs closed). Prints peak day and peak %, as mean ± spread. |
| `profile.py <exp>` | Infected vs Susceptible (infection profile). |
| `stacked.py <exp>` | Stacked area: S bottom, E+I middle, R + immune top. |
| `herd_immunity.py <exp> ...` | % ever infected vs immune share, one point per experiment. |
| `contact_distribution.py <run>` | Histogram of contact_count (bins of 100) + ranked plot. |
| `contact_graph.py <run> --from-day --to-day` | Contact graph for a time window; also writes `.gexf` for Gephi. |
| `transmission_tree.py <run>` | Tree from patient zero(s), hierarchical layout; prints max depth. Several patient zeros → forest. |
| `heatmap.py <run> --events contacts|infections --hours 0-24` | KDE heatmap over `data/map.png`; prints top 5 hotspot tiles. |

## Done when
- Every script runs on the output of a 2-day run and saves a PNG.
- Heatmap alignment: a fake event at tile (10, 10) appears at tile (10, 10) on the map.
- `compare.py` on `baseline` vs `malls_closed` prints both peaks.
