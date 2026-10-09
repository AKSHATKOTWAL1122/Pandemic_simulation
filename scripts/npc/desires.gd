class_name Desires
extends RefCounted
## Free-time choices driven by needs (spec 07). Decides where an NPC goes and for how long;
## moving there is spec 08's job.

enum Need { HUNGER, FUN, SOCIAL, SHOPPING }

## Destination kinds; also the keys of stay_minutes.
const RESTAURANT := "restaurant"
const NIGHTCLUB := "nightclub"
const MALL := "mall"
const FRIEND_HOME := "friend_home"
const HOME := "home"
## Order of social_destination_weights.
const SOCIAL_PLACES: Array[String] = [FRIEND_HOME, RESTAURANT, NIGHTCLUB]
const NEED_MAX := 100.0
## Distances below one tile count as one tile, so 1 / distance stays finite.
const MIN_DISTANCE := 1.0

var tick_seconds: int
var _buildings: BuildingRegistry
var _npcs: Array[NPC]
var _rng: SeededRng
var _growth := PackedFloat64Array()
var _threshold: float
var _stay: Dictionary
var _candidate_count: int
var _hunger_restaurant_share: float
var _social_weights: Array = []
var _nightclub_from_s: int
var _nightclub_to_s: int


## npcs: the whole population (for friends' homes). rng: the shared seeded Rng.
func _init(config: ConfigStore, buildings: BuildingRegistry, npcs: Array[NPC], rng: SeededRng) -> void:
	tick_seconds = config.get_int("tick_seconds")
	_buildings = buildings
	_npcs = npcs
	_rng = rng
	var growth: Dictionary = config.get_value("need_growth_per_hour")
	for need in Need.size():
		_growth.append(float(growth[need_name(need)]))
	_threshold = config.get_float("need_threshold")
	_stay = config.get_value("stay_minutes")
	_candidate_count = config.get_int("candidate_count")
	_hunger_restaurant_share = config.get_float("hunger_restaurant_share")
	var social: Dictionary = config.get_value("social_destination_weights")
	for place in SOCIAL_PLACES:
		_social_weights.append(float(social[place]))
	var hours: Array = config.get_value("nightclub_hours")
	_nightclub_from_s = roundi(float(hours[0]) * 3600.0)
	_nightclub_to_s = roundi(float(hours[1]) * 3600.0)


## "hunger", "fun", ...; "none" for -1.
static func need_name(need: int) -> String:
	if need < 0:
		return "none"
	var key: String = Need.keys()[need]
	return key.to_lower()


## Starting needs, uniform in start_range [lo, hi] (spec 05 step 10).
static func init_needs(npc: NPC, rng: SeededRng, start_range: Array) -> void:
	for need in Need.size():
		npc.needs[need] = rng.randf_range(float(start_range[0]), float(start_range[1]))


## Needs grow for the given game minutes, unless the NPC is asleep. Capped at 100.
func grow(npc: NPC, minutes: float, asleep: bool) -> void:
	if asleep:
		return
	for need in Need.size():
		npc.needs[need] = minf(NEED_MAX, npc.needs[need] + _growth[need] * minutes / 60.0)


## Call at the end of a stay: the need that caused the visit drops to 0 (need -1: nothing).
func finish_stay(npc: NPC, need: int) -> void:
	if need >= 0:
		npc.needs[need] = 0.0


## Where a free NPC at npc.pos goes now:
## {building_id, need (Need or -1), place (RESTAURANT...HOME), stay_minutes, stay_ticks}.
## Tries needs >= threshold from highest to lowest; if none has an open candidate, goes home.
func choose_destination(npc: NPC, tick: int) -> Dictionary:
	for need in _needs_to_try(npc):
		var place := _place_for(need, tick)
		var building_id := -1
		match place:
			HOME:
				building_id = npc.home_id if not _buildings.is_closed(npc.home_id) else -1
			FRIEND_HOME:
				building_id = _friend_home(npc)
			_:
				building_id = _pick_nearby(place, npc.pos)
		if building_id >= 0:
			return _choice(building_id, need, place)
	return _choice(npc.home_id, -1, HOME)


## Needs at or above the threshold, highest first (ties: Need order).
func _needs_to_try(npc: NPC) -> Array[int]:
	var result: Array[int] = []
	for need in Need.size():
		if npc.needs[need] >= _threshold:
			result.append(need)
	result.sort_custom(func(a: int, b: int) -> bool:
		return npc.needs[a] > npc.needs[b] or (npc.needs[a] == npc.needs[b] and a < b))
	return result


func _place_for(need: int, tick: int) -> String:
	match need:
		Need.HUNGER:
			return RESTAURANT if _rng.chance(_hunger_restaurant_share) else HOME
		Need.FUN:
			return NIGHTCLUB if _is_nightclub_time(tick) else MALL
		Need.SOCIAL:
			return SOCIAL_PLACES[_rng.weighted_pick(_social_weights)]
		_:
			return MALL


func _is_nightclub_time(tick: int) -> bool:
	var s := posmod(tick * tick_seconds, Timetable.SECONDS_PER_DAY)
	if _nightclub_from_s <= _nightclub_to_s:
		return s >= _nightclub_from_s and s < _nightclub_to_s
	return s >= _nightclub_from_s or s < _nightclub_to_s


## A random friend's home (the friend needn't be there), or -1.
func _friend_home(npc: NPC) -> int:
	if npc.friends.is_empty():
		return -1
	var friend: int = _rng.pick(npc.friends)
	var home := _npcs[friend].home_id
	return -1 if _buildings.is_closed(home) else home


## One of the candidate_count nearest open buildings with this purpose (straight line from
## pos to the building centre), weighted by 1 / distance. -1 if none is open.
func _pick_nearby(purpose: String, pos: Vector2) -> int:
	var options: Array[Vector2] = []  # (distance, id)
	for b in _buildings.with_purpose(purpose):
		if not _buildings.is_closed(b.id):
			options.append(Vector2(maxf(MIN_DISTANCE, pos.distance_to(b.center())), b.id))
	if options.is_empty():
		return -1
	options.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	options = options.slice(0, _candidate_count)
	var weights: Array = []
	for o in options:
		weights.append(1.0 / o.x)
	return int(options[_rng.weighted_pick(weights)].y)


func _choice(building_id: int, need: int, place: String) -> Dictionary:
	var minutes := int(_stay[place])
	return {
		"building_id": building_id,
		"need": need,
		"place": place,
		"stay_minutes": minutes,
		"stay_ticks": ceili(minutes * 60.0 / tick_seconds),
	}
