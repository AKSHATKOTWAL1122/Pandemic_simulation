extends Control
## Live SEIR chart: % of population in S, E, I, R against days, sampled every game hour.

const COLOURS: Array[Color] = [Color("#7A8CA5"), Color("#F2C14E"), Color("#D7263D"), Color("#3BB273")]
const LABELS: Array[String] = ["S", "E", "I", "R"]
const PAD := Vector2(34, 10)

## One PackedFloat32Array of percentages per state; one sample per game hour.
var series: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
var sample_ticks := PackedInt32Array()

var _simulation: Simulation
var _ticks_per_hour: int = 60
var _tick_seconds: int = 60


func attach(simulation: Simulation) -> void:
	_simulation = simulation
	for s in series:
		s.clear()
	sample_ticks.clear()
	_tick_seconds = simulation.config.get_int("tick_seconds")
	_ticks_per_hour = maxi(1, roundi(3600.0 / _tick_seconds))
	_sample(-1)
	simulation.listeners.append(_on_tick)


func _on_tick(tick: int, _contacts: Array, _infections: Array) -> void:
	if (tick + 1) % _ticks_per_hour == 0:
		_sample(tick)


func _sample(tick: int) -> void:
	var total := float(_simulation.population.count())
	for i in 4:
		series[i].append(100.0 * _simulation.epidemic.counts[i] / total)
	sample_ticks.append(tick)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var plot := Rect2(PAD, size - PAD * Vector2(1.6, 2.6))
	draw_rect(plot, Color(0, 0, 0, 0.25))
	for pct: int in [0, 50, 100]:
		var y := plot.end.y - plot.size.y * pct / 100.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1, 1, 1, 0.15))
		draw_string(font, Vector2(2, y + 4), "%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var n := sample_ticks.size()
	var days := maxf(1.0, ceilf(n / 24.0))
	draw_string(font, Vector2(plot.end.x - 60, size.y - 4), "day %d" % int(days), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	for i in 4:
		draw_string(font, Vector2(plot.position.x + 6 + i * 28, size.y - 4), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOURS[i])
	if n < 2:
		return
	for i in 4:
		var points := PackedVector2Array()
		points.resize(n)
		for k in n:
			points[k] = Vector2(
				plot.position.x + plot.size.x * (k / 24.0) / days,
				plot.end.y - plot.size.y * series[i][k] / 100.0)
		draw_polyline(points, COLOURS[i], 1.5, true)
