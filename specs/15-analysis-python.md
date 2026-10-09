# 15 — Analysis (Python)

**Goal:** the reference's charts and comparisons, drawn from the CSVs.
**Depends on:** 14. (Built first in lane C against fake runs from `analysis/make_fake_run.py`, in the exact spec 14 format.)

## Build
`analysis/requirements.txt`: pandas, numpy, matplotlib, networkx, scipy (unpinned). Python 3.11+ (built and tested with 3.14.7).
Setup, from the repo root (`analysis/.venv/` is gitignored):
```
python3 -m venv analysis/.venv
analysis/.venv/bin/pip install -r analysis/requirements.txt
```
Run every command below with `analysis/.venv/bin/python` (or activate the venv and use `python`), from the repo root.

`analysis/load.py`: `load_run(path) -> Run`, `load_experiment(path) -> list[Run]` (every `run_<i>/`, sorted by i; a run folder itself gives a one-element list).
`Run` has `config` (dict), `seir`, `infections`, `npcs` (DataFrames, read at once) and `contacts` (read on first access), plus helpers: `days(ticks)`, `hour_of_day(ticks)`, `seir_pct()`, `ever_infected_pct()`, `population`, `tick_seconds`, `immune_share`, `map_path`, `buildings_path`, `plots_dir`.
`analysis/common.py`: Agg backend, spec 11 state colours, mean line + 10–90 % band helper.

Scripts. Experiment scripts take `output/<experiment>` and save to `output/<experiment>/plots/`. Run scripts take `output/<experiment>/run_<i>` and save to the same experiment's `plots/`, with the run name in the file name. Every script also takes `--out FILE`.
| Script | Chart | Default PNG |
|---|---|---|
| `seir_curves.py <exp>` | S/E/I/R % over days. With many runs: mean line + 10–90 % band. | `seir_curves.png` |
| `compare.py <exp_a> <exp_b>` | Infected (I) % for both on one chart (e.g. malls open vs closed), mean + 10–90 % band. Prints peak day and peak % per experiment as mean ± sd (10–90 % range) over runs, and the paired difference for runs with the same name (same seed). | `compare_<a>_vs_<b>.png` in `<exp_a>/plots/` |
| `profile.py <exp>` | Infected % vs Susceptible % (infection profile): thin line per run, bold mean. | `profile.png` |
| `stacked.py <exp>` | Stacked area of the mean: S bottom, E+I middle, R (= R − immune_forever) and immune_forever top. | `stacked.png` |
| `herd_immunity.py <exp> <exp> ...` | % of population ever infected vs immune share, one point per experiment (mean, 10–90 % bar). | `herd_immunity.png` in the first experiment's `plots/` |
| `contact_distribution.py <run> [--bin 100]` | Histogram of contact_count (bins of 100) + ranked plot. | `contact_distribution_<run>.png` |
| `contact_graph.py <run> --from-day A --to-day B` | Contact graph for days [A, B) (edge weight = contact events, colour = occupation, size = degree); also writes `.gexf` for Gephi next to the PNG. Defaults 0–1. | `contact_graph_<run>_d<A>-<B>.png` + `.gexf` |
| `transmission_tree.py <run>` | Tree from patient zero(s), hierarchical layout (y = generation); prints max depth and tree sizes. Several patient zeros → forest, one colour per tree. Each infections.csv row is a node, so a reinfected NPC appears twice; its parent is the infector's latest infection before that tick. | `transmission_tree_<run>.png` |
| `heatmap.py <run> --events contacts\|infections --hours a-b [--sigma 2] [--min-sep 8]` | KDE heatmap over `data/map.png` (binned Gaussian KDE: per-tile counts smoothed with σ tiles). `--hours` is hour of day [a, b) over all days; a > b wraps midnight (e.g. `22-6`). Prints top 5 hotspot tiles (raw events per tile, at least `--min-sep` tiles apart, with their building). | `heatmap_<events>_<run>_h<a>-<b>.png` |

Examples:
```
python analysis/seir_curves.py output/baseline
python analysis/compare.py output/baseline output/malls_closed
python analysis/profile.py output/baseline
python analysis/stacked.py output/baseline
python analysis/herd_immunity.py output/baseline output/immune_50
python analysis/contact_distribution.py output/baseline/run_0
python analysis/contact_graph.py output/baseline/run_0 --from-day 0 --to-day 1
python analysis/transmission_tree.py output/baseline/run_0
python analysis/heatmap.py output/baseline/run_0 --events contacts --hours 0-24
```

## Data conventions the analysis assumes (the spec 14 exporter must match)
- Tick `t` covers game time `t × tick_seconds`; ticks start at 0. Days on chart axes = `tick × tick_seconds / 86400` (the `day` column is not needed). `seir.csv` row `t` = counts after tick t (patient zeros already I at tick 0).
- `seir.csv`: `R` counts every NPC in state R **including** `immune_forever` ones; `immune_forever` = how many NPCs have the flag. So S + E + I + R = population.
- `day` = `tick × tick_seconds // 86400`, `hour` = integer hour of the day (0–23).
- `x`, `y` are float tiles; an event is on tile `(floor(x), floor(y))` (tile (10, 10) spans 10.0 ≤ x < 11.0), y pointing down as in `map.png`.
- `npcs.csv`: `occupation` is the text `WORKER` / `STUDENT` / `NONE`; `first_infected_tick` = -1 if never infected (patient zeros: their infection tick, usually 0); `work_id` / `school_id` = -1 if none.
- `infections.csv`: one row per S→E (an NPC can appear again after losing immunity) plus one row per patient zero / manual infection with `infector = -1`; patient zero rows use the NPC's position and building at that tick.
- `config.json` keys read: `name`, `seed`, `tick_seconds`, `immune_share`, `map_path` (`res://` paths are resolved against the repo root; fallback `data/map.png`), `buildings_path` (fallback `data/buildings.json`). Missing keys fall back to the CSVs or defaults.

## Fake data (until the simulator exports)
`analysis/make_fake_run.py` writes one run in the exact spec 14 format (all 5 files, header row, `,`, `\n`, booleans 0/1, floats with 2 decimals). It is a small seeded agent model, not the simulator: households/homes/jobs/schools from `data/buildings.json` (spec 05 shares), an hourly schedule (home, work, school, outings to restaurants, malls, nightclubs, friends), contact events sampled per building-hour (busier, more mobile places like malls meet more) and on the street (snapped to sidewalk/road tiles of `map.png`), and SEIR with the spec 11 timers on those contacts. Seeded steps in spec 13 order (population → immune share → patient zero). Closed malls cancel mall outings and mall jobs.
```
python analysis/make_fake_run.py --out output/<exp>/run_<i> --days N --seed S --population P \
    --patient-zeros K --immune-share X [--close-malls] [--p 0.001] [--tick-seconds 60] [--name EXP]
```
A 2-day, 1,000-NPC run takes under a second; 30 days about 2 s. To make a fake experiment pair:
```
for i in 0 1 2; do
  python analysis/make_fake_run.py --out output/baseline/run_$i --days 30 --seed $((1000+i))
  python analysis/make_fake_run.py --out output/malls_closed/run_$i --days 30 --seed $((1000+i)) --close-malls
done
```
Generated runs and plots stay in `output/` (gitignored).

## Tests
`python analysis/test_analysis.py` (plain runner; also passes under `python -m pytest analysis/test_analysis.py` if pytest is installed — it is not in requirements). Generates fake runs into a temp folder (`KEEP_TEST_OUTPUT=1` keeps it) and checks:
- fake runs follow spec 14 exactly (headers, `\n`, rows == ticks, S+E+I+R = population, infections ↔ npcs.first_infected_tick ↔ seir, contact_count ↔ contacts.csv, 0/1 booleans), are deterministic per seed, and `immune_share` 0.2 → exactly 200 immune, no immune patient zero;
- heatmap alignment, numerically and on the rendered figure;
- every script runs on a 2-day run and saves a PNG (+ `.gexf`);
- `compare.py` on baseline vs malls_closed prints both peaks;
- transmission forest with two roots and the right depth.

## Done when
- Every script runs on the output of a 2-day run and saves a PNG. (`test_scripts_make_pngs`)
- Heatmap alignment: a fake event at tile (10, 10) appears at tile (10, 10) on the map. (`test_heatmap_tile_10_10_numeric`, `test_heatmap_tile_10_10_on_map`)
- `compare.py` on `baseline` vs `malls_closed` prints both peaks. (`test_compare_prints_both_peaks`)
- Re-check all three on real simulator output once spec 14 is built.
