class_name Population
extends RefCounted
## Every NPC and household (spec 05). Plain data in arrays indexed by id.

## Random picks tried before falling back to scanning every candidate.
const FRIEND_PICK_TRIES := 20

var npcs: Array[NPC] = []
var households: Array[Household] = []


## Builds the population. Every random draw goes through rng, in the order spec 05 lists.
static func generate(rng: SeededRng, buildings: BuildingRegistry, config: ConfigStore) -> Population:
	var pop := Population.new()
	pop._make_households(rng, config.get_int("population"), config.get_value("household_size_weights"))
	pop._assign_homes(rng, buildings)
	pop._assign_occupations(rng, config.get_value("occupation_shares"))
	pop._assign_jobs(rng, buildings)
	pop._assign_schools(buildings)
	pop._make_friends(rng, config.get_int("friends_min"), config.get_int("friends_max"), config.get_float("friends_same_place_share"))
	pop._assign_cars(rng, config.get_float("car_ownership_share"))
	pop._place_at_home(rng, buildings)
	return pop


## A uniformly random point inside a building rect (tiles, float).
static func random_point_in(rng: SeededRng, rect: Rect2i) -> Vector2:
	var end := Vector2(rect.end) - Vector2(0.001, 0.001)
	var p := Vector2(rect.position) + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
	return p.min(end)


func count() -> int:
	return npcs.size()


func households_with_car() -> Array[int]:
	var result: Array[int] = []
	for h in households:
		if h.has_car:
			result.append(h.id)
	return result


## Deterministic text dump of every household and NPC.
func serialize() -> String:
	var lines := PackedStringArray()
	for h in households:
		lines.append(h.serialize())
	for npc in npcs:
		lines.append(npc.serialize())
	return "\n".join(lines)


## Step 1: household sizes 1..n by weight until the population is reached; the last one is trimmed.
func _make_households(rng: SeededRng, population: int, size_weights: Array) -> void:
	var total := 0
	while total < population:
		var size := mini(rng.weighted_pick(size_weights) + 1, population - total)
		var h := Household.new()
		h.id = households.size()
		for i in size:
			var npc := NPC.new()
			npc.id = npcs.size()
			npc.household_id = h.id
			npcs.append(npc)
			h.members.append(npc.id)
		households.append(h)
		total += size


## Step 2: each household moves into a random home with enough free capacity.
func _assign_homes(rng: SeededRng, buildings: BuildingRegistry) -> void:
	var homes := buildings.with_purpose("home")
	var free := PackedInt32Array()
	free.resize(buildings.count())
	for b in homes:
		free[b.id] = b.home_capacity
	for h in households:
		var options: Array[int] = []
		for b in homes:
			if free[b.id] >= h.members.size():
				options.append(b.id)
		if options.is_empty():
			push_error("Population: no home has room for household %d" % h.id)
			assert(false, "Population: not enough home capacity")
			return
		var home_id: int = rng.pick(options)
		free[home_id] -= h.members.size()
		h.home_id = home_id
		for m in h.members:
			npcs[m].home_id = home_id


## Step 3: occupation by share, drawn per NPC in id order (STUDENT, WORKER, NONE).
func _assign_occupations(rng: SeededRng, shares: Dictionary) -> void:
	var weights: Array = []
	for occupation_name: String in NPC.Occupation.keys():
		weights.append(float(shares[occupation_name]))
	for npc in npcs:
		npc.occupation = rng.weighted_pick(weights)


## Step 4: each worker gets a random building that still has a free job slot.
func _assign_jobs(rng: SeededRng, buildings: BuildingRegistry) -> void:
	var open: Array[int] = []
	var free := PackedInt32Array()
	free.resize(buildings.count())
	for b in buildings.buildings:
		if b.jobs > 0:
			open.append(b.id)
			free[b.id] = b.jobs
	for npc in npcs:
		if npc.occupation != NPC.Occupation.WORKER:
			continue
		if open.is_empty():
			push_error("Population: no free job for %s" % npc.label())
			assert(false, "Population: not enough jobs")
			return
		var i := rng.randi_range(0, open.size() - 1)
		var building_id := open[i]
		npc.work_id = building_id
		free[building_id] -= 1
		if free[building_id] == 0:
			open.remove_at(i)


## Step 5: each student goes to the school nearest their home (ties: lowest id).
func _assign_schools(buildings: BuildingRegistry) -> void:
	var schools := buildings.with_purpose("school")
	for npc in npcs:
		if npc.occupation != NPC.Occupation.STUDENT:
			continue
		var home := buildings.by_id(npc.home_id).center()
		var best := -1
		var best_d := INF
		for s in schools:
			var d := home.distance_squared_to(s.center())
			if d < best_d:
				best_d = d
				best = s.id
		npc.school_id = best


## Step 6: mutual friendships. Each NPC first draws a target in [lo, hi]; then, in id order,
## adds friends until it reaches it — from its workplace/school with probability same_share,
## otherwise from anyone. Nobody goes above hi.
func _make_friends(rng: SeededRng, lo: int, hi: int, same_share: float) -> void:
	var targets := PackedInt32Array()
	for npc in npcs:
		targets.append(rng.randi_range(lo, hi))
	var members_by_place: Dictionary = {}
	for npc in npcs:
		var place := npc.place_id()
		if place >= 0:
			if not members_by_place.has(place):
				members_by_place[place] = [] as Array[int]
			(members_by_place[place] as Array[int]).append(npc.id)
	var everyone: Array[int] = []
	for npc in npcs:
		everyone.append(npc.id)
	for npc in npcs:
		while npc.friends.size() < targets[npc.id]:
			var other := -1
			var place := npc.place_id()
			if place >= 0 and rng.chance(same_share):
				other = _pick_friend(rng, npc, members_by_place[place], hi)
			if other < 0:
				other = _pick_friend(rng, npc, everyone, hi)
			if other < 0:
				break
			npc.friends.append(other)
			npcs[other].friends.append(npc.id)
	for npc in npcs:
		npc.friends.sort()


## A random NPC from pool who can still become npc's friend, or -1.
func _pick_friend(rng: SeededRng, npc: NPC, pool: Array[int], hi: int) -> int:
	for attempt in FRIEND_PICK_TRIES:
		var candidate: int = pool[rng.randi_range(0, pool.size() - 1)]
		if _can_befriend(npc, candidate, hi):
			return candidate
	var options: Array[int] = []
	for candidate in pool:
		if _can_befriend(npc, candidate, hi):
			options.append(candidate)
	if options.is_empty():
		return -1
	return rng.pick(options)


func _can_befriend(npc: NPC, other: int, hi: int) -> bool:
	return other != npc.id and not npc.friends.has(other) and npcs[other].friends.size() < hi


## Step 7: which households own a car.
func _assign_cars(rng: SeededRng, share: float) -> void:
	for h in households:
		h.has_car = rng.chance(share)


## Step 8: everyone starts at a random point inside their home, Monday 00:00.
func _place_at_home(rng: SeededRng, buildings: BuildingRegistry) -> void:
	for npc in npcs:
		npc.pos = random_point_in(rng, buildings.by_id(npc.home_id).rect)
