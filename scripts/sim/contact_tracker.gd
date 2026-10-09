class_name ContactTracker
extends RefCounted
## Spec 10: finds NPC pairs within the infection radius each tick, whatever their health,
## and logs a contact event when a pair comes into range.
## A pair counts only if both are inside the same building or both are outside (walls).

const OUTSIDE := -1

## In-range pairs this tick, sorted by (a, b): a < b.
var pair_a := PackedInt32Array()
var pair_b := PackedInt32Array()
var pair_in_car := PackedByteArray()
## Contact events that started this tick: Array of {tick, a, b, x, y, building_id, in_car}.
var events: Array[Dictionary] = []

var _npcs: Array[NPC]
var _radius: float
var _radius_sq: float
var _cell: float
## Pair keys (a * n + b) that were in range on the previous tick.
var _prev: Dictionary = {}


func _init(config: ConfigStore, npcs: Array[NPC]) -> void:
	_npcs = npcs
	var virus: Dictionary = config.get_value("virus")
	_radius = float(virus["infection_radius_m"]) / config.get_float("tile_metres")
	_radius_sq = _radius * _radius
	_cell = maxf(_radius, 0.0001)


## Where an NPC is for contact purposes: a building id, or OUTSIDE.
static func zone_of(npc: NPC) -> int:
	return npc.building_id if npc.activity == NPC.Activity.AT_BUILDING else OUTSIDE


func step(tick: int) -> void:
	pair_a.clear()
	pair_b.clear()
	pair_in_car.clear()
	events.clear()
	var n := _npcs.size()

	# Bucket NPCs by grid cell (cell size = radius, so neighbours are within 1 cell).
	var grid: Dictionary = {}  # cell key -> Array of ids, in id order
	for npc in _npcs:
		var key := _cell_key(floori(npc.pos.x / _cell), floori(npc.pos.y / _cell))
		var bucket: Variant = grid.get(key)
		if bucket == null:
			grid[key] = [npc.id]
		else:
			(bucket as Array).append(npc.id)

	var now: Dictionary = {}
	for npc in _npcs:
		var zone := zone_of(npc)
		var cx := floori(npc.pos.x / _cell)
		var cy := floori(npc.pos.y / _cell)
		var others := PackedInt32Array()
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var key := _cell_key(cx + dx, cy + dy)
				if not grid.has(key):
					continue
				for j: int in grid[key]:
					if j <= npc.id:
						continue
					var other := _npcs[j]
					if zone_of(other) != zone:
						continue
					if npc.pos.distance_squared_to(other.pos) <= _radius_sq:
						others.append(j)
		others.sort()
		for j in others:
			var other := _npcs[j]
			var in_car := npc.in_car or other.in_car
			pair_a.append(npc.id)
			pair_b.append(j)
			pair_in_car.append(1 if in_car else 0)
			var pair_key := npc.id * n + j
			now[pair_key] = true
			if not _prev.has(pair_key):
				npc.contact_count += 1
				other.contact_count += 1
				var mid := (npc.pos + other.pos) / 2.0
				events.append({
					"tick": tick, "a": npc.id, "b": j, "x": mid.x, "y": mid.y,
					"building_id": zone, "in_car": in_car,
				})
	_prev = now


static func _cell_key(cx: int, cy: int) -> int:
	return (cx + 4096) * 65536 + (cy + 4096)

