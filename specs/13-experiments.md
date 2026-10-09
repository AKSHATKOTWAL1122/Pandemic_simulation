# 13 — Experiments

**Goal:** describe a setup in a file and run it many times with fixed seeds.
**Depends on:** 12.

## Build
Experiment file `experiments/<name>.json`:
```json
{
  "name": "malls_closed",
  "base_seed": 1000,
  "runs": 10,
  "days": 30,
  "population": 1000,
  "virus": { "transmission_prob_per_min": 0.001 },
  "patient_zero": { "mode": "random", "count": 1 },
  "closed_buildings": { "ids": [], "purposes": ["mall"] },
  "immune_share": 0.0
}
```
Missing keys fall back to `config/default.json` (`days`, `population`, `tick_seconds` and `virus` can be overridden; `virus` is merged key by key).

`Experiment` (`scripts/sim/experiment.gd`): `load_file(path)`, `validate(buildings) -> "" or error`, `make_config(i)`, `apply(sim)` (closures → immune share → patient zero), `describe(i, applied)` (config.json extras), `run_standalone(i, out_root)` (no scene; used by tests).

`patient_zero.mode`:
- `ids` — list of NPC ids.
- `random` — `count` random non-immune NPCs.
- `top_contacts` — `count` NPCs with the highest `contact_count` in `from_run` (path to a previous run's `npcs.csv`).

Seeded steps, in this order: population (05) → immune_share (exactly `round(share × population)` NPCs set `immune_forever`) → patient zero (never an immune NPC) → run.

Closures apply from tick 0. Homes can't be closed — reject the file with a clear error.

Seeds: run `i` uses `base_seed + i`. To compare two setups, give both files the same `base_seed` and `runs` so run `i` of each shares a seed.

Batch run: `godot --path . -- --experiment experiments/<name>.json` runs every run one after another, in the visual window at Max speed, writes output (spec 14), then quits (exit code 0; 1 if the file is invalid). `BatchRunner` (`scripts/sim/batch_runner.gd`) does this: it reopens all buildings, builds a new `Simulation` per run, swaps it into the `Sim` node (`replace_simulation` → views re-attach), and stops at `days`. The **Run experiment…** button in the top bar starts a file the same way, without quitting.
The window run and `run_standalone` write byte-identical files for the same seed (checked).

Example files to provide:
`baseline.json` · `malls_closed.json` · `immune_50.json` · `pandemic.json` (p = 0.2) · `flat.json` (p = 0.0025) · `top_spreader.json` (patient zero = most-contacted NPC of `output/baseline/run_0`; run baseline first). All: 10 runs × 30 days, base_seed 1000, 5 random patient zeros. p values are relative to the calibrated baseline 0.05 (spec 11).

Run time: ~7 ms per tick for 1,000 NPCs, so a 30-day run (43,200 ticks) takes ~5 minutes at Max speed and a 10-run experiment ~50 minutes.

Finding (6-day test runs): with the spec 07 desire rules, closing malls makes the outbreak *worse* (peak 97 % vs 83 %, a day earlier): NPCs whose need pointed at a closed mall move to their next need, often a crowded nightclub or restaurant. Whether closed destinations should send NPCs home instead is an open modelling choice.

## Done when
- `test_experiments`: same file and seed twice → byte-identical `seir.csv`.
- `test_experiments`: `immune_share` 0.2 with 1,000 NPCs → exactly 200 immune; no patient zero is immune.
- `test_experiments`: closing `home` is rejected.
- `malls_closed` with 2 runs finishes and writes 2 run folders with the right seeds and closures.
- `test_experiments`: every file in `experiments/` loads and validates; `top_contacts` picks the highest `contact_count` rows.
