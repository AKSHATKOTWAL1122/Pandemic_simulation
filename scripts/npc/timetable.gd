class_name Timetable
extends RefCounted
## Fixed daily blocks that say where an NPC must be (spec 06). Time outside a block is FREE.
## Pure functions of (npc, tick): no state, no randomness after the jitter is drawn.

enum Kind { SLEEP, WORK, SCHOOL, FREE }

const SECONDS_PER_DAY := 86400
## Monday..Friday are weekdays 0..4 (a run starts Monday, day 0).
const WEEKDAYS_PER_WEEK := 5
## Kinds that are real blocks; NPC.jitter_start / jitter_end are indexed by these.
const BLOCK_KINDS: Array[int] = [Kind.SLEEP, Kind.WORK, Kind.SCHOOL]

var tick_seconds: int
var _buildings: BuildingRegistry
## [start, end] seconds after midnight per block kind; end <= start means it ends the next day.
var _start_s := PackedInt32Array()
var _end_s := PackedInt32Array()


func _init(config: ConfigStore, buildings: BuildingRegistry) -> void:
	tick_seconds = config.get_int("tick_seconds")
	_buildings = buildings
	for key in ["sleep_hours", "work_hours", "school_hours"]:
		var hours: Array = config.get_value(key)
		_start_s.append(roundi(float(hours[0]) * 3600.0))
		_end_s.append(roundi(float(hours[1]) * 3600.0))


static func kind_name(kind: int) -> String:
	return Kind.keys()[kind]


## Draws the NPC's fixed start/end offsets (minutes, in [-jitter_minutes, +jitter_minutes])
## for every block kind, in the order SLEEP start, SLEEP end, WORK start, ... (spec 05 step 9).
static func draw_jitter(npc: NPC, rng: SeededRng, jitter_minutes: int) -> void:
	npc.jitter_start = PackedInt32Array()
	npc.jitter_end = PackedInt32Array()
	for kind in BLOCK_KINDS:
		npc.jitter_start.append(rng.randi_range(-jitter_minutes, jitter_minutes))
		npc.jitter_end.append(rng.randi_range(-jitter_minutes, jitter_minutes))


## Path length (tiles) ÷ speed (tiles per game minute), for departure_tick.
static func estimate_travel_minutes(path_tiles: float, tiles_per_minute: float) -> float:
	return path_tiles / tiles_per_minute


## The block the NPC is in at this tick:
## {kind: Kind, building_id, start_tick, end_tick} (end exclusive).
## FREE has building_id, start_tick and end_tick = -1. A block whose building is closed is FREE.
func current_block(npc: NPC, tick: int) -> Dictionary:
	var t := tick * tick_seconds
	var today := floori(float(t) / SECONDS_PER_DAY)
	for kind in BLOCK_KINDS:
		for day in [today - 1, today]:
			var block := _block_on(npc, kind, day)
			if block.is_empty():
				continue
			if block["start_s"] <= t and t < block["end_s"] and not _buildings.is_closed(block["building_id"]):
				return _result(block)
	return free_block()


## The next block (open building) that starts after this tick, within the coming week,
## in the same shape as current_block. FREE (all -1) if there is none.
func next_block(npc: NPC, tick: int) -> Dictionary:
	var t := tick * tick_seconds
	var today := floori(float(t) / SECONDS_PER_DAY)
	var best: Dictionary = {}
	for day in range(today, today + 8):
		for kind in BLOCK_KINDS:
			var block := _block_on(npc, kind, day)
			if block.is_empty() or _buildings.is_closed(block["building_id"]):
				continue
			var result := _result(block)
			if result["start_tick"] > tick and (best.is_empty() or result["start_tick"] < best["start_tick"]):
				best = result
		if not best.is_empty():
			return best
	return free_block()


## Tick at which the NPC must leave to reach the block on time: block start minus travel time.
func departure_tick(block: Dictionary, travel_minutes: float) -> int:
	return int(block["start_tick"]) - ceili(travel_minutes * 60.0 / tick_seconds)


func free_block() -> Dictionary:
	return {"kind": Kind.FREE, "building_id": -1, "start_tick": -1, "end_tick": -1}


## The NPC's block of this kind starting on the given day (with jitter), or {} if it has none.
func _block_on(npc: NPC, kind: int, day: int) -> Dictionary:
	var building_id := npc.home_id
	if kind == Kind.WORK:
		building_id = npc.work_id
	elif kind == Kind.SCHOOL:
		building_id = npc.school_id
	if building_id < 0:
		return {}
	if kind != Kind.SLEEP and posmod(day, 7) >= WEEKDAYS_PER_WEEK:
		return {}
	var start := day * SECONDS_PER_DAY + _start_s[kind] + npc.jitter_start[kind] * 60
	var end := day * SECONDS_PER_DAY + _end_s[kind] + npc.jitter_end[kind] * 60
	if _end_s[kind] <= _start_s[kind]:
		end += SECONDS_PER_DAY
	return {"kind": kind, "building_id": building_id, "start_s": start, "end_s": end}


func _result(block: Dictionary) -> Dictionary:
	return {
		"kind": block["kind"],
		"building_id": block["building_id"],
		"start_tick": ceili(float(block["start_s"]) / tick_seconds),
		"end_tick": ceili(float(block["end_s"]) / tick_seconds),
	}
