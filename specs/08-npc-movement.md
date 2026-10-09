# 08 — NPC movement (walking and indoors)

**Goal:** NPCs physically walk their routes and move around inside buildings.
**Depends on:** 04, 07.

## Build
NPC activity (new field): `AT_BUILDING(building_id)`, `WALKING(path, index)`, `DRIVING` (spec 09).

Trip: current building → its entrance → `Paths.walk` to the destination entrance → inside.

Walking speed: 1.4 m/s = 21 tiles per game minute. Each tick the NPC moves `speed × tick_seconds` along its path.

Indoors: every 10 game minutes the NPC picks a random tile inside the building's `rect` plus a random offset inside that tile, and walks there in a straight line. NPCs inside buildings are drawn on top of the building, so you can see crowds in malls.

Drawing: positions are interpolated between ticks so movement looks smooth. Dot is 6 px; colour comes from spec 11 (grey until then).

## Config keys
`walk_speed_mps` 1.4 · `indoor_wander_minutes` 10

## Done when
- On screen: in the morning dots stream from homes to work and school; in the evening they stream back.
- `test_movement`: during a 1-day run every NPC is always either inside a building or on a walk path; no NPC is ever on a WATER tile.
- 1,000 NPCs at 1 tick per frame stay at ≥ 30 FPS (print it).
