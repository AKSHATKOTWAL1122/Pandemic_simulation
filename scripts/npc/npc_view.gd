extends Node2D
## Draws every NPC as a dot, interpolated between ticks.

const TILE_PX := 16.0
const RADIUS_PX := 3.0
const DEFAULT_COLOUR := Color("#7A8CA5")

@onready var _sim: Node = get_node("../Sim")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var simulation: Simulation = _sim.simulation
	if simulation == null:
		return
	var alpha: float = _sim.alpha
	for npc in simulation.population.npcs:
		var p := npc.prev_pos.lerp(npc.pos, alpha) * TILE_PX
		draw_circle(p, RADIUS_PX, colour_of(npc))


## Overridden by spec 11 to colour by SEIR state.
func colour_of(_npc: NPC) -> Color:
	return DEFAULT_COLOUR
