# 09 — Cars

**Goal:** households with a car drive their longer trips.
**Depends on:** 08.

## Build
Cars are plain data: `id`, `household_id`, `tile` (where parked), `driver` (NPC id or -1). One NPC per car.
At start each car is parked at the `nearest_road` of its household's home.

Mode choice at departure — drive only if **all** are true:
- the household owns a car,
- the car is parked within 3 tiles of the NPC's current building's `nearest_road`,
- the walk path is longer than 30 tiles.
Otherwise walk.

Driving: NPC jumps from entrance to its `nearest_road`, drives `Paths.drive` to the destination's `nearest_road`, parks the car there, enters the building. The car stays there until that NPC drives again. So if a family member takes the car, others walk.

Speed: 30 km/h ≈ 125 tiles per game minute. No collisions, no lanes, no lights; cars may overlap.

While driving, `npc.in_car = true` and the NPC's position is the car's position.

Drawing: moving cars are 10 × 6 px rectangles coloured by the driver's SEIR state. Parked cars hidden (toggle in spec 12).

## Config keys
`drive_speed_kmh` 30 · `drive_min_tiles` 30 · `car_pickup_radius` 3

## Done when
- `test_cars`: NPC with a car and a 100-tile trip drives; NPC without a car walks; car ends at the destination road tile.
- `test_cars`: after one family member drives away, another leaving home walks.
- On screen: traffic is visible on bridges at 08:00 and 17:00.
