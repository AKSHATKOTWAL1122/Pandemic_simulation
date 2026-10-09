extends SceneTree
## UI smoke test for spec 12, run on the real scene with synthetic input, in a window
## (headless windows are 64 x 64 px, so the HUD panels cover the map):
## godot --path . --script res://tests/ui_smoke.gd [-- <screenshot folder>]   (exits 0 / 1)

var _frames := 0
var _failures: Array[String] = []
var _step := 0
var _mall_id := -1
var _mall_entries := 0
var _shots := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_shots = args[0] if args.size() > 0 else ""
	change_scene_to_file("res://scenes/main.tscn")


func _check(cond: bool, message: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + message)
	if not cond:
		_failures.append(message)


func _click(world_tile: Vector2) -> void:
	var screen: Vector2 = current_scene.get_viewport().get_canvas_transform() * (world_tile * 16.0)
	# Move the mouse there first: the very first button event without a prior motion is dropped.
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	root.push_input(motion)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = screen
		ev.global_position = screen
		root.push_input(ev)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = pressed
		root.push_input(ev)


func _shot(name: String) -> void:
	if _shots != "":
		root.get_texture().get_image().save_png(_shots.path_join(name))


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or _frames < 3:
		return false
	var sim: Node = current_scene.get_node("Sim")
	var hud: CanvasLayer = current_scene.get_node("HUD")
	var camera: Camera2D = current_scene.get_node("Camera")
	var simulation: Simulation = sim.simulation
	var world: Node = root.get_node("World")
	match _step:
		0:
			# Zoom in on NPC 0 and click it.
			sim.paused = true
			var npc: NPC = simulation.population.npcs[0]
			camera.zoom = Vector2.ONE * 2.0
			camera.position = npc.pos * 16.0
			_step += 1
		1:
			_click(simulation.population.npcs[0].pos)
			_step += 1
		2:
			_check(hud._selected_npc == 0, "clicking NPC 0 selects it (got %d)" % hud._selected_npc)
			_check(hud._npc_panel.visible and hud._npc_label.text.begins_with("npc_000"), "inspector shows npc_000")
			hud._infect_button.pressed.emit()
			_check(simulation.population.npcs[0].health == NPC.Health.I, "Infect button sets the NPC to Infected")
			_key(KEY_SPACE)
			_step += 1
		3:
			_check(not sim.paused, "Space toggles pause off")
			_key(KEY_4)
			_step += 1
		4:
			_check(sim.is_max_speed(), "key 4 sets Max speed")
			_key(KEY_2)
			_step += 1
		5:
			_check(not sim.is_max_speed() and sim.ticks_per_second == 10.0, "key 2 sets 10 ticks/s")
			# Select a mall by clicking its centre, then close it.
			for b: Building in world.buildings.with_purpose("mall"):
				_mall_id = b.id
				break
			var mall: Building = world.buildings.by_id(_mall_id)
			camera.position = mall.center() * 16.0
			_click(mall.center() + Vector2(0.37, 0.41))
			_step += 1
		6:
			_check(hud._selected_building == _mall_id, "clicking the mall selects it (got %d)" % hud._selected_building)
			_check(hud._building_panel.visible and hud._building_label.text.contains("mall"), "building panel shows the mall")
			hud._close_button.pressed.emit()
			_check(world.buildings.is_closed(_mall_id), "Close button closes the mall")
			simulation.listeners.append(func(_t: int, _c: Array, _i: Array) -> void: pass)
			# Count NPCs who arrive in the mall from now on.
			for npc in simulation.population.npcs:
				npc.set_meta("was_in_mall", npc.activity == NPC.Activity.AT_BUILDING and npc.building_id == _mall_id)
			sim.set_speed(3)
			_step += 1
		7:
			for npc in simulation.population.npcs:
				var inside := npc.activity == NPC.Activity.AT_BUILDING and npc.building_id == _mall_id
				if inside and not npc.get_meta("was_in_mall"):
					_mall_entries += 1
				npc.set_meta("was_in_mall", inside)
			if simulation.clock.tick >= 3 * 1440:
				_check(_mall_entries == 0, "nobody entered the closed mall in 3 days (%d entries)" % _mall_entries)
				var chart: Control = null
				for child in hud.get_children():
					if child is PanelContainer and child.get_child(0).has_method("attach"):
						chart = child.get_child(0)
				var samples: int = chart.sample_ticks.size()
				var hours := int(simulation.clock.tick / 60)
				_check(abs(samples - 1 - hours) <= 1, "chart has one sample per game hour (%d samples, %d hours)" % [samples, hours])
				var c := simulation.epidemic.counts
				var last_i: float = chart.series[2][samples - 1]
				_check(is_equal_approx(last_i, 100.0 * c[2] / 1000.0) or simulation.clock.tick % 60 != 0,
					"chart's last I sample matches the counts")
				sim.set_speed(1)
				hud._overlay.show_contacts = true
				hud._overlay.show_infections = true
				hud._npc_view.show_parked_cars = true
				camera.zoom = Vector2.ONE * camera._min_zoom
				camera.position = Vector2.ONE * 128 * 16
				_step += 1
		8, 9, 10:
			_step += 1
		11:
			_shot("ui_full.png")
			world.buildings.set_closed(_mall_id, false)
			print("%d failed" % _failures.size())
			quit(1 if _failures.size() > 0 else 0)
	return false
