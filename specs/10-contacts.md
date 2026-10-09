# 10 — Contacts

**Goal:** detect when any two NPCs are close, whatever their health state, and record contact events.
**Depends on:** 09.

## Build
In range: two NPCs are within `infection_radius_m` (default 2 m = 0.5 tile) at the end of a tick **and** are in the same place:
- both inside the same building, or
- both outside buildings (walking or driving).
One inside and one outside never count (walls).

Spatial grid: bucket NPCs by tile each tick; check own tile + 8 neighbours.

Contact event: logged when a pair becomes in range after **not** being in range on the previous tick. While they stay in range it's the same encounter — no new event.

Event fields: `tick`, `a`, `b` (a < b), `x`, `y` (midpoint, tiles), `building_id` (-1 outside), `in_car` (true if either is driving).

Per tick, the system also hands the sorted list of in-range pairs (with `in_car`) to spec 11.

Each NPC keeps `contact_count` = number of encounters.

## Config keys
`infection_radius_m` 2.0

## Done when
- `test_contacts`: two NPCs 1 m apart → 1 event; still close next tick → no new event; separate, then close again → second event.
- `test_contacts`: one inside a building, one on the sidewalk 1 m away → no event.
- A 1-day run prints the contact_count distribution (not all zero).
- The contact step takes < 5 ms per tick for 1,000 NPCs (print it).
