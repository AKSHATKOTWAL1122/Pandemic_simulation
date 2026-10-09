# 09 — Cars

**Goal:** households with a car drive their longer trips.
**Depends on:** 08.

## Build
Cars are plain data (`scripts/npc/car.gd`): `id`, `household_id`, `tile` (where parked), `driver` (NPC id or -1). One NPC per car.
`CarFleet` (`scripts/npc/car_fleet.gd`): `CarFleet.create(population, buildings, paths)` makes one car per `households_with_car()`, parked at the `nearest_road` of the home; `of_household(id) -> Car or null`. Held by `Simulation.fleet`.

Mode choice at departure — drive only if **all** are true:
- the household owns a car,
- the car isn't being driven and is parked within 3 tiles (Manhattan) of the NPC's current building's `nearest_road`,
- the walk path is longer than 30 tiles.
Otherwise walk.

Driving (`NpcBehaviour.start_trip`): NPC jumps to the car, drives `Paths.drive` to the destination's `nearest_road`, parks the car there, enters the building. The car stays there until that NPC drives again. So if a family member takes the car, others walk.

Speed: 30 km/h ≈ 125 tiles per game minute. No collisions, no lanes, no lights; cars may overlap.

While driving, `npc.in_car = true` and the NPC's position is the car's position.

Drawing: moving cars are 10 × 6 px rectangles coloured by the driver's SEIR state. Parked cars hidden (toggle in spec 12).

## Config keys
`drive_speed_kmh` 30 · `drive_min_tiles` 30 · `car_pickup_radius` 3

Note: at 125 tiles/min most drives last 1–3 ticks, so only ~10 cars are on the road at once; traffic is brief on screen.

## Done when
- `test_cars`: NPC with a car and a 100-tile trip drives; NPC without a car walks; car ends at the destination road tile.
- `test_cars`: after one family member drives away, another leaving home walks.
- `test_cars`: a trip of ≤ 30 tiles is walked even with a car.
- `test_cars`: between 00:00 and 10:00 on Monday, cars cross bridges (count printed).
