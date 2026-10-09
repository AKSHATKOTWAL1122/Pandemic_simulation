extends Node
## Runs the simulation in the scene: ticks_per_second game ticks per real second,
## or as many ticks as fit in MAX_FRAME_USEC each frame at Max speed.
## `alpha` (0..1) is how far we are between the last tick and the next, for smooth drawing.

## Speed presets in ticks per second; 0 means Max. Keys 1-4 in the HUD.
const SPEEDS: Array[float] = [2.0, 10.0, 60.0, 0.0]
const MAX_FRAME_USEC := 16000

signal speed_changed(index: int)

var paused: bool = false
var ticks_per_second: float = 10.0
var alpha: float = 0.0
var simulation: Simulation

var _accumulator: float = 0.0
var _max_speed: bool = false


func _ready() -> void:
	simulation = Simulation.new(Config, Rng, SimClock, World.buildings, World.paths)
	ticks_per_second = Config.get_float("ticks_per_second")


func set_speed(index: int) -> void:
	_max_speed = SPEEDS[index] == 0.0
	if not _max_speed:
		ticks_per_second = SPEEDS[index]
	_accumulator = 0.0
	speed_changed.emit(index)


func is_max_speed() -> bool:
	return _max_speed


func _process(delta: float) -> void:
	if paused:
		return
	if _max_speed:
		# Wall-clock time only decides how many ticks to run this frame, never what they do.
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < MAX_FRAME_USEC:
			simulation.step()
		alpha = 1.0
		return
	_accumulator += delta * ticks_per_second
	var due := floori(_accumulator)
	for i in due:
		simulation.step()
	_accumulator -= due
	alpha = clampf(_accumulator, 0.0, 1.0)
