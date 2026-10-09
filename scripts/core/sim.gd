extends Node
## Runs the simulation in the scene: ticks_per_second game ticks per real second.
## `alpha` (0..1) is how far we are between the last tick and the next, for smooth drawing.

var paused: bool = false
var ticks_per_second: float = 10.0
var alpha: float = 0.0
var simulation: Simulation

var _accumulator: float = 0.0


func _ready() -> void:
	simulation = Simulation.new(Config, Rng, SimClock, World.buildings, World.paths)
	ticks_per_second = Config.get_float("ticks_per_second")


func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta * ticks_per_second
	var due := floori(_accumulator)
	for i in due:
		simulation.step()
	_accumulator -= due
	alpha = clampf(_accumulator, 0.0, 1.0)
