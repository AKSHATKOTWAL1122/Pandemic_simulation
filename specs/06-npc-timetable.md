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

Sleep ends the morning after it starts (end hour ≤ start hour means "next day"). Weekday 0 = Monday; WORK and SCHOOL blocks happen on days whose weekday is 0–4. A block belongs to the day it starts on.

Jitter: at creation each NPC draws fixed offsets of −30 to +30 min (whole minutes) for each block's start and end, so people don't all move on the same tick. Stored on the NPC as `jitter_start` / `jitter_end: PackedInt32Array`, indexed by `Timetable.Kind` (SLEEP, WORK, SCHOOL). Every NPC draws all six values (SLEEP start, SLEEP end, WORK start, …) via `Timetable.draw_jitter(npc, rng, jitter_minutes)`, called by `Population.generate` as spec 05 step 9, after positions.

Departure: the NPC leaves at block start minus its estimated travel time (path length ÷ speed from specs 08–09). Pathfinding (spec 04) was built in parallel, so the timetable takes the travel time as a parameter; the caller (spec 08) computes it from the path.

Closed building (specs 12–13): if the block's building is closed, that block becomes free time.

API `Timetable` (`scripts/npc/timetable.gd`, `RefCounted`; `enum Kind { SLEEP, WORK, SCHOOL, FREE }`):
- `Timetable.new(config: ConfigStore, buildings: BuildingRegistry)` — reads the hours and `tick_seconds`; checks closures through `buildings.is_closed`.
- `current_block(npc, tick) -> {kind, building_id, start_tick, end_tick}` — `end_tick` exclusive; FREE has all three = −1. A block with a closed building is FREE.
- `next_block(npc, tick) -> {…}` — the next block with an open building whose `start_tick > tick` (looks a week ahead); FREE (−1s) if none.
- `departure_tick(block, travel_minutes: float) -> int` — `block.start_tick − ceil(travel_minutes × 60 / tick_seconds)`.
- `Timetable.estimate_travel_minutes(path_tiles, tiles_per_minute) -> float` — path length ÷ speed.
- Spec 08 each tick: if `current_block` isn't FREE and the NPC isn't at/heading to its building → go now; if FREE and `tick >= departure_tick(next_block(npc, tick), travel)` → leave for the next block; otherwise desires (spec 07).

## Config keys
`sleep_hours` [23, 7] · `work_hours` [9, 17] · `school_hours` [8, 15] · `jitter_minutes` 30

## Done when
- `test_timetable`: a worker at Mon 10:00 → WORK; Sat 10:00 → FREE; Tue 02:00 → SLEEP.
- `test_timetable`: a student at Wed 09:00 → SCHOOL; a NONE at Wed 09:00 → FREE.
- `test_timetable`: jitter is within ±30 min; closed workplace → FREE.
- `test_timetable` (extra): jitter moves block edges; everyone is asleep at Monday 00:00; `next_block` / `departure_tick` give the right ticks.
