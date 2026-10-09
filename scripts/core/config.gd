class_name ConfigStore
extends Node
## Holds every tunable number. Loaded from config/default.json.

const DEFAULT_PATH := "res://config/default.json"

var _values: Dictionary = {}


func _init() -> void:
	load_file(DEFAULT_PATH)


func load_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Config: cannot read %s" % path)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config: %s is not a JSON object" % path)
		return
	_values = parsed


## Overrides a value (experiments, tests). A Dictionary value is merged into an existing one.
func set_value(key: String, value: Variant) -> void:
	if value is Dictionary and _values.get(key) is Dictionary:
		var merged: Dictionary = (_values[key] as Dictionary).duplicate(true)
		merged.merge(value, true)
		_values[key] = merged
	else:
		_values[key] = value


func has_value(key: String) -> bool:
	return _values.has(key)


func get_value(key: String) -> Variant:
	if not _values.has(key):
		push_error("Config: missing key '%s'" % key)
		assert(false, "Config: missing key '%s'" % key)
		return null
	return _values[key]


func get_int(key: String) -> int:
	return int(get_value(key))


func get_float(key: String) -> float:
	return float(get_value(key))
