extends Camera2D
## Right- or middle-drag to pan, mouse wheel to zoom (around the cursor). Starts framing the whole map.

const MAX_ZOOM := 4.0
const ZOOM_STEP := 1.15

var _min_zoom := 0.1
var _dragging := false


func _ready() -> void:
	var map_px := float(CityMap.SIZE * 16)
	var view := get_viewport_rect().size
	_min_zoom = minf(view.x, view.y) / map_px
	zoom = Vector2.ONE * _min_zoom
	position = Vector2.ONE * map_px / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(ZOOM_STEP, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / ZOOM_STEP, mb.position)
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen_pos
	zoom = Vector2.ONE * clampf(zoom.x * factor, _min_zoom, MAX_ZOOM)
	force_update_scroll()
	var after := get_canvas_transform().affine_inverse() * screen_pos
	position += before - after
