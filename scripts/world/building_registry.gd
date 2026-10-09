class_name BuildingRegistry
extends RefCounted
## All buildings, loaded from data/buildings.json, with a per-tile lookup.

var buildings: Array[Building] = []
var _by_tile := PackedInt32Array()


static func load_default() -> BuildingRegistry:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(CityMap.META_PATH))
	if typeof(meta) != TYPE_DICTIONARY:
		push_error("BuildingRegistry: cannot read %s" % CityMap.META_PATH)
		return null
	return from_entries(meta["buildings"])


static func from_entries(entries: Array) -> BuildingRegistry:
	var registry := BuildingRegistry.new()
	registry._by_tile.resize(CityMap.SIZE * CityMap.SIZE)
	registry._by_tile.fill(-1)
	for entry: Dictionary in entries:
		var b := Building.new()
		b.id = int(entry["id"])
		b.island = int(entry["island"])
		var r: Array = entry["rect"]
		b.rect = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		b.entrance = Vector2i(int(entry["entrance"][0]), int(entry["entrance"][1]))
		b.purposes = PackedStringArray(entry["purposes"])
		b.home_capacity = int(entry["home_capacity"])
		b.jobs = int(entry["jobs"])
		assert(b.id == registry.buildings.size(), "building ids must be 0..n-1 in order")
		registry.buildings.append(b)
		for y in range(b.rect.position.y, b.rect.end.y):
			for x in range(b.rect.position.x, b.rect.end.x):
				registry._by_tile[y * CityMap.SIZE + x] = b.id
	return registry


func by_id(id: int) -> Building:
	return buildings[id]


func count() -> int:
	return buildings.size()


func with_purpose(purpose: String) -> Array[Building]:
	var result: Array[Building] = []
	for b in buildings:
		if b.has_purpose(purpose):
			result.append(b)
	return result


## Building id at a tile, or -1.
func at_tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= CityMap.SIZE or y >= CityMap.SIZE:
		return -1
	return _by_tile[y * CityMap.SIZE + x]


func is_closed(id: int) -> bool:
	return buildings[id].closed


func set_closed(id: int, value: bool) -> void:
	buildings[id].closed = value
