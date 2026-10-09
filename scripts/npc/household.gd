class_name Household
extends RefCounted
## People who share a home (and maybe a car). Plain data, indexed by id.

var id: int
var home_id: int = -1
var members: Array[int] = []
## Decided in spec 05; the Car objects themselves are spec 09.
var has_car: bool = false


func serialize() -> String:
	return "hh_%03d home=%d car=%s members=%s" % [id, home_id, has_car, members]
