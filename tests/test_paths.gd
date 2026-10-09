extends BaseTest

const T := CityMap.TileType
const RANDOM_PAIRS := 300
const TIMED_QUERIES := 1000

static var _map: CityMap
static var _reg: BuildingRegistry
static var _paths: Paths


## Map, buildings and paths are built once and shared by every test in this file.
static func shared() -> Paths:
	if _paths == null:
		_map = CityMap.load_default()
		_reg = BuildingRegistry.load_default()
		_paths = fresh_paths()
	return _paths


static func fresh_paths() -> Paths:
	var config := ConfigStore.new()
	var paths := Paths.build(_map, _reg, config)
	config.free()
	return paths


static func make_rng(seed_value: int) -> SeededRng:
	var rng := SeededRng.new()
	rng.reseed(seed_value)
	return rng


func random_building(rng: SeededRng) -> Building:
	return _reg.by_id(rng.randi_range(0, _reg.count() - 1))


func is_entrance(p: Vector2i) -> bool:
	var id := _reg.at_tile(p.x, p.y)
	return id != -1 and _reg.by_id(id).entrance == p


## Empty string if the path is a 4-connected chain from `from` to `to`, else what's wrong.
func chain_error(path: Array[Vector2i], from: Vector2i, to: Vector2i) -> String:
	if path.is_empty():
		return "no path %s -> %s" % [from, to]
	if path[0] != from or path[path.size() - 1] != to:
		return "path %s -> %s has ends %s, %s" % [from, to, path[0], path[path.size() - 1]]
	for i in range(1, path.size()):
		var d := path[i] - path[i - 1]
		if absi(d.x) + absi(d.y) != 1:
			return "path %s -> %s jumps from %s to %s" % [from, to, path[i - 1], path[i]]
	return ""


func walk_tile_error(p: Vector2i) -> String:
	var t := _map.tile(p.x, p.y)
	if t == T.WATER:
		return "walk path enters WATER at %s" % p
	if t == T.BUILDING and not is_entrance(p):
		return "walk path enters non-entrance BUILDING tile %s" % p
	return ""


func test_walk_between_islands_crosses_bridge() -> void:
	var paths := shared()
	var first_on_island: Dictionary = {}
	for b in _reg.buildings:
		if not first_on_island.has(b.island):
			first_on_island[b.island] = b
	check(first_on_island.size() == 3, "expected buildings on 3 islands, got %d" % first_on_island.size())
	for pair: Array in [[0, 1], [0, 2], [1, 2]]:
		if not first_on_island.has(pair[0]) or not first_on_island.has(pair[1]):
			continue
		var a: Building = first_on_island[pair[0]]
		var b: Building = first_on_island[pair[1]]
		var path := paths.walk(a.entrance, b.entrance)
		var err := chain_error(path, a.entrance, b.entrance)
		check(err == "", "island %d -> %d: %s" % [pair[0], pair[1], err])
		var on_bridge := false
		for p in path:
			for r in _map.bridges:
				if r.has_point(p):
					on_bridge = true
		check(on_bridge, "walk path island %d -> %d never touches a bridge" % [pair[0], pair[1]])


func test_walk_paths_avoid_water_and_buildings() -> void:
	var paths := shared()
	var rng := make_rng(404)
	var errors: Array[String] = []
	for i in RANDOM_PAIRS:
		var a := random_building(rng).entrance
		var b := random_building(rng).entrance
		var path := paths.walk(a, b)
		var err := chain_error(path, a, b)
		if err != "":
			errors.append(err)
			continue
		for p in path:
			err = walk_tile_error(p)
			if err != "":
				errors.append(err)
				break
	rng.free()
	check(errors.is_empty(), "%d bad walk paths, first: %s" % [errors.size(), errors.slice(0, 3)])


func test_drive_paths_only_road() -> void:
	var paths := shared()
	var rng := make_rng(405)
	var errors: Array[String] = []
	for i in RANDOM_PAIRS:
		var a := paths.nearest_road(random_building(rng).entrance)
		var b := paths.nearest_road(random_building(rng).entrance)
		var path := paths.drive(a, b)
		var err := chain_error(path, a, b)
		if err != "":
			errors.append(err)
			continue
		for p in path:
			if _map.tile(p.x, p.y) != T.ROAD:
				errors.append("drive path %s -> %s leaves the road at %s" % [a, b, p])
				break
	rng.free()
	check(errors.is_empty(), "%d bad drive paths, first: %s" % [errors.size(), errors.slice(0, 3)])


func test_nearest_road_for_every_entrance() -> void:
	var paths := shared()
	var bad: Array[String] = []
	var longest := 0
	for b in _reg.buildings:
		var road := paths.nearest_road(b.entrance)
		if _map.tile(road.x, road.y) != T.ROAD:
			bad.append("building %d: nearest_road %s is not ROAD" % [b.id, road])
			continue
		var path := paths.walk(b.entrance, road)
		var err := chain_error(path, b.entrance, road)
		if err != "":
			bad.append("building %d: %s" % [b.id, err])
			continue
		longest = maxi(longest, paths.length(path))
	check(bad.is_empty(), "%d entrances without a reachable road, first: %s" % [bad.size(), bad.slice(0, 3)])
	print("        nearest_road: longest entrance -> road walk is %d steps" % longest)


func test_no_route_and_length() -> void:
	var paths := shared()
	var b := _reg.by_id(0)
	var road := paths.nearest_road(b.entrance)
	check(paths.walk(b.entrance, Vector2i(0, 0)).is_empty(), "walk to WATER should be empty")
	check(paths.walk(Vector2i(-1, 5), b.entrance).is_empty(), "walk from outside the map should be empty")
	check(paths.drive(b.entrance, road).is_empty(), "drive from a BUILDING tile should be empty")
	var interior := b.rect.position if b.rect.position != b.entrance else b.rect.end - Vector2i.ONE
	check(paths.walk(b.entrance, interior).is_empty(), "walk into a non-entrance BUILDING tile should be empty")
	var empty: Array[Vector2i] = []
	check(paths.length(empty) == 0, "length of empty path should be 0")
	var single: Array[Vector2i] = [road]
	check(paths.length(single) == 0, "length of one-tile path should be 0")
	check(paths.walk(road, road).size() == 1, "walk to the same tile should be that tile")
	var path := paths.walk(b.entrance, road)
	check(paths.length(path) == path.size() - 1, "length should be steps")


func test_paths_are_deterministic_and_cache_safe() -> void:
	var paths := shared()
	var other := fresh_paths()
	var rng := make_rng(406)
	var same := true
	for i in 50:
		var a := random_building(rng).entrance
		var b := random_building(rng).entrance
		var first := paths.walk(a, b)
		first.clear()  # callers may change what they get back without hurting the cache
		if paths.walk(a, b) != other.walk(a, b):
			same = false
	rng.free()
	check(same, "two Paths built from the same map give different routes")


func test_thousand_walk_queries_timing() -> void:
	shared()
	var start := Time.get_ticks_msec()
	var paths := fresh_paths()
	var built := Time.get_ticks_msec()
	var rng := make_rng(407)
	var found := 0
	var steps := 0
	for i in TIMED_QUERIES:
		var path := paths.walk(random_building(rng).entrance, random_building(rng).entrance)
		if not path.is_empty():
			found += 1
			steps += paths.length(path)
	var done := Time.get_ticks_msec()
	rng.free()
	check(found == TIMED_QUERIES, "only %d of %d walk queries found a path" % [found, TIMED_QUERIES])
	print("        build: %d ms; %d walk queries: %d ms (target < 2000), mean %.1f steps" % [
		built - start, TIMED_QUERIES, done - built, float(steps) / maxi(found, 1)])
