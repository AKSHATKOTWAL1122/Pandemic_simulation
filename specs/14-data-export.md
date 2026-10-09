# 14 — Data export

**Goal:** write every run to disk for analysis.
**Depends on:** 13.

## Build
`RunExporter` (`scripts/sim/run_exporter.gd`), a `Simulation` listener.
Folder: `output/<experiment name>/run_<i>/` (`output/live/run_<timestamp>/` for runs started by hand, when `export_live_runs` is true; npcs.csv is written when the app closes).

| File | Columns | Rows |
|---|---|---|
| `config.json` | fully resolved config, incl. seed and map path | — |
| `seir.csv` | tick, day, hour, S, E, I, R, immune_forever | one per tick |
| `contacts.csv` | tick, a, b, x, y, building_id, in_car | one per contact event (spec 10) |
| `infections.csv` | tick, infector, infected, x, y, building_id, in_car | one per S→E, plus patient zeros/manual (infector = -1) |
| `npcs.csv` | id, household_id, home_id, occupation, work_id, school_id, has_car, immune_forever, contact_count, first_infected_tick | one per NPC, written at the end |

Format: header row, comma-separated, `\n` line endings, no index column, booleans as 0/1, positions with 3 decimals.

Conventions (agreed with the spec 15 analysis):
- `seir.csv` row `t` = counts **after** tick `t`; ticks start at 0, so patient zeros are already I in row 0. `day` = `tick × tick_seconds // 86400`, `hour` = whole hour of the day.
- `R` includes `immune_forever` NPCs, so S + E + I + R = population; `immune_forever` = how many have the flag.
- `x`, `y` are float tiles; an event is on tile `(floor(x), floor(y))`, y pointing down as in `map.png`.
- `npcs.csv`: `occupation` is `WORKER` / `STUDENT` / `NONE`; `-1` for no work/school or never infected; `first_infected_tick` is the first infection only.
- `infections.csv`: one row per S→E (an NPC can appear again after losing immunity) plus one per patient zero / manual infection (`infector` -1) at the NPC's own position and building.
- `config.json`: `name`, `run`, `seed`, `base_seed`, `tick_seconds`, `days`, `population`, `virus`, `immune_share`, `immune_count`, `patient_zero`, `patient_zero_ids`, `closed_buildings`, `closed_building_ids`, `map_path`, `buildings_path`, `experiment_file`.
Writing: buffer in memory, flush every game hour and at the end of the run.
`contacts.csv` can reach millions of rows; that's expected.

## Config keys
`export_live_runs` true

## Done when
Checked by `test_experiments::test_one_day_export_files_and_row_counts`, and by running every spec 15 script on real output.
- After a 1-day run all 5 files exist with headers.
- `seir.csv` rows == ticks run.
- `infections.csv` rows == number of S→E transitions + patient zeros.
- `npcs.csv` rows == population.
