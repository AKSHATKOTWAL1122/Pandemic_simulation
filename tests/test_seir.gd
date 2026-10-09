extends BaseTest

const H := NPC.Health
const TICKS_PER_DAY := 1440


## Two NPCs standing 1 m apart outside; npc 0 infected. Returns [config, rng, npcs, tracker, epidemic].
static func _pair(virus: Dictionary, in_car: bool = false) -> Array:
	var config := ConfigStore.new()
	config.set_value("virus", virus)
	var rng := SeededRng.new()
	rng.reseed(1)
	var npcs: Array[NPC] = []
	for i in 2:
		var npc := NPC.new()
		npc.id = i
		npc.activity = NPC.Activity.DRIVING if in_car else NPC.Activity.WALKING
		npc.in_car = in_car
		npc.pos = Vector2(50.5 + i * 0.25, 50.5)
		npcs.append(npc)
	var tracker := ContactTracker.new(config, npcs)
	var epidemic := Epidemic.new(config, npcs, rng)
	epidemic.infect(npcs[0], 0)
	return [config, rng, npcs, tracker, epidemic]


static func _free(parts: Array) -> void:
	(parts[0] as ConfigStore).free()
	(parts[1] as SeededRng).free()


static func _tick(parts: Array, tick: int) -> void:
	(parts[3] as ContactTracker).step(tick)
	(parts[4] as Epidemic).step(tick, parts[3])


func test_p1_exposes_in_one_tick() -> void:
	var parts := _pair({"transmission_prob_per_min": 1.0})
	_tick(parts, 0)
	var b: NPC = parts[2][1]
	check(b.health == H.E, "with p = 1 the neighbour is %s, expected E" % H.keys()[b.health])
	check(b.infected_by == 0, "infected_by should be 0")
	var events: Array = (parts[4] as Epidemic).events
	check(events.size() == 2 and events[1]["infector"] == 0 and events[0]["infector"] == -1,
		"expected a patient-zero event then an infection event, got %s" % [events])
	_free(parts)


func test_timers_e_to_i_to_r_to_s() -> void:
	var parts := _pair({"transmission_prob_per_min": 1.0})
	_tick(parts, 0)
	var b: NPC = parts[2][1]
	var epidemic: Epidemic = parts[4]
	# Move b far away so it can't be re-exposed, then run the clock.
	b.pos = Vector2(200, 200)
	var seen := {}
	for tick in range(1, 10 * TICKS_PER_DAY):
		_tick(parts, tick)
		if not seen.has(b.health):
			seen[b.health] = tick
	check(seen.get(H.I, -1) == TICKS_PER_DAY, "E -> I at tick %d, expected %d" % [seen.get(H.I, -1), TICKS_PER_DAY])
	check(seen.get(H.R, -1) == 4 * TICKS_PER_DAY, "I -> R at tick %d, expected %d" % [seen.get(H.R, -1), 4 * TICKS_PER_DAY])
	check(seen.get(H.S, -1) == 9 * TICKS_PER_DAY, "R -> S at tick %d, expected %d" % [seen.get(H.S, -1), 9 * TICKS_PER_DAY])
	check(epidemic.counts[H.S] + epidemic.counts[H.E] + epidemic.counts[H.I] + epidemic.counts[H.R] == 2, "counts don't add up")
	_free(parts)


func test_immune_forever_never_leaves_r() -> void:
	var parts := _pair({"transmission_prob_per_min": 1.0})
	var b: NPC = parts[2][1]
	b.health = H.R
	b.immune_forever = true
	for tick in 20 * TICKS_PER_DAY:
		_tick(parts, tick)
	check(b.health == H.R, "immune_forever NPC left R")
	check((parts[4] as Epidemic).immune_forever_count == 1, "immune_forever_count should be 1")
	_free(parts)


func test_p0_never_infects() -> void:
	var parts := _pair({"transmission_prob_per_min": 0.0})
	for tick in TICKS_PER_DAY:
		_tick(parts, tick)
	check((parts[2][1] as NPC).health == H.S, "p = 0 still infected someone")
	_free(parts)


func test_car_multiplier_zero_never_infects() -> void:
	var parts := _pair({"transmission_prob_per_min": 1.0, "car_transmission_multiplier": 0.0}, true)
	for tick in TICKS_PER_DAY:
		_tick(parts, tick)
	check((parts[2][1] as NPC).health == H.S, "in-car multiplier 0 still infected someone")
	_free(parts)


func test_exposed_do_not_transmit() -> void:
	var parts := _pair({"transmission_prob_per_min": 1.0})
	var a: NPC = parts[2][0]
	var b: NPC = parts[2][1]
	a.health = H.E
	a.health_since_tick = 0
	for tick in 10:
		_tick(parts, tick)
	check(b.health == H.S, "an Exposed NPC infected its neighbour")
	_free(parts)


func test_outbreak_spreads_in_the_city() -> void:
	var config := ConfigStore.new()
	var sim := Simulation.standalone(config)
	for id in [0, 100, 200, 300, 400]:
		sim.infect(id)
	var daily: Array[String] = []
	var infected_ever := [0]  # an Array, because lambdas capture locals by value
	sim.listeners.append(func(_t: int, _c: Array, inf: Array) -> void: infected_ever[0] += inf.size())
	for day in 10:
		for i in TICKS_PER_DAY:
			sim.step()
		var c := sim.epidemic.counts
		daily.append("d%d S%d E%d I%d R%d" % [day + 1, c[H.S], c[H.E], c[H.I], c[H.R]])
	print("        10 days, 5 patient zeros: " + ", ".join(daily))
	print("        infection events (incl. 5 patient zeros): %d" % infected_ever[0])
	check(infected_ever[0] > 5, "nobody caught the virus in 10 days")
	sim.free_standalone()
	config.free()
