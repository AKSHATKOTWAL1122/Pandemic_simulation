extends Node2D
## Map overlay: a dot for every contact event (blue, last MAX_CONTACT_DOTS) and every infection (red, all).

const TILE_PX := 16.0
const MAX_CONTACT_DOTS := 20000
const CONTACT_COLOUR := Color(0.2, 0.45, 1.0, 0.45)
const INFECTION_COLOUR := Color(0.9, 0.1, 0.15, 0.8)
const DOT_PX := 3.0
## Redraw at most every few frames; thousands of dots are costly to draw each frame.
const REDRAW_EVERY_FRAMES := 6

var show_contacts: bool = false:
	set(value):
		show_contacts = value
		queue_redraw()
var show_infections: bool = false:
	set(value):
		show_infections = value
		queue_redraw()

var _contacts := PackedVector2Array()
var _contact_next: int = 0
var _infections := PackedVector2Array()
var _dirty := false

@onready var _sim: Node = get_node("../Sim")


func _ready() -> void:
	_sim.simulation.listeners.append(_on_tick)
	_sim.simulation_changed.connect(_on_simulation_changed)


func _on_simulation_changed(simulation: Simulation) -> void:
	_contacts.clear()
	_contact_next = 0
	_infections.clear()
	simulation.listeners.append(_on_tick)
	queue_redraw()


func _on_tick(_tick: int, contact_events: Array, infection_events: Array) -> void:
	for e: Dictionary in contact_events:
		var p := Vector2(e["x"], e["y"]) * TILE_PX
		if _contacts.size() < MAX_CONTACT_DOTS:
			_contacts.append(p)
		else:
			_contacts[_contact_next] = p
			_contact_next = (_contact_next + 1) % MAX_CONTACT_DOTS
	for e: Dictionary in infection_events:
		_infections.append(Vector2(e["x"], e["y"]) * TILE_PX)
	if not contact_events.is_empty() or not infection_events.is_empty():
		_dirty = true


func _process(_delta: float) -> void:
	if _dirty and (show_contacts or show_infections) and Engine.get_process_frames() % REDRAW_EVERY_FRAMES == 0:
		_dirty = false
		queue_redraw()


func _draw() -> void:
	var half := Vector2.ONE * DOT_PX / 2.0
	var size := Vector2.ONE * DOT_PX
	if show_contacts:
		for p in _contacts:
			draw_rect(Rect2(p - half, size), CONTACT_COLOUR)
	if show_infections:
		for p in _infections:
			draw_rect(Rect2(p - half * 1.5, size * 1.5), INFECTION_COLOUR)
