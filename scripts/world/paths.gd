class_name Paths
extends RefCounted
## Walk and drive routes on two 4-direction AStarGrid2D grids (spec 04).
## Paths include both end tiles. An empty path means "no route".

const T := CityMap.TileType
const NO_TILE := Vector2i(-1, -1)
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var _map: CityMap
var _walk := AStarGrid2D.new()
var _drive := AStarGrid2D.new()
var _nearest_road: Dictionary = {}  # Vector2i -> Vector2i
var _walk_cache := _PathCache.new()
var _drive_cache := _PathCache.new()


## Reads `walk_road_cost` and `path_cache_size` from config.
static func build(map: CityMap, buildings: BuildingRegistry, config: ConfigStore) -> Paths:
	var paths := Paths.new()
	paths._map = map
	paths._walk_cache.setup(config.get_int("path_cache_size"))
	paths._drive_cache.setup(config.get_int("path_cache_size"))
	_setup_grid(paths._walk)
	_setup_grid(paths._drive)
	var road_cost := config.get_float("walk_road_cost")
	var entrances: Dictionary = {}
	for b in buildings.buildings:
		entrances[b.entrance] = true
	for y in CityMap.SIZE:
		for x in CityMap.SIZE:
			var p := Vector2i(x, y)
			var t := map.tile(x, y)
			match t:
				T.ROAD:
					paths._walk.set_point_weight_scale(p, road_cost)
				T.SIDEWALK:
					pass
				T.BUILDING:
					paths._walk.set_point_solid(p, not entrances.has(p))
				_:
					paths._walk.set_point_solid(p, true)
			paths._drive.set_point_solid(p, t != T.ROAD)
	for b in buildings.buildings:
		paths.nearest_road(b.entrance)
	return paths


static func _setup_grid(grid: AStarGrid2D) -> void:
	grid.region = Rect2i(0, 0, CityMap.SIZE, CityMap.SIZE)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.jumping_enabled = false
	grid.update()


func walk(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return _route(_walk, _walk_cache, from, to)


## Both ends must be ROAD tiles (use nearest_road).
func drive(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return _route(_drive, _drive_cache, from, to)


## Closest ROAD tile by breadth-first search over walkable tiles, or NO_TILE.
## Cached; every building entrance is precomputed in build().
func nearest_road(tile: Vector2i) -> Vector2i:
	if _nearest_road.has(tile):
		return _nearest_road[tile]
	var found := _bfs_road(tile)
	_nearest_road[tile] = found
	return found


## Number of steps (tiles moved) along a path.
func length(path: Array[Vector2i]) -> int:
	return maxi(path.size() - 1, 0)


func _route(grid: AStarGrid2D, cache: _PathCache, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to):
		return empty
	if grid.is_point_solid(from) or grid.is_point_solid(to):
		return empty
	var key := _key(from, to)
	if cache.has(key):
		return cache.fetch(key).duplicate()
	var path := grid.get_id_path(from, to)
	cache.store(key, path)
	return path.duplicate()


static func _key(from: Vector2i, to: Vector2i) -> int:
	return ((from.y * CityMap.SIZE + from.x) << 16) | (to.y * CityMap.SIZE + to.x)


func _bfs_road(start: Vector2i) -> Vector2i:
	if not _map.in_bounds(start.x, start.y):
		return NO_TILE
	if _map.tile(start.x, start.y) == T.ROAD:
		return start
	var seen := PackedByteArray()
	seen.resize(CityMap.SIZE * CityMap.SIZE)
	seen[start.y * CityMap.SIZE + start.x] = 1
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d in NEIGHBOURS:
			var q := p + d
			if not _map.in_bounds(q.x, q.y) or seen[q.y * CityMap.SIZE + q.x] == 1:
				continue
			seen[q.y * CityMap.SIZE + q.x] = 1
			if _walk.is_point_solid(q):
				continue
			if _map.tile(q.x, q.y) == T.ROAD:
				return q
			queue.append(q)
	return NO_TILE


## Fixed-size store of the most recent paths; the oldest entry is dropped first.
class _PathCache:
	var _paths: Dictionary = {}  # int key -> Array[Vector2i]
	var _ring := PackedInt64Array()
	var _next := 0

	func setup(size: int) -> void:
		_ring.resize(maxi(size, 0))
		_ring.fill(-1)

	func has(key: int) -> bool:
		return _paths.has(key)

	func fetch(key: int) -> Array[Vector2i]:
		return _paths[key]

	func store(key: int, path: Array[Vector2i]) -> void:
		if _ring.is_empty():
			return
		var old := _ring[_next]
		if old != -1:
			_paths.erase(old)
		_ring[_next] = key
		_paths[key] = path
		_next = (_next + 1) % _ring.size()
