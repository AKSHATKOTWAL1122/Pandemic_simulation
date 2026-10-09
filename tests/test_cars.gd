extends BaseTest


static func _sim() -> Simulation:
	return Simulation.standalone(ConfigStore.new())


static func _cleanup(sim: Simulation) -> void:
	var config := sim.config
	sim.free_standalone()
	config.free()


## A building whose walk path from `from` is longer than min_tiles (first found, id order).
static func _far_building(sim: Simulation, from: Building, min_tiles: int) -> Building:
	for b in sim.buildings.buildings:
		var path := sim.paths.walk(from.entrance, b.entrance)
		if sim.paths.length(path) > min_tiles:
			return b
	return null


static func _run_until_arrived(sim: Simulation, npc: NPC, max_ticks: int) -> bool:
	for i in max_ticks:
		if npc.activity == NPC.Activity.AT_BUILDING:
			return true
		sim.step()
	return npc.activity == NPC.Activity.AT_BUILDING


func test_npc_with_car_drives_a_long_trip_and_parks() -> void:
	var sim := _sim()
	var npc: NPC = null
	for n in sim.population.npcs:
		if sim.fleet.of_household(n.household_id) != null:
			npc = n
			break
	var home := sim.buildings.by_id(npc.home_id)
	var dest := _far_building(sim, home, 100)
	# Saturday noon, with a long stay, so the NPC doesn't leave again on arrival.
	sim.clock.tick = 5 * 1440 + 12 * 60
	sim.behaviour.start_trip(npc, dest.id, -1, 300, sim.clock.tick)
	check(npc.activity == NPC.Activity.DRIVING, "NPC with a car walked a %d+ tile trip" % 100)
	check(npc.in_car, "driver isn't marked in_car")
	var car := sim.fleet.of_household(npc.household_id)
	check(car.driver == npc.id, "car has no driver")
	check(_run_until_arrived(sim, npc, 60), "driver didn't arrive within 60 ticks")
	check(car.tile == sim.paths.nearest_road(dest.entrance), "car parked at %s, expected %s" % [car.tile, sim.paths.nearest_road(dest.entrance)])
	check(car.driver == -1 and not npc.in_car, "car still has a driver after arrival")
	_cleanup(sim)


func test_npc_without_car_walks() -> void:
	var sim := _sim()
	var npc: NPC = null
	for n in sim.population.npcs:
		if sim.fleet.of_household(n.household_id) == null:
			npc = n
			break
	var dest := _far_building(sim, sim.buildings.by_id(npc.home_id), 100)
	sim.behaviour.start_trip(npc, dest.id, -1, 0, 0)
	check(npc.activity == NPC.Activity.WALKING, "NPC without a car didn't walk")
	_cleanup(sim)


func test_short_trip_walks_even_with_a_car() -> void:
	var sim := _sim()
	var npc: NPC = null
	for n in sim.population.npcs:
		if sim.fleet.of_household(n.household_id) != null:
			npc = n
			break
	var home := sim.buildings.by_id(npc.home_id)
	var near: Building = null
	for b in sim.buildings.buildings:
		var length := sim.paths.length(sim.paths.walk(home.entrance, b.entrance))
		if b.id != home.id and length > 0 and length <= 30:
			near = b
			break
	sim.behaviour.start_trip(npc, near.id, -1, 0, 0)
	check(npc.activity == NPC.Activity.WALKING, "a <= 30-tile trip was driven")
	_cleanup(sim)


func test_family_member_walks_when_car_is_away() -> void:
	var sim := _sim()
	var household: Household = null
	for h in sim.population.households:
		if h.has_car and h.members.size() >= 2:
			household = h
			break
	var a: NPC = sim.population.npcs[household.members[0]]
	var b: NPC = sim.population.npcs[household.members[1]]
	var dest := _far_building(sim, sim.buildings.by_id(household.home_id), 100)
	sim.behaviour.start_trip(a, dest.id, -1, 0, 0)
	check(a.activity == NPC.Activity.DRIVING, "first member didn't drive")
	sim.behaviour.start_trip(b, dest.id, -1, 0, 0)
	check(b.activity == NPC.Activity.WALKING, "second member drove while the car was away")
	_cleanup(sim)


func test_rush_hour_traffic_on_bridges() -> void:
	var sim := _sim()
	var map := CityMap.load_default()
	var on_bridge := 0
	var max_driving := 0
	for tick in 10 * 60:
		sim.step()
		var driving := 0
		for npc in sim.population.npcs:
			if npc.activity != NPC.Activity.DRIVING:
				continue
			driving += 1
			for r in map.bridges:
				if Rect2(r).has_point(npc.pos):
					on_bridge += 1
		max_driving = maxi(max_driving, driving)
	print("        cars on bridges 00:00-10:00: %d car-ticks; max cars driving at once %d" % [on_bridge, max_driving])
	check(on_bridge > 0, "no car crossed a bridge during the morning rush")
	_cleanup(sim)
