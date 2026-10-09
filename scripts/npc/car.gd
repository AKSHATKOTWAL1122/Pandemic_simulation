class_name Car
extends RefCounted
## A household's car. Plain data, indexed by id. One NPC (the driver) per car.

var id: int
var household_id: int
## Road tile where it's parked (or where it last parked while driving).
var tile: Vector2i
## NPC id driving it, or -1 when parked.
var driver: int = -1
