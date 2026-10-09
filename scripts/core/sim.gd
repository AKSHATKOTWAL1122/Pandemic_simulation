extends Node
## Runs the simulation: ticks_per_frame ticks each frame, systems in a fixed order.

var paused: bool = false
var ticks_per_frame: int = 1


func _ready() -> void:
	Rng.reseed(Config.get_int("seed"))
	SimClock.setup(Config.get_int("tick_seconds"))
	ticks_per_frame = Config.get_int("ticks_per_frame")


func _process(_delta: float) -> void:
	if paused:
		return
	for i in ticks_per_frame:
		_step()


func _step() -> void:
	# Systems run here in a fixed order; later specs add them.
	SimClock.advance()
