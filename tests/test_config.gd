extends BaseTest


func test_default_config_has_spec_01_keys() -> void:
	var config := ConfigStore.new()
	for key in ["seed", "tick_seconds", "days", "population", "ticks_per_second"]:
		check(config.has_value(key), "missing key '%s'" % key)
	check(config.get_int("tick_seconds") == 60, "tick_seconds is not 60")
	config.free()
