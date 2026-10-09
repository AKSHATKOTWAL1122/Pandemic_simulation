class_name NpcBehaviour
extends RefCounted
## Spec 08: each tick, NPCs follow their timetable and desires and move there.
## An NPC only decides at decision points (block start/end, stay end, time to leave);
## in between it walks its route or wanders inside its building.

const NEVER := 1 << 60

var _clock: GameClock
var _rng: SeededRng
var _buildings: BuildingRegistry
var _paths: Paths
var _population: Population
var _timetable: Timetable
var _desires: Desires
var _minutes_per_tick: float
var _walk_tiles_per_tick: float
var _walk_tiles_per_minute: float
var _wander_ticks: int
var _min_outing_ticks: int
var _decision_retry_ticks: int


func _init(config: ConfigStore, clock: GameClock, rng: SeededRng, buildings: BuildingRegistry, paths: Paths,
		population: Population, timetable: Timetable, desires: Desires) -> void:
	_clock = clock
	_rng = rng
	_buildings = buildings
	_paths = paths
	_population = population
	_timetable = timetable
	_desires = desires
	var tick_seconds := config.get_int("tick_seconds")
	_minutes_per_tick = tick_seconds / 60.0
	var walk_mps := config.get_float("walk_speed_mps")
	_walk_tiles_per_minute = walk_mps * 60.0 / config.get_float("tile_metres")
	_walk_tiles_per_tick = _walk_tiles_per_minute * _minutes_per_tick
	_wander_ticks = maxi(1, roundi(config.get_float("indoor_wander_minutes") / _minutes_per_tick))
	_min_outing_ticks = maxi(1, roundi(config.get_float("min_outing_minutes") / _minutes_per_tick))
	_decision_retry_ticks = maxi(1, roundi(60.0 / _minutes_per_tick))
	for npc in population.npcs:
		npc.activity = NPC.Activity.AT_BUILDING
		npc.building_id = npc.home_id
		npc.prev_pos = npc.pos
		npc.indoor_target = npc.pos
		npc.next_decision_tick = 0


## One tick for every NPC, in id order.
func step(tick: int) -> void:
	for npc in _population.npcs:
		npc.prev_pos = npc.pos
		_desires.grow(npc, _minutes_per_tick, npc.asleep)
		if npc.activity == NPC.Activity.WALKING:
			_advance(npc, _walk_tiles_per_tick, tick)
		elif npc.activity == NPC.Activity.AT_BUILDING and tick >= npc.next_decision_tick:
			_decide(npc, tick)
		if npc.activity == NPC.Activity.AT_BUILDING:
			_wander(npc, tick)


## Straight-line walking time between two buildings' entrances, using the real walk path.
func travel_minutes(from_id: int, to_id: int) -> float:
	if from_id == to_id:
		return 0.0
	var path := _paths.walk(_buildings.by_id(from_id).entrance, _buildings.by_id(to_id).entrance)
	return Timetable.estimate_travel_minutes(_paths.length(path), _walk_tiles_per_minute)


func _decide(npc: NPC, tick: int) -> void:
	if npc.stay_need >= 0 and tick >= npc.stay_until_tick:
		_desires.finish_stay(npc, npc.stay_need)
		npc.stay_need = -1

	var block := _timetable.current_block(npc, tick)
	npc.asleep = block["kind"] == Timetable.Kind.SLEEP and npc.building_id == block["building_id"]
	if block["kind"] != Timetable.Kind.FREE:
		if npc.building_id == block["building_id"]:
			npc.next_decision_tick = block["end_tick"]
		else:
			_start_trip(npc, block["building_id"], -1, 0, tick)
		return

	# Free time: leave for the next block in time, otherwise follow desires.
	var deadline := NEVER
	var next := _timetable.next_block(npc, tick)
	if next["kind"] != Timetable.Kind.FREE:
		if next["building_id"] == npc.building_id:
			deadline = next["start_tick"] - _min_outing_ticks
			if tick >= deadline:
				npc.next_decision_tick = next["start_tick"]
				return
		else:
			deadline = _timetable.departure_tick(next, travel_minutes(npc.building_id, next["building_id"]))
			if tick >= deadline:
				_start_trip(npc, next["building_id"], -1, 0, tick)
				return

	if tick < npc.stay_until_tick:
		npc.next_decision_tick = mini(npc.stay_until_tick, deadline)
		return
	var choice := _desires.choose_destination(npc, tick)
	if choice["building_id"] == npc.building_id:
		_begin_stay(npc, choice["need"], choice["stay_ticks"], tick)
		npc.next_decision_tick = mini(npc.stay_until_tick, deadline)
	else:
		_start_trip(npc, choice["building_id"], choice["need"], choice["stay_ticks"], tick)


func _begin_stay(npc: NPC, need: int, stay_ticks: int, tick: int) -> void:
	npc.stay_need = need
	npc.stay_until_tick = tick + stay_ticks


func _start_trip(npc: NPC, dest_id: int, need: int, stay_ticks: int, tick: int) -> void:
	var from := _buildings.by_id(npc.building_id)
	var to := _buildings.by_id(dest_id)
	var tiles := _paths.walk(from.entrance, to.entrance)
	if tiles.is_empty():
		push_warning("NpcBehaviour: no walk path from building %d to %d" % [from.id, to.id])
		npc.next_decision_tick = tick + _decision_retry_ticks
		return
	var route := PackedVector2Array([npc.pos])
	for t in tiles:
		route.append(Vector2(t) + Vector2(0.5, 0.5))
	route.append(Population.random_point_in(_rng, to.rect))
	npc.route = route
	npc.route_index = 1
	npc.activity = NPC.Activity.WALKING
	npc.building_id = -1
	npc.asleep = false
	npc.stay_need = -1  # leaving cuts any stay short; the need isn't satisfied
	npc.dest_id = dest_id
	npc.dest_need = need
	npc.dest_stay_ticks = stay_ticks


## Moves along the route by up to `budget` tiles; arrives (and decides) at the end.
func _advance(npc: NPC, budget: float, tick: int) -> void:
	while budget > 0.0 and npc.route_index < npc.route.size():
		var target := npc.route[npc.route_index]
		var dist := npc.pos.distance_to(target)
		if dist <= budget:
			npc.pos = target
			budget -= dist
			npc.route_index += 1
		else:
			npc.pos += (target - npc.pos) * (budget / dist)
			budget = 0.0
	if npc.route_index >= npc.route.size():
		_arrive(npc, tick)


func _arrive(npc: NPC, tick: int) -> void:
	npc.activity = NPC.Activity.AT_BUILDING
	npc.in_car = false
	npc.building_id = npc.dest_id
	npc.route = PackedVector2Array()
	npc.route_index = 0
	npc.indoor_target = npc.pos
	npc.next_wander_tick = tick + _wander_ticks
	_begin_stay(npc, npc.dest_need, npc.dest_stay_ticks, tick)
	npc.dest_id = -1
	_decide(npc, tick)


## Inside a building: every indoor_wander_minutes pick a new spot, and walk towards it.
func _wander(npc: NPC, tick: int) -> void:
	if npc.asleep:
		return
	if tick >= npc.next_wander_tick:
		npc.indoor_target = Population.random_point_in(_rng, _buildings.by_id(npc.building_id).rect)
		npc.next_wander_tick = tick + _wander_ticks
	var dist := npc.pos.distance_to(npc.indoor_target)
	if dist <= _walk_tiles_per_tick:
		npc.pos = npc.indoor_target
	else:
		npc.pos += (npc.indoor_target - npc.pos) * (_walk_tiles_per_tick / dist)
