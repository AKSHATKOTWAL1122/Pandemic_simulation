class_name NPC
extends RefCounted
## One person. Plain data, stored in Population.npcs and indexed by id — never a Node.

enum Occupation { STUDENT, WORKER, NONE }
## Spec 11: SEIR state.
enum Health { S, E, I, R }
## Spec 08/09: what the NPC is doing right now.
enum Activity { AT_BUILDING, WALKING, DRIVING }

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
## Spec 07: 0..100, indexed by Desires.Need (HUNGER, FUN, SOCIAL, SHOPPING).
var needs := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])

## Spec 08: movement state, owned by NpcBehaviour.
var activity: int = Activity.AT_BUILDING
## Building the NPC is inside (AT_BUILDING), else -1.
var building_id: int = -1
## Position at the start of the current tick, for drawing between ticks.
var prev_pos: Vector2 = Vector2.ZERO
## Trip waypoints (tiles, float) and the next one to reach.
var route := PackedVector2Array()
var route_index: int = 0
## Trip destination and what to do on arrival.
var dest_id: int = -1
var dest_need: int = -1
var dest_stay_ticks: int = 0
## Current stay: the need it satisfies (-1 none) and when it ends.
var stay_need: int = -1
var stay_until_tick: int = 0
var next_decision_tick: int = 0
var indoor_target: Vector2 = Vector2.ZERO
var next_wander_tick: int = 0
var asleep: bool = false
## Spec 09: driving a car.
var in_car: bool = false

## Spec 10: number of encounters with anyone so far.
var contact_count: int = 0

## Spec 11: infection state, owned by Epidemic.
var health: int = Health.S
var health_since_tick: int = 0
## Who infected this NPC most recently (-1: nobody, or patient zero / manual).
var infected_by: int = -1
var first_infected_tick: int = -1
## Stays in R forever (spec 13 immune share).
var immune_forever: bool = false


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
	return "%s hh=%d home=%d occ=%s work=%d school=%d friends=%s pos=%s jitter=%s/%s needs=%s" % [
		label(), household_id, home_id, occupation_name(), work_id, school_id,
		friends, var_to_str(pos), jitter_start, jitter_end, var_to_str(needs),
	]
