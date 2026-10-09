# 06 — NPC timetable

**Goal:** fixed daily blocks that say where an NPC must be.
**Depends on:** 05.

## Build
Blocks:
| Who | Mon–Fri | Sat–Sun |
|---|---|---|
| Everyone | Sleep at home 23:00–07:00 | Sleep at home 23:00–07:00 |
| WORKER | Work 09:00–17:00 at `work_id` | free |
| STUDENT | School 08:00–15:00 at `school_id` | free |
| NONE | free | free |

Any time not in a block is **free time** (spec 07).

Jitter: at creation each NPC draws fixed offsets of −30 to +30 min for each block's start and end, so people don't all move on the same tick.

Departure: the NPC leaves at block start minus its estimated travel time (path length ÷ speed from specs 08–09).

Closed building (specs 12–13): if the block's building is closed, that block becomes free time.

API `Timetable.current_block(npc, tick) -> {kind: SLEEP | WORK | SCHOOL | FREE, building_id}`.

## Config keys
`sleep_hours` [23, 7] · `work_hours` [9, 17] · `school_hours` [8, 15] · `jitter_minutes` 30

## Done when
- `test_timetable`: a worker at Mon 10:00 → WORK; Sat 10:00 → FREE; Tue 02:00 → SLEEP.
- `test_timetable`: a student at Wed 09:00 → SCHOOL; a NONE at Wed 09:00 → FREE.
- `test_timetable`: jitter is within ±30 min; closed workplace → FREE.
