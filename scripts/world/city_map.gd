class_name CityMap
extends RefCounted
## The city ground: a SIZE x SIZE grid of tiles, loaded from data/map.png (one pixel per tile).

enum TileType { WATER, ROAD, SIDEWALK, BUILDING }

const SIZE := 256
const MAP_PATH := "res://data/map.png"
const META_PATH := "res://data/buildings.json"
const TILE_COLOURS: Dictionary = {
	TileType.WATER: Color("#1E4A8C"),
	TileType.ROAD: Color("#3A3A3A"),
	TileType.SIDEWALK: Color("#A0A0A0"),
	TileType.BUILDING: Color("#C8B48C"),
}

var tiles := PackedByteArray()
var islands: Array[Rect2i] = []
var bridges: Array[Rect2i] = []


static func load_default() -> CityMap:
	var bytes := FileAccess.get_file_as_bytes(MAP_PATH)
	var image := Image.new()
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK:
		push_error("CityMap: cannot read %s" % MAP_PATH)
		return null
	var map := from_image(image)
	if map == null:
		return null
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if typeof(meta) != TYPE_DICTIONARY:
		push_error("CityMap: cannot read %s" % META_PATH)
		return null
	for island: Dictionary in meta["islands"]:
		map.islands.append(_rect(island["rect"]))
	for bridge: Dictionary in meta["bridges"]:
		map.bridges.append(_rect(bridge["rect"]))
	return map


## Returns null (and names the pixel) if the image has a colour that isn't a tile type.
static func from_image(image: Image) -> CityMap:
	if image.get_width() != SIZE or image.get_height() != SIZE:
		push_error("CityMap: map must be %dx%d, got %dx%d" % [SIZE, SIZE, image.get_width(), image.get_height()])
		return null
	var by_colour: Dictionary = {}
	for type: int in TILE_COLOURS:
		by_colour[(TILE_COLOURS[type] as Color).to_rgba32()] = type
	var map := CityMap.new()
	map.tiles.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var key := image.get_pixel(x, y).to_rgba32()
			if not by_colour.has(key):
				push_error("CityMap: unknown colour #%s at pixel (%d, %d)" % [image.get_pixel(x, y).to_html(false), x, y])
				return null
			map.tiles[y * SIZE + x] = by_colour[key]
	return map


static func _rect(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE


func tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return TileType.WATER
	return tiles[y * SIZE + x]


## Island index, or -1 for water and bridges.
func island_of(x: int, y: int) -> int:
	if tile(x, y) == TileType.WATER:
		return -1
	for i in islands.size():
		if islands[i].has_point(Vector2i(x, y)):
			return i
	return -1
