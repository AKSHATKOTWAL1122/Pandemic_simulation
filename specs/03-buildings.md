# 03 — Buildings

**Goal:** group BUILDING tiles into buildings with ids, purposes and entrances.
**Depends on:** 02.

## Build
File `data/buildings.json`, written by `tools/make_map.py` together with `map.png`. One entry per building:
```json
{"id": 17, "rect": [x, y, w, h], "entrance": [x, y], "purposes": ["home"], "home_capacity": 6, "jobs": 0}
```
Rules:
- `rect` covers only BUILDING tiles. Buildings don't overlap. Every BUILDING tile belongs to exactly one building.
- `entrance` is a tile inside `rect` that touches a SIDEWALK tile (4-neighbour).
- `purposes`: one or more of `home`, `workplace`, `school`, `restaurant`, `nightclub`, `mall`.
- `home_capacity` > 0 only if `home` is a purpose.
- `jobs` = worker slots. Any building with `workplace`, `school`, `restaurant`, `nightclub` or `mall` has `jobs` > 0.

City mix (enforced by `make_map.py`):
- Exactly 2 malls, on different islands, each at least 10 × 10 tiles.
- 3 schools, ~15 restaurants, ~6 nightclubs.
- A few mixed buildings (e.g. `home` + `restaurant`).
- Total `home_capacity` ≥ 1.2 × `population`.
- Total `jobs` ≥ the number of workers spec 05 will create.

Runtime registry `Buildings` (`scripts/world/buildings.gd`):
`get(id)`, `with_purpose(p) -> Array`, `at_tile(x, y) -> id or -1`, `is_closed(id)`, `set_closed(id, bool)` (default open; used by 12 and 13).

Drawing: building tiles tinted by first purpose. Malls must stand out. Colours live in spec 12's legend.

## Not in this spec
NPCs, closures logic beyond the flag.

## Done when
- `test_buildings`: every BUILDING tile maps to exactly one building; no overlaps; every entrance touches a sidewalk.
- `test_buildings`: exactly 2 malls on different islands; capacity and job totals hold.
- On screen, the purposes are visible by colour.
