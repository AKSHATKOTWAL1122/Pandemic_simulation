extends BaseTest

static var _buildings: BuildingRegistry
static var _pop: Population
static var _population_size: int


## Generates the default population once for the whole file.
static func _shared() -> Population:
	if _pop == null:
		_buildings = BuildingRegistry.load_default()
		var config := ConfigStore.new()
		_population_size = config.get_int("population")
		_pop = _generate(config.get_int("seed"), config)
		config.free()
	return _pop


static func _generate(seed_value: int, config: ConfigStore) -> Population:
	var rng := SeededRng.new()
	rng.reseed(seed_value)
	var pop := Population.generate(rng, BuildingRegistry.load_default(), config)
	rng.free()
	return pop


func test_count_and_households() -> void:
	var pop := _shared()
	check(pop.count() == _population_size, "count %d != population %d" % [pop.count(), _population_size])
	var members := 0
	var bad_size := 0
	for h in pop.households:
		members += h.members.size()
		if h.members.size() < 1 or h.members.size() > 5:
			bad_size += 1
		for m in h.members:
			if pop.npcs[m].household_id != h.id or pop.npcs[m].home_id != h.home_id:
				check(false, "%s doesn't match household %d" % [pop.npcs[m].label(), h.id])
	check(members == _population_size, "households hold %d people" % members)
	check(bad_size == 0, "%d households outside size 1-5" % bad_size)
	for i in pop.count():
		check(pop.npcs[i].id == i, "npc at index %d has id %d" % [i, pop.npcs[i].id])
	check(pop.npcs[7].label() == "npc_007", "label is %s" % pop.npcs[7].label())


func test_no_home_over_capacity() -> void:
	var pop := _shared()
	var used: Dictionary = {}
	for npc in pop.npcs:
		check(_buildings.by_id(npc.home_id).has_purpose("home"), "%s lives in a non-home" % npc.label())
		used[npc.home_id] = int(used.get(npc.home_id, 0)) + 1
	var over: Array[int] = []
	for id: int in used:
		if used[id] > _buildings.by_id(id).home_capacity:
			over.append(id)
	check(over.is_empty(), "homes over capacity: %s" % [over])


func test_no_job_over_slots() -> void:
	var pop := _shared()
	var used: Dictionary = {}
	for npc in pop.npcs:
		if npc.occupation == NPC.Occupation.WORKER:
			check(npc.work_id >= 0, "worker %s has no job" % npc.label())
			used[npc.work_id] = int(used.get(npc.work_id, 0)) + 1
		else:
			check(npc.work_id == -1, "non-worker %s has a job" % npc.label())
	var over: Array[int] = []
	for id: int in used:
		if used[id] > _buildings.by_id(id).jobs:
			over.append(id)
	check(over.is_empty(), "buildings over job slots: %s" % [over])


func test_students_go_to_nearest_school() -> void:
	var pop := _shared()
	var schools := _buildings.with_purpose("school")
	for npc in pop.npcs:
		if npc.occupation != NPC.Occupation.STUDENT:
			check(npc.school_id == -1, "non-student %s has a school" % npc.label())
			continue
		var home := _buildings.by_id(npc.home_id).center()
		var mine := home.distance_to(_buildings.by_id(npc.school_id).center())
		for s in schools:
			if home.distance_to(s.center()) < mine:
				check(false, "%s isn't at the nearest school" % npc.label())


func test_occupation_and_car_shares() -> void:
	var pop := _shared()
	var counts := [0, 0, 0]
	for npc in pop.npcs:
		counts[npc.occupation] += 1
	var n := float(pop.count())
	check(absf(counts[NPC.Occupation.STUDENT] / n - 0.15) < 0.05, "student share %.2f" % (counts[NPC.Occupation.STUDENT] / n))
	check(absf(counts[NPC.Occupation.WORKER] / n - 0.65) < 0.05, "worker share %.2f" % (counts[NPC.Occupation.WORKER] / n))
	check(absf(counts[NPC.Occupation.NONE] / n - 0.20) < 0.05, "none share %.2f" % (counts[NPC.Occupation.NONE] / n))
	var car_share := pop.households_with_car().size() / float(pop.households.size())
	check(absf(car_share - 0.6) < 0.08, "car share %.2f" % car_share)


func test_friendships_mutual() -> void:
	var pop := _shared()
	var same_place := 0
	var links := 0
	for npc in pop.npcs:
		check(npc.friends.size() >= 3 and npc.friends.size() <= 8, "%s has %d friends" % [npc.label(), npc.friends.size()])
		var seen: Dictionary = {}
		for f in npc.friends:
			check(f != npc.id, "%s is its own friend" % npc.label())
			check(not seen.has(f), "%s lists friend %d twice" % [npc.label(), f])
			seen[f] = true
			check(pop.npcs[f].friends.has(npc.id), "%s -> %d isn't mutual" % [npc.label(), f])
			if npc.place_id() >= 0:
				links += 1
				if pop.npcs[f].place_id() == npc.place_id():
					same_place += 1
	# Spec 05: each pick tries the NPC's own place with probability 0.7 and falls back to anyone
	# when nobody there can take another friend. Most workplaces only have 2-3 workers, so the
	# real share is lower; at big places (schools, malls) the 70 % should show.
	var big_links := 0
	var big_same := 0
	var place_size: Dictionary = {}
	for npc in pop.npcs:
		if npc.place_id() >= 0:
			place_size[npc.place_id()] = int(place_size.get(npc.place_id(), 0)) + 1
	for npc in pop.npcs:
		if npc.place_id() < 0 or place_size[npc.place_id()] < 30:
			continue
		for f in npc.friends:
			big_links += 1
			if pop.npcs[f].place_id() == npc.place_id():
				big_same += 1
	print("        same-place friendships: %d / %d overall, %d / %d at places with >= 30 people" % [same_place, links, big_same, big_links])
	check(big_links > 0 and big_same > big_links * 0.5, "only %d of %d friendships at big places share the place" % [big_same, big_links])


func test_same_seed_identical_population() -> void:
	var config := ConfigStore.new()
	var a := _generate(99, config).serialize()
	var b := _generate(99, config).serialize()
	var c := _generate(100, config).serialize()
	config.free()
	check(a == b, "same seed gave different populations")
	check(a != c, "different seeds gave the same population")


## Visual check replaced: spec 08 draws NPCs, so here we check positions directly.
func test_everyone_starts_inside_home() -> void:
	var pop := _shared()
	var outside: Array[String] = []
	for npc in pop.npcs:
		var rect := Rect2(_buildings.by_id(npc.home_id).rect)
		var tile := Vector2i(npc.pos.floor())
		if not rect.has_point(npc.pos) or _buildings.at_tile(tile.x, tile.y) != npc.home_id:
			outside.append(npc.label())
	check(outside.is_empty(), "outside their home: %s" % [outside.slice(0, 10)])
