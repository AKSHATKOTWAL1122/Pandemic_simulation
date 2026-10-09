# 02 — Tile map

**Goal:** the city ground — a 256 × 256 grid loaded from a file and drawn on screen.
**Depends on:** 01.

## Build
Tile types (`enum TileType`): `WATER 0`, `ROAD 1`, `SIDEWALK 2`, `BUILDING 3`.

Map file `data/map.png`: 256 × 256 px, one pixel per tile, exact colours:
| Type | Colour |
|---|---|
| WATER | `#1E4A8C` |
| ROAD | `#3A3A3A` |
| SIDEWALK | `#A0A0A0` |
| BUILDING | `#C8B48C` |
Any other colour is a load error that names the pixel.

Making the map: `tools/make_map.py` (Python + Pillow, fixed seed) writes `map.png` once. The file is committed; it may be hand-edited later. Layout rules:
- Map border is water.
- 3 islands, separated by water channels at least 6 tiles wide.
- 5 bridges in total; each is a straight road 2 tiles wide with 1 sidewalk tile on each side. Every island is reachable.
- Each island has a road grid: roads 2 tiles wide, 1 sidewalk tile on each side, blocks 12–24 tiles across.
- Block interiors are BUILDING tiles.

Loader `scripts/world/city_map.gd` (`CityMap`): `tile(x, y) -> TileType`, `SIZE = 256`, `island_of(x, y) -> int` (-1 for water and bridges). Island and bridge rects come from `data/buildings.json` (spec 03), because bridges join the land into one piece.
`data/` has a `.gdignore`, so Godot doesn't import the PNG; it's read as raw bytes.

Drawing: `TileMapLayer` with 4 flat-colour tiles, 16 px per tile. `Camera2D`: right- or middle-drag to pan (left click is kept for selecting in spec 12), mouse wheel zooms around the cursor from fit-to-map up to 4×, starts framing the whole map.

## Not in this spec
Building purposes (03), textures, animation.

## Done when
- `test_map`: map is 256 × 256; corner tile is WATER; exactly 3 islands.
- `test_map`: all ROAD tiles form one connected network (flood fill).
- `test_map`: all ROAD + SIDEWALK tiles form one connected network.
- The whole map shows on screen; pan and zoom work.
