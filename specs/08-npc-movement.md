# 08 — NPC movement (walking and indoors)

**Goal:** NPCs physically walk their routes and move around inside buildings.
**Depends on:** 04, 07.

## Build
`Simulation` (`scripts/sim/simulation.gd`) holds one run: config, `SeededRng`, `GameClock`, buildings, paths, population, timetable, desires and the per-tick systems. `step()` runs the systems in a fixed order, then advances the clock. `Simulation.standalone(config)` builds a run with its own RNG, clock and buildings (tests, batch runs); the scene's `Sim` node builds one from the autoloads.

`NpcBehaviour` (`scripts/npc/npc_behaviour.gd`) — per tick, NPCs in id order:
1. `prev_pos = pos` (for drawing).
2. Needs grow (`Desires.grow`), no growth while asleep.
3. WALKING → move along the route; on arrival enter the building and decide.
   AT_BUILDING and `tick >= next_decision_tick` → decide.
4. AT_BUILDING and awake → wander indoors.

NPC activity (new fields on `NPC`): `AT_BUILDING` (with `building_id`), `WALKING` (`route`, `route_index`), `DRIVING` (spec 09).

Decisions only happen at decision points, so 1,000 NPCs stay cheap:
- In a timetable block (spec 06): at its building → next decision at block end; elsewhere → walk there.
- Free time, next block in another building → leave at `Timetable.departure_tick` using the real walk-path time.
- Free time, next block in this building (e.g. home before sleep) → stay put once it's less than `min_outing_minutes` away.
- Otherwise desires (spec 07): choose a destination, stay there for its stay length (capped by the departure deadline), then decide again. A stay cut short by leaving does not reset the need.

Trip: current position → own entrance → `Paths.walk` (tile centres) → destination entrance → a random point inside the destination.

Walking speed: 1.4 m/s = 21 tiles per game minute (`tile_metres` 4). Each tick the NPC moves `speed × tick_seconds` along its route.

Indoors: every 10 game minutes the NPC picks a random point inside the building's `rect` and walks there in a straight line. Sleeping NPCs don't wander. NPCs inside buildings are drawn on top of the building, so you can see crowds in malls.

Drawing (`scripts/npc/npc_view.gd`): one `_draw` of 1,000 dots, each at `lerp(prev_pos, pos, alpha)`. Dot radius 3 px; colour from spec 11 (grey until then).

Speed: the `Sim` node runs `ticks_per_second` ticks per real second (default 10; a game day ≈ 2.4 real minutes) with an accumulator; `alpha` is the fraction to the next tick. This replaces spec 01's `ticks_per_frame`: at one tick per frame a walker would jump 21 tiles per frame.

## Config keys
`walk_speed_mps` 1.4 · `tile_metres` 4 · `indoor_wander_minutes` 10 · `min_outing_minutes` 60 · `ticks_per_second` 10

## Done when
- On screen: in the morning dots stream from homes to work and school; in the evening they stream back.
- `test_movement`: during a 1-day run every NPC is always either inside its building or on a walk route; no NPC is ever on a WATER tile.
- `test_movement`: everyone is home at 03:00; ≥ 90 % of workers are at work at Mon 10:00; same seed → same positions.
- 1,000 NPCs at 10 ticks/s stay at ≥ 30 FPS.
