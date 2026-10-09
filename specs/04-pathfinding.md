# 04 — Pathfinding

**Goal:** routes between building entrances, for walking and for driving.
**Depends on:** 03.

## Build
Two `AStarGrid2D` grids, 4 directions (no diagonals):

| Grid | Walkable tiles | Cost |
|---|---|---|
| Walk | SIDEWALK | 1 |
| | ROAD (crossing) | 4 |
| | Building **entrances** only | 1 |
| | Other BUILDING, WATER | solid |
| Drive | ROAD | 1 |
| | everything else | solid |

API `Paths` (`scripts/world/paths.gd`, `class_name Paths extends RefCounted`):
- `static build(map: CityMap, buildings: BuildingRegistry, config: ConfigStore) -> Paths` — builds both grids and precomputes `nearest_road` for every entrance. Takes its inputs as arguments so tests can build it without autoloads.
- `walk(from: Vector2i, to: Vector2i) -> Array[Vector2i]`
- `drive(from: Vector2i, to: Vector2i) -> Array[Vector2i]` — both ends must be ROAD tiles (use `nearest_road`).
- Paths include both end tiles. No route (an end out of bounds, solid, or unreachable) → empty array.
- `nearest_road(tile: Vector2i) -> Vector2i` — BFS (neighbour order up, right, down, left) over walk-grid tiles from the tile to the closest ROAD tile; `Paths.NO_TILE` `(-1, -1)` if none. Precomputed for every entrance; other tiles are computed on first call and cached.
- `length(path: Array[Vector2i]) -> int` — steps (tiles moved) = `path.size() - 1`, 0 for an empty path.

Cache: last `path_cache_size` `(from, to)` results per grid (ring buffer, oldest dropped first; 0 disables). Callers get a copy, so changing a returned path never changes the cache. Results don't depend on the cache.

Wiring (on `main`, after merge): autoload `World` gets `var paths: Paths`, set after `map` and `buildings` with `paths = Paths.build(map, buildings, Config)`. Specs 08 and 09 use `World.paths`.

Moving inside a building does not use these grids (spec 08).

## Config keys
`walk_road_cost` 4 (walk-grid weight of a ROAD tile; SIDEWALK and entrances are 1) · `path_cache_size` 2000

## Not in this spec
Moving anything along the paths.

## Done when
- `test_paths`: a walk path between entrances on different islands exists and crosses a bridge.
- `test_paths`: walk paths never contain WATER or non-entrance BUILDING tiles; drive paths contain only ROAD.
- `test_paths`: 1,000 random walk queries finish; time is printed (target < 2 s).
