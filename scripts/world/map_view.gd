extends Node2D
## Draws the city: a TileMapLayer of flat-colour tiles, buildings tinted by first purpose, and building outlines.

const TILE_PX := 16
const PURPOSE_COLOURS: Dictionary = {
	"home": Color("#D9CBA3"),
	"workplace": Color("#9AA5B1"),
	"school": Color("#F4A259"),
	"restaurant": Color("#E07A5F"),
	"nightclub": Color("#8E5FA8"),
	"mall": Color("#F25F5C"),
}
const OUTLINE_COLOUR := Color(0, 0, 0, 0.35)

var _layer: TileMapLayer
var _atlas_index: Dictionary = {}  # tile type or purpose -> atlas x


func _ready() -> void:
	_layer = TileMapLayer.new()
	_layer.tile_set = _make_tile_set()
	_layer.show_behind_parent = true  # outlines in _draw go on top
	add_child(_layer)
	var map: CityMap = World.map
	var registry: BuildingRegistry = World.buildings
	for y in CityMap.SIZE:
		for x in CityMap.SIZE:
			var t := map.tile(x, y)
			var key: Variant = t
			if t == CityMap.TileType.BUILDING:
				var id := registry.at_tile(x, y)
				if id >= 0:
					key = registry.by_id(id).purposes[0]
			_layer.set_cell(Vector2i(x, y), 0, Vector2i(_atlas_index[key], 0))
	queue_redraw()


func _draw() -> void:
	for b in World.buildings.buildings:
		var r := Rect2(Vector2(b.rect.position) * TILE_PX, Vector2(b.rect.size) * TILE_PX)
		draw_rect(r, OUTLINE_COLOUR, false, 2.0)


func _make_tile_set() -> TileSet:
	var colours: Array[Color] = []
	for t: int in CityMap.TILE_COLOURS:
		_atlas_index[t] = colours.size()
		colours.append(CityMap.TILE_COLOURS[t])
	for p: String in PURPOSE_COLOURS:
		_atlas_index[p] = colours.size()
		colours.append(PURPOSE_COLOURS[p])
	var image := Image.create(TILE_PX * colours.size(), TILE_PX, false, Image.FORMAT_RGBA8)
	for i in colours.size():
		image.fill_rect(Rect2i(i * TILE_PX, 0, TILE_PX, TILE_PX), colours[i])
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for i in colours.size():
		source.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_PX, TILE_PX)
	tile_set.add_source(source, 0)
	return tile_set
