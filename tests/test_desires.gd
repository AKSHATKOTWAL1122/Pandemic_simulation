extends BaseTest

const N := Desires.Need
const SAT := 5

static var _pop: Population


static func _population() -> Population:
	if _pop == null:
		var config := ConfigStore.new()
		var rng := SeededRng.new()
		rng.reseed(config.get_int("seed"))
		_pop = Population.generate(rng, BuildingRegistry.load_default(), config)
		rng.free()
		config.free()
	return _pop


var _config: ConfigStore
var _rng: SeededRng
var _reg: BuildingRegistry
var _desires: Desires


## Fresh registry (nothing closed), rng and Desires for one test. Call _done() at the end.
func _setup(seed_value: int = 1) -> void:
	_config = ConfigStore.new()
	_rng = SeededRng.new()
	_rng.reseed(seed_value)
	_reg = BuildingRegistry.load_default()
	_desires = Desires.new(_config, _reg, _population().npcs, _rng)


func _done() -> void:
	_config.free()
	_rng.free()


func _tick(day: int, hour: int, minute: int = 0) -> int:
	@warning_ignore("integer_division")
	return (day * 86400 + hour * 3600 + minute * 60) / _desires.tick_seconds


## A copy of population NPC i (home, friends, position) with the given needs.
func _npc(i: int, hunger: float, fun: float, social: float, shopping: float) -> NPC:
	var src := _population().npcs[i]
	var npc := NPC.new()
	npc.id = src.id
	npc.home_id = src.home_id
	npc.friends = src.friends.duplicate()
	npc.pos = src.pos
	npc.needs = PackedFloat64Array([hunger, fun, social, shopping])
	return npc


func test_hungry_goes_to_restaurant_or_home() -> void:
	_setup()
	var npc := _npc(0, 80, 10, 10, 10)
	var restaurant := 0
	var home := 0
	for i in 300:
		var c := _desires.choose_destination(npc, _tick(SAT, 12))
		check(c["need"] == N.HUNGER, "hungry NPC chose for need %s" % Desires.need_name(c["need"]))
		if c["place"] == Desires.RESTAURANT and _reg.by_id(c["building_id"]).has_purpose("restaurant"):
			restaurant += 1
			check(c["stay_minutes"] == 60, "restaurant stay isn't 60 min")
		elif c["place"] == Desires.HOME and c["building_id"] == npc.home_id:
			home += 1
		else:
			check(false, "hungry NPC went to %s (building %d)" % [c["place"], c["building_id"]])
	check(restaurant + home == 300, "not every choice was restaurant or home")
	check(absf(restaurant / 300.0 - 0.7) < 0.1, "restaurant share %.2f, expected ~0.7" % (restaurant / 300.0))
	_done()


func test_one_mall_closed_picks_the_other() -> void:
	_setup()
	var malls := _reg.with_purpose("mall")
	var npc := _npc(0, 10, 10, 10, 90)
	_reg.set_closed(malls[0].id, true)
	for i in 50:
		var c := _desires.choose_destination(npc, _tick(SAT, 12))
		check(c["building_id"] == malls[1].id and c["need"] == N.SHOPPING, "shopping didn't pick the open mall")
	_done()


func test_both_malls_closed_next_need_or_home() -> void:
	_setup()
	for m in _reg.with_purpose("mall"):
		_reg.set_closed(m.id, true)
	# Next need: social 60 → friend's home, restaurant or nightclub.
	var npc := _npc(0, 10, 10, 60, 90)
	for i in 50:
		var c := _desires.choose_destination(npc, _tick(SAT, 12))
		check(c["need"] == N.SOCIAL, "both malls closed: expected social, got %s" % Desires.need_name(c["need"]))
		check(not _reg.by_id(c["building_id"]).has_purpose("mall"), "went to a closed mall")
	# No other need ≥ 50: home.
	var lonely := _npc(0, 10, 10, 10, 90)
	var c := _desires.choose_destination(lonely, _tick(SAT, 12))
	check(c["place"] == Desires.HOME and c["building_id"] == lonely.home_id and c["need"] == -1, "both malls closed, nothing else: should go home")
	# Fun in the afternoon also wants a mall: falls through to home too.
	var bored := _npc(0, 10, 90, 10, 10)
	c = _desires.choose_destination(bored, _tick(SAT, 14))
	check(c["place"] == Desires.HOME, "fun with malls closed at 14:00 should go home")
	_done()


func test_fun_nightclub_at_night_mall_by_day() -> void:
	_setup()
	var npc := _npc(0, 10, 90, 10, 10)
	for hour in [19, 22, 0, 2]:
		var c := _desires.choose_destination(npc, _tick(SAT, hour))
		check(c["place"] == Desires.NIGHTCLUB and _reg.by_id(c["building_id"]).has_purpose("nightclub"), "fun at %02d:00 didn't pick a nightclub" % hour)
		check(c["stay_minutes"] == 120, "nightclub stay isn't 120")
	for hour in [3, 12, 18]:
		var c := _desires.choose_destination(npc, _tick(SAT, hour))
		check(c["place"] == Desires.MALL and _reg.by_id(c["building_id"]).has_purpose("mall"), "fun at %02d:00 didn't pick a mall" % hour)
		check(c["stay_minutes"] == 90, "mall stay isn't 90")
	_done()


func test_social_destinations() -> void:
	_setup()
	var npc := _npc(0, 10, 10, 90, 10)
	var friend_homes: Array[int] = []
	for f in npc.friends:
		friend_homes.append(_population().npcs[f].home_id)
	var counts: Dictionary = {}
	for i in 400:
		var c := _desires.choose_destination(npc, _tick(SAT, 20))
		counts[c["place"]] = int(counts.get(c["place"], 0)) + 1
		match c["place"]:
			Desires.FRIEND_HOME:
				check(friend_homes.has(c["building_id"]), "friend_home isn't a friend's home")
				check(c["stay_minutes"] == 120, "friend's home stay isn't 120")
			Desires.RESTAURANT:
				check(_reg.by_id(c["building_id"]).has_purpose("restaurant"), "social restaurant isn't a restaurant")
			Desires.NIGHTCLUB:
				check(_reg.by_id(c["building_id"]).has_purpose("nightclub"), "social nightclub isn't a nightclub")
			_:
				check(false, "social went to %s" % c["place"])
	check(absf(int(counts.get(Desires.FRIEND_HOME, 0)) / 400.0 - 0.5) < 0.1, "friend's home share off: %s" % [counts])
	_done()


func test_no_need_goes_home() -> void:
	_setup()
	var npc := _npc(0, 49, 10, 10, 10)
	var c := _desires.choose_destination(npc, _tick(SAT, 12))
	check(c["place"] == Desires.HOME and c["building_id"] == npc.home_id and c["need"] == -1, "no need >= 50 should go home")
	check(c["stay_minutes"] == 60 and c["stay_ticks"] == 60, "home stay isn't 60 min / 60 ticks")
	_done()


func test_highest_need_first() -> void:
	_setup()
	var npc := _npc(0, 60, 10, 10, 95)
	var c := _desires.choose_destination(npc, _tick(SAT, 12))
	check(c["need"] == N.SHOPPING and c["place"] == Desires.MALL, "shopping 95 should beat hunger 60")
	_done()


func test_five_nearest_weighted_by_distance() -> void:
	_setup()
	var npc := _npc(0, 90, 10, 10, 10)
	var by_distance: Array[Building] = _reg.with_purpose("restaurant")
	by_distance.sort_custom(func(a: Building, b: Building) -> bool:
		return npc.pos.distance_to(a.center()) < npc.pos.distance_to(b.center()))
	var nearest: Array[int] = []
	for b in by_distance.slice(0, 5):
		nearest.append(b.id)
	var counts: Dictionary = {}
	for i in 1000:
		var c := _desires.choose_destination(npc, _tick(SAT, 12))
		if c["place"] == Desires.RESTAURANT:
			counts[c["building_id"]] = int(counts.get(c["building_id"], 0)) + 1
			check(nearest.has(c["building_id"]), "restaurant %d isn't among the 5 nearest" % c["building_id"])
	check(int(counts.get(nearest[0], 0)) > int(counts.get(nearest[4], 0)), "nearest restaurant isn't picked more than the 5th: %s" % [counts])
	_done()


func test_growth_and_reset() -> void:
	_setup()
	var npc := _npc(0, 10, 10, 10, 10)
	_desires.grow(npc, 60.0, false)
	check(npc.needs == PackedFloat64Array([16, 14, 14, 12]), "one awake hour gave %s" % npc.needs)
	_desires.grow(npc, 600.0, true)
	check(npc.needs == PackedFloat64Array([16, 14, 14, 12]), "needs grew while asleep: %s" % npc.needs)
	_desires.grow(npc, 6000.0, false)
	check(npc.needs == PackedFloat64Array([100, 100, 100, 100]), "needs not capped at 100: %s" % npc.needs)
	_desires.finish_stay(npc, N.FUN)
	check(npc.needs[N.FUN] == 0.0 and npc.needs[N.HUNGER] == 100.0, "finish_stay didn't reset only fun")
	_desires.finish_stay(npc, -1)
	check(npc.needs[N.HUNGER] == 100.0, "finish_stay(-1) changed a need")
	_done()


func test_starting_needs_in_range() -> void:
	var bad := 0
	for npc in _population().npcs:
		for v in npc.needs:
			if v < 0.0 or v > 50.0:
				bad += 1
	check(bad == 0, "%d starting needs outside 0-50" % bad)


func test_same_seed_same_choices() -> void:
	var runs: Array[String] = []
	for r in 2:
		_setup(7)
		var line := ""
		for i in 50:
			var npc := _npc(i, 60 + i % 30, 55, 70, 50 + i % 40)
			var c := _desires.choose_destination(npc, _tick(SAT, 10 + i % 12))
			line += "%d/%d " % [c["building_id"], c["need"]]
		runs.append(line)
		_done()
	check(runs[0] == runs[1], "same seed gave different choices")


## Spec 07's 7-day check, without movement (spec 08): decisions every game hour, NPCs arrive
## instantly. Counts mall visits per mall per day, prints them, and checks every day has visitors.
func test_seven_day_mall_visits() -> void:
	_setup()
	var tt := Timetable.new(_config, _reg)
	var pop := _population()
	var n := pop.count()
	# Work on copies so the shared population stays untouched.
	var npcs: Array[NPC] = []
	for i in n:
		var copy := _npc(i, 0, 0, 0, 0)
		copy.needs = pop.npcs[i].needs.duplicate()
		copy.occupation = pop.npcs[i].occupation
		copy.work_id = pop.npcs[i].work_id
		copy.school_id = pop.npcs[i].school_id
		copy.jitter_start = pop.npcs[i].jitter_start
		copy.jitter_end = pop.npcs[i].jitter_end
		npcs.append(copy)
	var malls := _reg.with_purpose("mall")
	var stay_until := PackedInt32Array()
	stay_until.resize(n)
	var visit_need := PackedInt32Array()
	visit_need.resize(n)
	visit_need.fill(-1)
	var visiting := PackedInt32Array()
	visiting.resize(n)
	visiting.fill(-1)
	@warning_ignore("integer_division")
	var ticks_per_hour := 3600 / tt.tick_seconds
	var visits: Array[Dictionary] = []
	for day in 7:
		var per_mall: Dictionary = {}
		for m in malls:
			per_mall[m.id] = 0
		visits.append(per_mall)
	for hour in 7 * 24:
		var tick := hour * ticks_per_hour
		@warning_ignore("integer_division")
		var day := hour / 24
		for npc in npcs:
			var block := tt.current_block(npc, tick)
			if hour > 0:
				_desires.grow(npc, 60.0, block["kind"] == Timetable.Kind.SLEEP)
			if block["kind"] != Timetable.Kind.FREE:
				visiting[npc.id] = -1
				stay_until[npc.id] = 0
				npc.pos = _reg.by_id(block["building_id"]).center()
				continue
			if tick < stay_until[npc.id]:
				continue
			if visiting[npc.id] >= 0:
				_desires.finish_stay(npc, visit_need[npc.id])
			var c := _desires.choose_destination(npc, tick)
			visiting[npc.id] = c["building_id"]
			visit_need[npc.id] = c["need"]
			stay_until[npc.id] = tick + c["stay_ticks"]
			npc.pos = _reg.by_id(c["building_id"]).center()
			if c["place"] == Desires.MALL:
				visits[day][c["building_id"]] += 1
	print("        mall visits per day (mall ids %s):" % [visits[0].keys()])
	for day in 7:
		print("        day %d %s: %s" % [day, GameClock.WEEKDAYS[day], visits[day].values()])
		for id: int in visits[day]:
			check(visits[day][id] > 0, "mall %d had no visitors on day %d" % [id, day])
	_done()
