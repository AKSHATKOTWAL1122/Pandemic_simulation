# 03 — Buildings

**Goal:** group BUILDING tiles into buildings with ids, purposes and entrances.
**Depends on:** 02.

## Build
File `data/buildings.json`, written by `tools/make_map.py` together with `map.png`:
```json
{
  "seed": 2026,
  "islands":   [{"id": 0, "rect": [x, y, w, h]}],
  "bridges":   [{"id": 0, "rect": [x, y, w, h]}],
  "buildings": [{"id": 17, "island": 0, "rect": [x, y, w, h], "entrance": [x, y], "purposes": ["home"], "home_capacity": 6, "jobs": 0}]
}
```
Building ids run 0..n-1 in file order. Bridge rects cover only the part over water.
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

Runtime: `Building` (`scripts/world/building.gd`) and `BuildingRegistry` (`scripts/world/building_registry.gd`), reachable as `World.buildings` (autoload `World` also holds `World.map`):
`by_id(id)` (not `get`, which every Godot Object already has), `with_purpose(p) -> Array[Building]`, `at_tile(x, y) -> id or -1`, `is_closed(id)`, `set_closed(id, bool)` (default open; used by 12 and 13).

Drawing: building tiles tinted by first purpose. Malls must stand out. Colours live in spec 12's legend.

## Not in this spec
NPCs, closures logic beyond the flag.

## Done when
- `test_buildings`: every BUILDING tile maps to exactly one building; no overlaps; every entrance touches a sidewalk.
- `test_buildings`: exactly 2 malls on different islands; capacity and job totals hold.
- On screen, the purposes are visible by colour.
