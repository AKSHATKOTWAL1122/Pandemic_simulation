class_name GameClock
extends Node
## Game time. Everything is derived from tick * tick_seconds. A run starts Monday 00:00, day 0.

signal ticked(tick: int)

const WEEKDAYS: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const SECONDS_PER_DAY := 86400

var tick: int = 0
var tick_seconds: int = 60


func setup(seconds_per_tick: int) -> void:
	tick_seconds = seconds_per_tick
	tick = 0


func advance() -> void:
	tick += 1
	ticked.emit(tick)


func total_seconds() -> int:
	return tick * tick_seconds


@warning_ignore("integer_division")
func day() -> int:
	return total_seconds() / SECONDS_PER_DAY


## 0 = Monday.
func weekday() -> int:
	return day() % 7


@warning_ignore("integer_division")
func hour() -> int:
	return (total_seconds() % SECONDS_PER_DAY) / 3600


@warning_ignore("integer_division")
func minute() -> int:
	return (total_seconds() % 3600) / 60


func label() -> String:
	return "Day %d %s %02d:%02d" % [day(), WEEKDAYS[weekday()], hour(), minute()]
