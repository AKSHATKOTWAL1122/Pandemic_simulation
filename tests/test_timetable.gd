extends BaseTest

const K := Timetable.Kind
const MON := 0
const TUE := 1
const WED := 2
const SAT := 5


## Tick at a given day / hour / minute of the run (day 0 = Monday).
func _tick(tt: Timetable, day: int, hour: int, minute: int = 0) -> int:
	@warning_ignore("integer_division")
	return (day * 86400 + hour * 3600 + minute * 60) / tt.tick_seconds


## A hand-made NPC with zero jitter, using real building ids.
func _npc(reg: BuildingRegistry, occupation: int) -> NPC:
	var npc := NPC.new()
	npc.id = 0
	npc.occupation = occupation
	npc.home_id = reg.with_purpose("home")[0].id
	if occupation == NPC.Occupation.WORKER:
		npc.work_id = reg.with_purpose("workplace")[0].id
	elif occupation == NPC.Occupation.STUDENT:
		npc.school_id = reg.with_purpose("school")[0].id
	return npc


func _timetable(reg: BuildingRegistry) -> Timetable:
	var config := ConfigStore.new()
	var tt := Timetable.new(config, reg)
	config.free()
	return tt


func _expect(tt: Timetable, npc: NPC, tick: int, kind: int, building_id: int, what: String) -> void:
	var block := tt.current_block(npc, tick)
	check(block["kind"] == kind, "%s: expected %s, got %s" % [what, Timetable.kind_name(kind), Timetable.kind_name(block["kind"])])
	check(block["building_id"] == building_id, "%s: expected building %d, got %d" % [what, building_id, block["building_id"]])


func test_worker_blocks() -> void:
	var reg := BuildingRegistry.load_default()
	var tt := _timetable(reg)
	var w := _npc(reg, NPC.Occupation.WORKER)
	_expect(tt, w, _tick(tt, MON, 10), K.WORK, w.work_id, "worker Mon 10:00")
	_expect(tt, w, _tick(tt, SAT, 10), K.FREE, -1, "worker Sat 10:00")
	_expect(tt, w, _tick(tt, TUE, 2), K.SLEEP, w.home_id, "worker Tue 02:00")
	_expect(tt, w, _tick(tt, MON, 0), K.SLEEP, w.home_id, "worker Mon 00:00")
	_expect(tt, w, _tick(tt, MON, 23, 30), K.SLEEP, w.home_id, "worker Mon 23:30")
	_expect(tt, w, _tick(tt, MON, 18), K.FREE, -1, "worker Mon 18:00")


func test_student_and_none_blocks() -> void:
	var reg := BuildingRegistry.load_default()
	var tt := _timetable(reg)
	var s := _npc(reg, NPC.Occupation.STUDENT)
	var n := _npc(reg, NPC.Occupation.NONE)
	_expect(tt, s, _tick(tt, WED, 9), K.SCHOOL, s.school_id, "student Wed 09:00")
	_expect(tt, s, _tick(tt, WED, 16), K.FREE, -1, "student Wed 16:00")
	_expect(tt, n, _tick(tt, WED, 9), K.FREE, -1, "none Wed 09:00")
	_expect(tt, n, _tick(tt, WED, 3), K.SLEEP, n.home_id, "none Wed 03:00")


func test_jitter_within_range() -> void:
	var config := ConfigStore.new()
	var limit := config.get_int("jitter_minutes")
	var rng := SeededRng.new()
	rng.reseed(config.get_int("seed"))
	var pop := Population.generate(rng, BuildingRegistry.load_default(), config)
	var tt := Timetable.new(config, BuildingRegistry.load_default())
	rng.free()
	config.free()
	var outside := 0
	var distinct: Dictionary = {}
	for npc in pop.npcs:
		check(npc.jitter_start.size() == 3 and npc.jitter_end.size() == 3, "%s has wrong jitter size" % npc.label())
		for v in npc.jitter_start + npc.jitter_end:
			if absi(v) > limit:
				outside += 1
			distinct[v] = true
	check(outside == 0, "%d jitter values outside +-%d min" % [outside, limit])
	check(distinct.size() > 2 * limit, "jitter takes only %d distinct values" % distinct.size())
	# Everyone is asleep at home when the run starts.
	var awake := 0
	for npc in pop.npcs:
		if tt.current_block(npc, 0)["kind"] != K.SLEEP:
			awake += 1
	check(awake == 0, "%d NPCs aren't asleep at Monday 00:00" % awake)


func test_jitter_moves_block_edges() -> void:
	var reg := BuildingRegistry.load_default()
	var tt := _timetable(reg)
	var w := _npc(reg, NPC.Occupation.WORKER)
	w.jitter_start[K.WORK] = 20
	w.jitter_end[K.WORK] = -15
	_expect(tt, w, _tick(tt, MON, 9, 10), K.FREE, -1, "Mon 09:10 with +20 start")
	_expect(tt, w, _tick(tt, MON, 9, 20), K.WORK, w.work_id, "Mon 09:20 with +20 start")
	_expect(tt, w, _tick(tt, MON, 16, 44), K.WORK, w.work_id, "Mon 16:44 with -15 end")
	_expect(tt, w, _tick(tt, MON, 16, 45), K.FREE, -1, "Mon 16:45 with -15 end")
	w.jitter_start[K.SLEEP] = -30
	_expect(tt, w, _tick(tt, MON, 22, 30), K.SLEEP, w.home_id, "Mon 22:30 with -30 sleep start")


func test_closed_workplace_is_free() -> void:
	var reg := BuildingRegistry.load_default()
	var tt := _timetable(reg)
	var w := _npc(reg, NPC.Occupation.WORKER)
	reg.set_closed(w.work_id, true)
	_expect(tt, w, _tick(tt, MON, 10), K.FREE, -1, "closed workplace Mon 10:00")
	var next := tt.next_block(w, _tick(tt, MON, 10))
	check(next["kind"] == K.SLEEP, "next block after a closed workday should be SLEEP, got %s" % Timetable.kind_name(next["kind"]))
	reg.set_closed(w.work_id, false)
	_expect(tt, w, _tick(tt, MON, 10), K.WORK, w.work_id, "reopened workplace Mon 10:00")


func test_next_block_and_departure() -> void:
	var reg := BuildingRegistry.load_default()
	var tt := _timetable(reg)
	var w := _npc(reg, NPC.Occupation.WORKER)
	w.jitter_start[K.WORK] = -10
	var next := tt.next_block(w, _tick(tt, MON, 8))
	check(next["kind"] == K.WORK and next["building_id"] == w.work_id, "next block at Mon 08:00 isn't work")
	check(next["start_tick"] == _tick(tt, MON, 8, 50), "work starts at tick %d, expected Mon 08:50" % next["start_tick"])
	check(next["end_tick"] == _tick(tt, MON, 17), "work ends at tick %d, expected Mon 17:00" % next["end_tick"])
	var minutes := Timetable.estimate_travel_minutes(315.0, 21.0)
	check(is_equal_approx(minutes, 15.0), "315 tiles at 21 tiles/min should be 15 min")
	check(tt.departure_tick(next, minutes) == _tick(tt, MON, 8, 35), "departure isn't 15 min before the start")
	# Friday evening: the next work block is Monday.
	var after_friday := tt.next_block(w, _tick(tt, 4, 18))
	check(after_friday["kind"] == K.SLEEP, "Fri 18:00 next block should be SLEEP")
	var weekend := tt.next_block(w, _tick(tt, SAT, 8))
	check(weekend["kind"] == K.SLEEP and weekend["start_tick"] == _tick(tt, SAT, 23), "Sat 08:00 next block should be SLEEP at 23:00")
