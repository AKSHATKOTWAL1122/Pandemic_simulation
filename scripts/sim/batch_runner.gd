class_name BatchRunner
extends Node
## Spec 13: runs every run of an experiment file in the window, at Max speed, one after another,
## exporting each (spec 14). Child of the Sim node.
## From the command line: godot --path . -- --experiment experiments/<name>.json (quits when done).

signal finished(experiment_name: String)

var quit_when_done: bool = false
var experiment: Experiment
var run_index: int = -1

var _config: ConfigStore
var _exporter: RunExporter
var _total_ticks: int = 0

@onready var _sim: Node = get_parent()


static func experiment_from_cmdline() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--experiment")
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""


func start(file_path: String) -> void:
	var path := file_path if file_path.begins_with("res://") or file_path.is_absolute_path() else "res://" + file_path
	experiment = Experiment.load_file(path)
	if experiment == null:
		_fail("cannot read experiment %s" % path)
		return
	var problem := experiment.validate(World.buildings)
	if problem != "":
		_fail("%s: %s" % [path, problem])
		return
	print("Experiment %s: %d runs from seed %d" % [experiment.name, experiment.runs, experiment.base_seed])
	run_index = -1
	_next_run()


func is_running() -> bool:
	return experiment != null and run_index >= 0


func _next_run() -> void:
	run_index += 1
	if run_index >= experiment.runs:
		print("Experiment %s finished: output/%s/" % [experiment.name, experiment.name])
		var done_name := experiment.name
		experiment = null
		_sim.tick_limit = -1
		_sim.paused = true
		finished.emit(done_name)
		if quit_when_done:
			get_tree().quit(0)
		return
	for b in World.buildings.buildings:
		b.closed = false
	var old_config := _config
	_config = experiment.make_config(run_index)
	var simulation := Simulation.new(_config, Rng, SimClock, World.buildings, World.paths)
	var applied := experiment.apply(simulation)
	_exporter = RunExporter.new()
	_exporter.open("res://output/%s/run_%d" % [experiment.name, run_index], simulation, experiment.describe(run_index, applied))
	_total_ticks = Experiment.total_ticks(_config)
	_sim.tick_limit = _total_ticks
	_sim.replace_simulation(simulation)
	if old_config != null:
		old_config.free()
	_sim.paused = false
	_sim.set_speed(3)
	print("  run %d (seed %d): %d ticks" % [run_index, experiment.base_seed + run_index, _total_ticks])


func _process(_delta: float) -> void:
	if not is_running():
		return
	var simulation: Simulation = _sim.simulation
	if simulation.clock.tick >= _total_ticks:
		_exporter.finish()
		_exporter = null
		var c := simulation.epidemic.counts
		print("  run %d done: S %d E %d I %d R %d" % [run_index, c[0], c[1], c[2], c[3]])
		_next_run()


func _exit_tree() -> void:
	if _config != null:
		_config.free()
		_config = null


func _fail(message: String) -> void:
	push_error("BatchRunner: " + message)
	experiment = null
	if quit_when_done:
		get_tree().quit(1)
