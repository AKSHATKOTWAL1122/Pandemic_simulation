# 14 — Data export

**Goal:** write every run to disk for analysis.
**Depends on:** 13.

## Build
Folder: `output/<experiment name>/run_<i>/` (`output/live/run_<timestamp>/` for runs started by hand).

| File | Columns | Rows |
|---|---|---|
| `config.json` | fully resolved config, incl. seed and map path | — |
| `seir.csv` | tick, day, hour, S, E, I, R, immune_forever | one per tick |
| `contacts.csv` | tick, a, b, x, y, building_id, in_car | one per contact event (spec 10) |
| `infections.csv` | tick, infector, infected, x, y, building_id, in_car | one per S→E, plus patient zeros/manual (infector = -1) |
| `npcs.csv` | id, household_id, home_id, occupation, work_id, school_id, has_car, immune_forever, contact_count, first_infected_tick | one per NPC, written at the end |

Format: header row, comma-separated, `\n` line endings, no index column, booleans as 0/1.
Writing: buffer in memory, flush every game hour and at the end of the run.
`contacts.csv` can reach millions of rows; that's expected.

## Done when
- After a 1-day run all 5 files exist with headers.
- `seir.csv` rows == ticks run.
- `infections.csv` rows == number of S→E transitions + patient zeros.
- `npcs.csv` rows == population.
