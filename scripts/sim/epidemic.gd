class_name Epidemic
extends RefCounted
## Spec 11: SEIR. Transmission on in-range pairs from ContactTracker, then fixed-length timers.

const H := NPC.Health

## S, E, I, R totals after the last step (R includes immune_forever NPCs), and immune_forever.
var counts := PackedInt32Array([0, 0, 0, 0])
var immune_forever_count: int = 0
## Infections since the Simulation last handed them to its listeners:
## Array of {tick, infector, infected, x, y, building_id, in_car}.
## infector = -1 for patient zero / manual infections. Simulation clears it after each tick.
var events: Array[Dictionary] = []

var _npcs: Array[NPC]
var _rng: SeededRng
var _p_tick: float
var _p_tick_car: float
var _incubation_ticks: int
var _infection_ticks: int
var _immunity_ticks: int


func _init(config: ConfigStore, npcs: Array[NPC], rng: SeededRng) -> void:
	_npcs = npcs
	_rng = rng
	var virus: Dictionary = config.get_value("virus")
	var tick_seconds := config.get_float("tick_seconds")
	var p := float(virus["transmission_prob_per_min"])
	var car_p := p * float(virus["car_transmission_multiplier"])
	_p_tick = 1.0 - pow(1.0 - p, tick_seconds / 60.0)
	_p_tick_car = 1.0 - pow(1.0 - car_p, tick_seconds / 60.0)
	_incubation_ticks = _days_to_ticks(float(virus["incubation_days"]), tick_seconds)
	_infection_ticks = _days_to_ticks(float(virus["infection_days"]), tick_seconds)
	_immunity_ticks = _days_to_ticks(float(virus["immunity_days"]), tick_seconds)
	recount()


static func _days_to_ticks(days: float, tick_seconds: float) -> int:
	return maxi(1, roundi(days * 86400.0 / tick_seconds))


## Sets an NPC straight to Infected (patient zero, or the Infect button) and logs it.
func infect(npc: NPC, tick: int) -> void:
	if npc.health == H.I:
		return
	_set_health(npc, H.I, tick)
	npc.infected_by = -1
	if npc.first_infected_tick < 0:
		npc.first_infected_tick = tick
	events.append(_event(tick, -1, npc, npc.in_car))
	recount()


func step(tick: int, contacts: ContactTracker) -> void:
	# 1. Transmission, in pair order. Someone exposed this tick can't infect this tick (they're E).
	for k in contacts.pair_a.size():
		var a := _npcs[contacts.pair_a[k]]
		var b := _npcs[contacts.pair_b[k]]
		var source: NPC = null
		var target: NPC = null
		if a.health == H.I and b.health == H.S:
			source = a
			target = b
		elif b.health == H.I and a.health == H.S:
			source = b
			target = a
		else:
			continue
		var in_car := contacts.pair_in_car[k] == 1
		if _rng.chance(_p_tick_car if in_car else _p_tick):
			_set_health(target, H.E, tick)
			target.infected_by = source.id
			if target.first_infected_tick < 0:
				target.first_infected_tick = tick
			events.append(_event(tick, source.id, target, in_car))

	# 2. Timers (fixed lengths).
	for npc in _npcs:
		var age := tick - npc.health_since_tick
		match npc.health:
			H.E:
				if age >= _incubation_ticks:
					_set_health(npc, H.I, tick)
			H.I:
				if age >= _infection_ticks:
					_set_health(npc, H.R, tick)
			H.R:
				if not npc.immune_forever and age >= _immunity_ticks:
					_set_health(npc, H.S, tick)
	recount()


func recount() -> void:
	counts = PackedInt32Array([0, 0, 0, 0])
	immune_forever_count = 0
	for npc in _npcs:
		counts[npc.health] += 1
		if npc.immune_forever:
			immune_forever_count += 1


static func _set_health(npc: NPC, health: int, tick: int) -> void:
	npc.health = health
	npc.health_since_tick = tick


func _event(tick: int, infector: int, infected: NPC, in_car: bool) -> Dictionary:
	return {
		"tick": tick, "infector": infector, "infected": infected.id,
		"x": infected.pos.x, "y": infected.pos.y,
		"building_id": ContactTracker.zone_of(infected), "in_car": in_car,
	}
