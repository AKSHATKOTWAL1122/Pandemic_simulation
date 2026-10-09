extends BaseTest

const T := CityMap.TileType


## Number of 4-connected components among tiles where include(x, y) is true.
static func components(map: CityMap, include: Callable) -> int:
	var seen := PackedByteArray()
	seen.resize(CityMap.SIZE * CityMap.SIZE)
	var count := 0
	for start in CityMap.SIZE * CityMap.SIZE:
		var sx := start % CityMap.SIZE
		@warning_ignore("integer_division")
		var sy := start / CityMap.SIZE
		if seen[start] == 1 or not include.call(sx, sy):
			continue
		count += 1
		seen[start] = 1
		var stack: Array[Vector2i] = [Vector2i(sx, sy)]
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var q := p + d
				if not map.in_bounds(q.x, q.y):
					continue
				var qi := q.y * CityMap.SIZE + q.x
				if seen[qi] == 0 and include.call(q.x, q.y):
					seen[qi] = 1
					stack.append(q)
	return count


func test_map_is_256_square_with_water_corner() -> void:
	var map := CityMap.load_default()
	check(map != null, "map failed to load")
	if map == null:
		return
	check(map.tiles.size() == 256 * 256, "map has %d tiles" % map.tiles.size())
	check(map.tile(0, 0) == T.WATER, "corner (0, 0) is not water")
	check(map.tile(255, 255) == T.WATER, "corner (255, 255) is not water")


func test_border_is_water() -> void:
	var map := CityMap.load_default()
	var ok := true
	for i in CityMap.SIZE:
		for p: Vector2i in [Vector2i(i, 0), Vector2i(i, 255), Vector2i(0, i), Vector2i(255, i)]:
			if map.tile(p.x, p.y) != T.WATER:
				ok = false
	check(ok, "map border has non-water tiles")


func test_exactly_three_islands() -> void:
	var map := CityMap.load_default()
	check(map.islands.size() == 3, "metadata lists %d islands" % map.islands.size())
	var land_without_bridges := func(x: int, y: int) -> bool:
		if map.tile(x, y) == T.WATER:
			return false
		for b in map.bridges:
			if b.has_point(Vector2i(x, y)):
				return false
		return true
	var n := components(map, land_without_bridges)
	check(n == 3, "land without bridges forms %d components, expected 3" % n)
	check(map.bridges.size() == 5, "expected 5 bridges, got %d" % map.bridges.size())


func test_roads_form_one_network() -> void:
	var map := CityMap.load_default()
	var n := components(map, func(x: int, y: int) -> bool: return map.tile(x, y) == T.ROAD)
	check(n == 1, "ROAD tiles form %d networks" % n)


func test_roads_and_sidewalks_form_one_network() -> void:
	var map := CityMap.load_default()
	var walkable := func(x: int, y: int) -> bool:
		var t := map.tile(x, y)
		return t == T.ROAD or t == T.SIDEWALK
	var n := components(map, walkable)
	check(n == 1, "ROAD + SIDEWALK tiles form %d networks" % n)


func test_unknown_colour_is_rejected() -> void:
	var image := Image.create(CityMap.SIZE, CityMap.SIZE, false, Image.FORMAT_RGBA8)
	image.fill(CityMap.TILE_COLOURS[T.WATER])
	image.set_pixel(5, 7, Color.MAGENTA)
	check(CityMap.from_image(image) == null, "a magenta pixel was accepted")


func test_island_of() -> void:
	var map := CityMap.load_default()
	check(map.island_of(0, 0) == -1, "water should be island -1")
	check(map.island_of(20, 20) == 0, "(20, 20) should be on island 0")
	check(map.island_of(200, 200) == 2, "(200, 200) should be on island 2")
