extends Node
## Runs the simulation in the scene: ticks_per_second game ticks per real second,
## or as many ticks as fit in MAX_FRAME_USEC each frame at Max speed.
## `alpha` (0..1) is how far we are between the last tick and the next, for smooth drawing.

## Speed presets in ticks per second; 0 means Max. Keys 1-4 in the HUD.
const SPEEDS: Array[float] = [2.0, 10.0, 60.0, 0.0]
const MAX_FRAME_USEC := 16000

signal speed_changed(index: int)
## A new Simulation replaced the old one (batch runs); views re-attach.
signal simulation_changed(simulation: Simulation)

var paused: bool = false
var ticks_per_second: float = 10.0
var alpha: float = 0.0
var simulation: Simulation
## Stop stepping at this tick (-1: never). Set by BatchRunner.
var tick_limit: int = -1

var _accumulator: float = 0.0
var _live_exporter: RunExporter
var _max_speed: bool = false


func _ready() -> void:
	simulation = Simulation.new(Config, Rng, SimClock, World.buildings, World.paths)
	ticks_per_second = Config.get_float("ticks_per_second")
	var experiment_path := BatchRunner.experiment_from_cmdline()
	if experiment_path != "":
		var runner := BatchRunner.new()
		runner.quit_when_done = true
		add_child(runner)
		runner.start.call_deferred(experiment_path)
	elif Config.get_value("export_live_runs"):
		_live_exporter = RunExporter.new()
		var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
		_live_exporter.open("res://output/live/run_%s" % stamp, simulation, {"name": "live", "run": stamp})


func _exit_tree() -> void:
	stop_live_export()


## Finishes the hand-started run's export (npcs.csv). Called on exit or when a batch replaces it.
func stop_live_export() -> void:
	if _live_exporter != null:
		_live_exporter.finish()
		_live_exporter = null


func replace_simulation(new_simulation: Simulation) -> void:
	stop_live_export()
	simulation = new_simulation
	_accumulator = 0.0
	alpha = 1.0
	simulation_changed.emit(simulation)


func _can_step() -> bool:
	return tick_limit < 0 or simulation.clock.tick < tick_limit


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
		while Time.get_ticks_usec() - start < MAX_FRAME_USEC and _can_step():
			simulation.step()
		alpha = 1.0
		return
	_accumulator += delta * ticks_per_second
	var due := floori(_accumulator)
	for i in due:
		if _can_step():
			simulation.step()
	_accumulator -= due
	alpha = clampf(_accumulator, 0.0, 1.0)
