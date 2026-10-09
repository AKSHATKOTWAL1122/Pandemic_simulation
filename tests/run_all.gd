extends SceneTree
## Runs every tests/test_*.gd. Exits 0 if all pass, 1 otherwise.
## godot --headless --path . --script res://tests/run_all.gd


func _init() -> void:
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()

	var passed := 0
	var failed := 0
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var seen: Dictionary = {}
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_") or seen.has(method_name):
				continue
			seen[method_name] = true
			var test: BaseTest = script.new()
			test.call(method_name)
			if test.failures.is_empty():
				passed += 1
				print("PASS  %s::%s" % [f, method_name])
			else:
				failed += 1
				print("FAIL  %s::%s" % [f, method_name])
				for message in test.failures:
					print("        - " + message)

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
