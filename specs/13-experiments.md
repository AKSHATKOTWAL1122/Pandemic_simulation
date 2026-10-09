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
Missing keys fall back to `config/default.json`.

`patient_zero.mode`:
- `ids` — list of NPC ids.
- `random` — `count` random non-immune NPCs.
- `top_contacts` — `count` NPCs with the highest `contact_count` in `from_run` (path to a previous run's `npcs.csv`).

Seeded steps, in this order: population (05) → immune_share (exactly `round(share × population)` NPCs set `immune_forever`) → patient zero (never an immune NPC) → run.

Closures apply from tick 0. Homes can't be closed — reject the file with a clear error.

Seeds: run `i` uses `base_seed + i`. To compare two setups, give both files the same `base_seed` and `runs` so run `i` of each shares a seed.

Batch run: `godot --path . -- --experiment experiments/<name>.json` runs every run one after another, in the visual window at Max speed, writes output (spec 14), then quits. A menu in the app can also start an experiment file.

Example files to provide:
`baseline.json` · `malls_closed.json` · `immune_50.json` · `pandemic.json` (p = 0.2) · `flat.json` (p = 0.00005)

## Done when
- `test_experiments`: same file and seed twice → byte-identical `seir.csv`.
- `test_experiments`: `immune_share` 0.2 with 1,000 NPCs → exactly 200 immune; no patient zero is immune.
- `test_experiments`: closing `home` is rejected.
- `malls_closed` with 2 runs finishes and writes 2 run folders.
