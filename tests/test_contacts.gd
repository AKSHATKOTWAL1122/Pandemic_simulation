extends BaseTest

const METRE := 0.25  # tiles, at tile_metres = 4


static func _npc(id: int, pos: Vector2, building_id: int = -1, activity: int = NPC.Activity.WALKING) -> NPC:
	var npc := NPC.new()
	npc.id = id
	npc.pos = pos
	npc.building_id = building_id
	npc.activity = activity
	return npc


static func _tracker(npcs: Array[NPC]) -> ContactTracker:
	var config := ConfigStore.new()
	var tracker := ContactTracker.new(config, npcs)
	config.free()
	return tracker


func test_encounter_logs_one_event_until_they_separate() -> void:
	var a := _npc(0, Vector2(50.5, 50.5))
	var b := _npc(1, Vector2(50.5 + METRE, 50.5))
	var tracker := _tracker([a, b] as Array[NPC])
	tracker.step(0)
	check(tracker.events.size() == 1, "1 m apart: expected 1 event, got %d" % tracker.events.size())
	check(tracker.pair_a.size() == 1, "pair not reported to SEIR")
	tracker.step(1)
	check(tracker.events.size() == 0, "still close: expected no new event, got %d" % tracker.events.size())
	b.pos = Vector2(60, 50)
	tracker.step(2)
	check(tracker.events.size() == 0 and tracker.pair_a.is_empty(), "apart: expected no pair")
	b.pos = Vector2(50.5, 50.5 + METRE)
	tracker.step(3)
	check(tracker.events.size() == 1, "close again: expected a second event")
	check(a.contact_count == 2 and b.contact_count == 2, "contact_count is %d / %d, expected 2" % [a.contact_count, b.contact_count])
	var e: Dictionary = tracker.events[0]
	check(e["tick"] == 3 and e["a"] == 0 and e["b"] == 1 and e["building_id"] == -1, "event fields wrong: %s" % e)


func test_wall_between_inside_and_outside() -> void:
	var inside := _npc(0, Vector2(50.5, 50.5), 7, NPC.Activity.AT_BUILDING)
	var outside := _npc(1, Vector2(50.5 + METRE, 50.5))
	var tracker := _tracker([inside, outside] as Array[NPC])
	tracker.step(0)
	check(tracker.events.is_empty(), "inside vs outside 1 m apart made a contact")


func test_same_building_counts_other_building_does_not() -> void:
	var a := _npc(0, Vector2(50.5, 50.5), 7, NPC.Activity.AT_BUILDING)
	var b := _npc(1, Vector2(50.5 + METRE, 50.5), 7, NPC.Activity.AT_BUILDING)
	var c := _npc(2, Vector2(50.5, 50.5 + METRE), 8, NPC.Activity.AT_BUILDING)
	var tracker := _tracker([a, b, c] as Array[NPC])
	tracker.step(0)
	check(tracker.events.size() == 1, "expected only the same-building pair, got %d events" % tracker.events.size())
	if tracker.events.size() == 1:
		check(tracker.events[0]["building_id"] == 7, "event building should be 7")


func test_beyond_radius_no_contact_and_in_car_flag() -> void:
	var a := _npc(0, Vector2(50.5, 50.5))
	var b := _npc(1, Vector2(50.5 + 9 * METRE, 50.5))
	var c := _npc(2, Vector2(50.5, 50.5 + 1.5 * METRE), -1, NPC.Activity.DRIVING)
	c.in_car = true
	var tracker := _tracker([a, b, c] as Array[NPC])
	tracker.step(0)
	check(tracker.events.size() == 1, "expected 1 event (a-c), got %d" % tracker.events.size())
	if tracker.events.size() == 1:
		check(tracker.events[0]["b"] == 2 and tracker.events[0]["in_car"], "a-c contact should be in_car")


func test_pairs_sorted_and_deterministic() -> void:
	var npcs: Array[NPC] = []
	for i in 30:
		npcs.append(_npc(i, Vector2(100.0 + (i % 5) * 0.2, 100.0 + floori(i / 5.0) * 0.2)))
	var tracker := _tracker(npcs)
	tracker.step(0)
	var sorted := true
	for k in range(1, tracker.pair_a.size()):
		var prev := Vector2i(tracker.pair_a[k - 1], tracker.pair_b[k - 1])
		var cur := Vector2i(tracker.pair_a[k], tracker.pair_b[k])
		if prev.x > cur.x or (prev.x == cur.x and prev.y >= cur.y):
			sorted = false
	check(sorted, "pairs are not sorted by (a, b)")
	check(tracker.pair_a.size() > 0, "dense crowd produced no pairs")


func test_one_day_contact_distribution_and_speed() -> void:
	var config := ConfigStore.new()
	var sim := Simulation.standalone(config)
	var spent_us := 0
	var events := 0
	for tick in 1440:
		sim.behaviour.step(sim.clock.tick)
		var t0 := Time.get_ticks_usec()
		sim.contacts.step(sim.clock.tick)
		spent_us += Time.get_ticks_usec() - t0
		events += sim.contacts.events.size()
		sim.clock.advance()
	var counts: Array[int] = []
	for npc in sim.population.npcs:
		counts.append(npc.contact_count)
	counts.sort()
	var ms_per_tick := spent_us / 1000.0 / 1440.0
	print("        1 day: %d contact events; contact_count min %d, median %d, max %d; contact step %.2f ms/tick" % [
		events, counts[0], counts[counts.size() / 2], counts[-1], ms_per_tick])
	check(counts[-1] > 0, "nobody had a contact in a whole day")
	check(ms_per_tick < 5.0, "contact step takes %.2f ms per tick (target < 5)" % ms_per_tick)
	sim.free_standalone()
	config.free()
