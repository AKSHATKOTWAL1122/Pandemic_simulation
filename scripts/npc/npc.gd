class_name NPC
extends RefCounted
## One person. Plain data, stored in Population.npcs and indexed by id — never a Node.

enum Occupation { STUDENT, WORKER, NONE }

var id: int
var household_id: int = -1
var home_id: int = -1
var occupation: int = Occupation.NONE
var work_id: int = -1
var school_id: int = -1
var friends: Array[int] = []
## Tiles, float.
var pos: Vector2 = Vector2.ZERO
## Spec 06: fixed minutes added to each block's start / end, indexed by Timetable.Kind
## (SLEEP, WORK, SCHOOL). Drawn once at creation.
var jitter_start := PackedInt32Array([0, 0, 0])
var jitter_end := PackedInt32Array([0, 0, 0])


## Shown as npc_000.
func label() -> String:
	return "npc_%03d" % id


func occupation_name() -> String:
	return Occupation.keys()[occupation]


## Building where this NPC works or studies, or -1.
func place_id() -> int:
	if work_id >= 0:
		return work_id
	return school_id


## One deterministic line with every field, for comparing populations.
func serialize() -> String:
	return "%s hh=%d home=%d occ=%s work=%d school=%d friends=%s pos=%s jitter=%s/%s" % [
		label(), household_id, home_id, occupation_name(), work_id, school_id,
		friends, var_to_str(pos), jitter_start, jitter_end,
	]
