extends BaseTest


func _clock_at(tick: int) -> GameClock:
	var clock := GameClock.new()
	clock.setup(60)
	clock.tick = tick
	return clock


func test_start_is_monday_midnight() -> void:
	var clock := _clock_at(0)
	check(clock.label() == "Day 0 Mon 00:00", "tick 0 is '%s'" % clock.label())
	clock.free()


func test_one_day_later_is_tuesday() -> void:
	var clock := _clock_at(1440)
	check(clock.label() == "Day 1 Tue 00:00", "tick 1440 is '%s'" % clock.label())
	clock.free()


func test_hour_and_minute() -> void:
	var clock := _clock_at(90)
	check(clock.hour() == 1 and clock.minute() == 30, "tick 90 is '%s'" % clock.label())
	clock.free()


func test_week_wraps() -> void:
	var clock := _clock_at(7 * 1440 + 23 * 60 + 59)
	check(clock.label() == "Day 7 Mon 23:59", "got '%s'" % clock.label())
	clock.free()


func test_advance_emits_tick() -> void:
	var clock := _clock_at(0)
	var got: Array[int] = []
	clock.ticked.connect(func(t: int) -> void: got.append(t))
	clock.advance()
	clock.advance()
	check(got == [1, 2] and clock.tick == 2, "advance emitted %s" % [got])
	clock.free()
