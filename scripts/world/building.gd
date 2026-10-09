class_name Building
extends RefCounted

const PURPOSES: Array[String] = ["home", "workplace", "school", "restaurant", "nightclub", "mall"]
const WORK_PURPOSES: Array[String] = ["workplace", "school", "restaurant", "nightclub", "mall"]

var id: int
var island: int
var rect: Rect2i
var entrance: Vector2i
var purposes: PackedStringArray
var home_capacity: int
var jobs: int
var closed: bool = false


func has_purpose(purpose: String) -> bool:
	return purposes.has(purpose)


func center() -> Vector2:
	return Vector2(rect.position) + Vector2(rect.size) / 2.0
