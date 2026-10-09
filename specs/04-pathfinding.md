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

API `Paths` (`scripts/world/paths.gd`):
- `walk(from: Vector2i, to: Vector2i) -> Array[Vector2i]`
- `drive(from: Vector2i, to: Vector2i) -> Array[Vector2i]`
- `nearest_road(tile: Vector2i) -> Vector2i` — BFS from the tile to the closest ROAD tile. Precompute for every entrance.
- `length(path) -> int` tiles.

Optional cache: last 2,000 `(from, to)` results per grid.

Moving inside a building does not use these grids (spec 08).

## Not in this spec
Moving anything along the paths.

## Done when
- `test_paths`: a walk path between entrances on different islands exists and crosses a bridge.
- `test_paths`: walk paths never contain WATER or non-entrance BUILDING tiles; drive paths contain only ROAD.
- `test_paths`: 1,000 random walk queries finish; time is printed (target < 2 s).
