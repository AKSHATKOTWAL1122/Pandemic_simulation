extends BaseTest

const TICKS_PER_DAY := 1440  # at tick_seconds = 60

static var _day_run: Dictionary = {}


## Runs one simulated day once and records what the tests need.
static func _run_day() -> Dictionary:
	if not _day_run.is_empty():
		return _day_run
	var config := ConfigStore.new()
	var sim := Simulation.standalone(config)
	var map := CityMap.load_default()
	var bad_state := 0
	var on_water := 0
	var at_work_10 := 0
	var workers := 0
	var home_03 := 0
	var walkers_max := 0
	var started := Time.get_ticks_msec()
	for tick in TICKS_PER_DAY:
		sim.step()
		var walkers := 0
		for npc in sim.population.npcs:
			if npc.activity == NPC.Activity.AT_BUILDING:
				var b := sim.buildings.by_id(npc.building_id) if npc.building_id >= 0 else null
				if b == null or not Rect2(b.rect).grow(0.001).has_point(npc.pos):
					bad_state += 1
			elif npc.activity == NPC.Activity.WALKING:
				walkers += 1
				if npc.route.is_empty():
					bad_state += 1
			else:
				bad_state += 1
			if map.tile(floori(npc.pos.x), floori(npc.pos.y)) == CityMap.TileType.WATER:
				on_water += 1
		walkers_max = maxi(walkers_max, walkers)
		if sim.clock.tick == 3 * 60:
			for npc in sim.population.npcs:
				if npc.building_id == npc.home_id:
					home_03 += 1
		if sim.clock.tick == 10 * 60:
			for npc in sim.population.npcs:
				if npc.occupation == NPC.Occupation.WORKER:
					workers += 1
					if npc.building_id == npc.work_id:
						at_work_10 += 1
	var elapsed := Time.get_ticks_msec() - started
	print("        1 day, %d NPCs: %d ms (%.2f ms/tick); max walkers at once %d" % [
		sim.population.count(), elapsed, float(elapsed) / TICKS_PER_DAY, walkers_max])
	_day_run = {
		"bad_state": bad_state, "on_water": on_water, "at_work_10": at_work_10, "workers": workers,
		"home_03": home_03, "population": sim.population.count(), "walkers_max": walkers_max,
	}
	sim.free_standalone()
	config.free()
	return _day_run


func test_every_npc_is_inside_a_building_or_walking() -> void:
	var r := _run_day()
	check(r["bad_state"] == 0, "%d NPC-ticks were neither inside their building nor on a route" % r["bad_state"])


func test_no_npc_ever_on_water() -> void:
	var r := _run_day()
	check(r["on_water"] == 0, "%d NPC-ticks were on a WATER tile" % r["on_water"])


func test_everyone_home_at_night_and_workers_at_work_by_10() -> void:
	var r := _run_day()
	check(r["home_03"] == r["population"], "only %d / %d at home at 03:00" % [r["home_03"], r["population"]])
	var share := float(r["at_work_10"]) / maxf(1.0, r["workers"])
	print("        workers at work at Mon 10:00: %d / %d" % [r["at_work_10"], r["workers"]])
	check(share >= 0.9, "only %.0f%% of workers at work at 10:00" % (share * 100.0))
	check(r["walkers_max"] > 50, "almost nobody walked (max %d at once)" % r["walkers_max"])


func test_same_seed_same_positions() -> void:
	var a_config := ConfigStore.new()
	var b_config := ConfigStore.new()
	var a := Simulation.standalone(a_config)
	var b := Simulation.standalone(b_config)
	for i in 600:
		a.step()
		b.step()
	var same := true
	for i in a.population.count():
		if a.population.npcs[i].pos != b.population.npcs[i].pos:
			same = false
			break
	check(same, "two runs with the same seed diverged within 600 ticks")
	a.free_standalone()
	b.free_standalone()
	a_config.free()
	b_config.free()
