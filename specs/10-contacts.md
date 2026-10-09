# 10 — Contacts

**Goal:** detect when any two NPCs are close, whatever their health state, and record contact events.
**Depends on:** 09.

## Build
`ContactTracker` (`scripts/sim/contact_tracker.gd`), run by `Simulation.step` right after NPC movement.

In range: two NPCs are within `virus.infection_radius_m` (default 2 m = 0.5 tile) at the end of a tick **and** are in the same place:
- both inside the same building, or
- both outside buildings (walking or driving).
One inside and one outside never count (walls).

Spatial grid: bucket NPCs by cells of radius size each tick; check own cell + 8 neighbours.

Contact event: logged when a pair becomes in range after **not** being in range on the previous tick. While they stay in range it's the same encounter — no new event.

Event fields: `tick`, `a`, `b` (a < b), `x`, `y` (midpoint, tiles), `building_id` (-1 outside), `in_car` (true if either is driving).

Per tick, the tracker exposes the in-range pairs sorted by (a, b) as `pair_a`, `pair_b`, `pair_in_car` for spec 11, and this tick's new events in `events`.

Each NPC keeps `contact_count` (field on `NPC`) = number of encounters.

## Config keys
`virus.infection_radius_m` 2.0 (inside the `virus` object shared with spec 11)

## Done when
- `test_contacts`: two NPCs 1 m apart → 1 event; still close next tick → no new event; separate, then close again → second event.
- `test_contacts`: one inside a building, one on the sidewalk 1 m away → no event.
- A 1-day run prints the contact_count distribution (not all zero).
- The contact step takes < 5 ms per tick for 1,000 NPCs (print it).
