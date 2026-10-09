extends CanvasLayer
## Spec 12: top bar (time, pause, speed, counts), NPC and building inspectors, live SEIR chart,
## overlay toggles and legend. Left-click on the map selects; Space pauses; keys 1-4 set speed.

const PICK_RADIUS_PX := 8.0
const TILE_PX := 16.0
const SPEED_LABELS: Array[String] = ["2/s", "10/s", "60/s", "Max"]
const HEALTH_NAMES: Array[String] = ["Susceptible", "Exposed", "Infected", "Recovered"]
const ACTIVITY_NAMES: Array[String] = ["in", "walking to", "driving to"]
const SeirChart := preload("res://scripts/ui/seir_chart.gd")
const MapView := preload("res://scripts/world/map_view.gd")
const NpcView := preload("res://scripts/npc/npc_view.gd")

var _time_label: Label
var _counts_label: Label
var _pause_button: Button
var _speed_buttons: Array[Button] = []
var _npc_panel: PanelContainer
var _npc_label: Label
var _infect_button: Button
var _building_panel: PanelContainer
var _building_label: Label
var _close_button: Button
var _selected_npc: int = -1
var _selected_building: int = -1
var _chart: Control
var _experiment_dialog: FileDialog

@onready var _sim: Node = get_node("../Sim")
@onready var _camera: Camera2D = get_node("../Camera")
@onready var _npc_view: Node2D = get_node("../NpcView")
@onready var _overlay: Node2D = get_node("../EventOverlay")


func _ready() -> void:
	_build_top_bar()
	_build_npc_panel()
	_build_building_panel()
	_build_chart()
	_build_legend()
	_sim.speed_changed.connect(_on_speed_changed)
	_sim.simulation_changed.connect(_on_simulation_changed)
	_sim.set_speed(1)


func _process(_delta: float) -> void:
	var simulation: Simulation = _sim.simulation
	_time_label.text = simulation.clock.label()
	var c := simulation.epidemic.counts
	_counts_label.text = "S %d   E %d   I %d   R %d" % [c[0], c[1], c[2], c[3]]
	_pause_button.text = "Play" if _sim.paused else "Pause"
	_npc_panel.visible = _selected_npc >= 0
	if _selected_npc >= 0:
		_npc_label.text = _npc_text(simulation.population.npcs[_selected_npc])
	_building_panel.visible = _selected_building >= 0
	if _selected_building >= 0:
		_building_label.text = _building_text(_selected_building)
		var b := World.buildings.by_id(_selected_building)
		_close_button.text = "Open" if b.closed else "Close"
		_close_button.disabled = b.has_purpose("home")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_SPACE:
			_toggle_pause()
		elif key >= KEY_1 and key <= KEY_4:
			_sim.set_speed(key - KEY_1)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_at(_camera.get_canvas_transform().affine_inverse() * mb.position)


# --- Selection ---------------------------------------------------------------

func _select_at(world_px: Vector2) -> void:
	var simulation: Simulation = _sim.simulation
	var best := -1
	var best_dist := PICK_RADIUS_PX / _camera.zoom.x
	for npc in simulation.population.npcs:
		var p := npc.prev_pos.lerp(npc.pos, _sim.alpha) * TILE_PX
		var d := p.distance_to(world_px)
		if d <= best_dist:
			best_dist = d
			best = npc.id
	_selected_npc = best
	_selected_building = -1
	if best < 0:
		var tile := Vector2i((world_px / TILE_PX).floor())
		_selected_building = World.buildings.at_tile(tile.x, tile.y)


func _npc_text(npc: NPC) -> String:
	var simulation: Simulation = _sim.simulation
	var tick_seconds := simulation.clock.tick_seconds
	var health := "Immune (permanent)" if npc.immune_forever else HEALTH_NAMES[npc.health]
	var since := _duration((simulation.clock.tick - npc.health_since_tick) * tick_seconds)
	var place := npc.place_id()
	var doing: String
	if npc.activity == NPC.Activity.AT_BUILDING:
		doing = "in %s" % _building_name(npc.building_id)
		if npc.asleep:
			doing += " (asleep)"
	else:
		doing = "%s %s" % [ACTIVITY_NAMES[npc.activity], _building_name(npc.dest_id)]
	var lines: Array[String] = [
		npc.label(),
		"%s for %s" % [health, since],
		"Occupation: %s" % npc.occupation_name(),
		"Home: %s" % _building_name(npc.home_id),
		"%s: %s" % ["School" if npc.school_id >= 0 else "Work", _building_name(place) if place >= 0 else "-"],
		"Now: %s" % doing,
		"Contacts: %d" % npc.contact_count,
		"Infected by: %s" % (simulation.population.npcs[npc.infected_by].label() if npc.infected_by >= 0 else "-"),
	]
	return "\n".join(lines)


func _building_text(id: int) -> String:
	var b := World.buildings.by_id(id)
	var inside := 0
	var infected := 0
	for npc in (_sim.simulation as Simulation).population.npcs:
		if npc.activity == NPC.Activity.AT_BUILDING and npc.building_id == id:
			inside += 1
			if npc.health == NPC.Health.I:
				infected += 1
	return "Building #%d%s\n%s\nPeople inside: %d (%d infected)" % [
		id, "  [CLOSED]" if b.closed else "", ", ".join(b.purposes), inside, infected]


static func _building_name(id: int) -> String:
	if id < 0:
		return "-"
	return "#%d %s" % [id, World.buildings.by_id(id).purposes[0]]


static func _duration(seconds: int) -> String:
	@warning_ignore("integer_division")
	var days := seconds / 86400
	@warning_ignore("integer_division")
	var hours := (seconds % 86400) / 3600
	@warning_ignore("integer_division")
	var minutes := (seconds % 3600) / 60
	if days > 0:
		return "%dd %dh" % [days, hours]
	return "%dh %02dm" % [hours, minutes]


# --- Actions -----------------------------------------------------------------

func _toggle_pause() -> void:
	_sim.paused = not _sim.paused


func _on_speed_changed(index: int) -> void:
	for i in _speed_buttons.size():
		_speed_buttons[i].button_pressed = i == index


func _on_simulation_changed(simulation: Simulation) -> void:
	_selected_npc = -1
	_selected_building = -1
	_chart.attach(simulation)


func _on_experiment_chosen(path: String) -> void:
	var runner: BatchRunner = _sim.get_node_or_null("BatchRunner")
	if runner == null:
		runner = BatchRunner.new()
		runner.name = "BatchRunner"
		_sim.add_child(runner)
	runner.start(path)


func _on_infect() -> void:
	if _selected_npc >= 0:
		(_sim.simulation as Simulation).infect(_selected_npc)


func _on_close_toggled() -> void:
	if _selected_building >= 0:
		var b := World.buildings.by_id(_selected_building)
		World.buildings.set_closed(b.id, not b.closed)


# --- Layout ------------------------------------------------------------------

static func _panel(anchor_left: float, anchor_top: float, pos: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = anchor_left
	panel.anchor_right = anchor_left
	panel.anchor_top = anchor_top
	panel.anchor_bottom = anchor_top
	panel.position = pos
	return panel


func _build_top_bar() -> void:
	var panel := _panel(0, 0, Vector2(8, 8))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_time_label = Label.new()
	_time_label.custom_minimum_size.x = 150
	row.add_child(_time_label)
	_pause_button = Button.new()
	_pause_button.custom_minimum_size.x = 64
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(_toggle_pause)
	row.add_child(_pause_button)
	var group := ButtonGroup.new()
	for i in SPEED_LABELS.size():
		var b := Button.new()
		b.text = SPEED_LABELS[i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Key %d" % (i + 1)
		b.pressed.connect(_sim.set_speed.bind(i))
		row.add_child(b)
		_speed_buttons.append(b)
	_counts_label = Label.new()
	row.add_child(_counts_label)
	var run := Button.new()
	run.text = "Run experiment…"
	run.focus_mode = Control.FOCUS_NONE
	row.add_child(run)
	_experiment_dialog = FileDialog.new()
	_experiment_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_experiment_dialog.access = FileDialog.ACCESS_RESOURCES
	_experiment_dialog.current_dir = "res://experiments"
	_experiment_dialog.filters = PackedStringArray(["*.json ; Experiment files"])
	_experiment_dialog.file_selected.connect(_on_experiment_chosen)
	add_child(_experiment_dialog)
	run.pressed.connect(func() -> void: _experiment_dialog.popup_centered(Vector2i(640, 420)))


func _build_npc_panel() -> void:
	_npc_panel = _panel(1, 0, Vector2(-268, 8))
	_npc_panel.custom_minimum_size.x = 260
	add_child(_npc_panel)
	var box := VBoxContainer.new()
	_npc_panel.add_child(box)
	_npc_label = Label.new()
	box.add_child(_npc_label)
	_infect_button = Button.new()
	_infect_button.text = "Infect"
	_infect_button.focus_mode = Control.FOCUS_NONE
	_infect_button.pressed.connect(_on_infect)
	box.add_child(_infect_button)


func _build_building_panel() -> void:
	_building_panel = _panel(1, 0, Vector2(-268, 8))
	_building_panel.custom_minimum_size.x = 260
	add_child(_building_panel)
	var box := VBoxContainer.new()
	_building_panel.add_child(box)
	_building_label = Label.new()
	box.add_child(_building_label)
	_close_button = Button.new()
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.tooltip_text = "Homes can't be closed"
	_close_button.pressed.connect(_on_close_toggled)
	box.add_child(_close_button)


func _build_chart() -> void:
	var panel := _panel(0, 1, Vector2(8, -188))
	add_child(panel)
	_chart = SeirChart.new()
	_chart.custom_minimum_size = Vector2(460, 172)
	panel.add_child(_chart)
	_chart.attach(_sim.simulation)


func _build_legend() -> void:
	var panel := _panel(1, 1, Vector2(-208, -392))
	panel.custom_minimum_size.x = 200
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for i in 4:
		box.add_child(_swatch(NpcView.HEALTH_COLOURS[i], HEALTH_NAMES[i]))
	box.add_child(_swatch(NpcView.IMMUNE_COLOUR, "Immune (permanent)"))
	box.add_child(HSeparator.new())
	for purpose: String in MapView.PURPOSE_COLOURS:
		box.add_child(_swatch(MapView.PURPOSE_COLOURS[purpose], purpose.capitalize()))
	box.add_child(HSeparator.new())
	box.add_child(_toggle("Contact dots", func(on: bool) -> void: _overlay.show_contacts = on))
	box.add_child(_toggle("Infection dots", func(on: bool) -> void: _overlay.show_infections = on))
	box.add_child(_toggle("Parked cars", func(on: bool) -> void: _npc_view.show_parked_cars = on))


static func _swatch(colour: Color, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var rect := ColorRect.new()
	rect.color = colour
	rect.custom_minimum_size = Vector2(14, 14)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rect)
	var label := Label.new()
	label.text = text
	row.add_child(label)
	return row


static func _toggle(text: String, on_toggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(on_toggled)
	return box
