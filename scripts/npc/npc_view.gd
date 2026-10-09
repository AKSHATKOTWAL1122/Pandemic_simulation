extends Node2D
## Draws every NPC as a dot (drivers as a car), interpolated between ticks.

const TILE_PX := 16.0
const RADIUS_PX := 3.0
const DEFAULT_COLOUR := Color("#7A8CA5")
const CAR_SIZE_PX := Vector2(10, 6)
const PARKED_COLOUR := Color(0.1, 0.1, 0.1, 0.6)

## Spec 12 toggles this.
var show_parked_cars: bool = false

@onready var _sim: Node = get_node("../Sim")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var simulation: Simulation = _sim.simulation
	if simulation == null:
		return
	var alpha: float = _sim.alpha
	if show_parked_cars:
		for car in simulation.fleet.cars:
			if car.driver < 0:
				var c := (Vector2(car.tile) + Vector2(0.5, 0.5)) * TILE_PX
				draw_rect(Rect2(c - CAR_SIZE_PX / 2.0, CAR_SIZE_PX), PARKED_COLOUR)
	for npc in simulation.population.npcs:
		var p := npc.prev_pos.lerp(npc.pos, alpha) * TILE_PX
		if npc.activity == NPC.Activity.DRIVING:
			var d := npc.pos - npc.prev_pos
			var size := CAR_SIZE_PX if absf(d.x) >= absf(d.y) else Vector2(CAR_SIZE_PX.y, CAR_SIZE_PX.x)
			draw_rect(Rect2(p - size / 2.0, size), colour_of(npc))
			draw_rect(Rect2(p - size / 2.0, size), Color.BLACK, false, 1.0)
		else:
			draw_circle(p, RADIUS_PX, colour_of(npc))


## Overridden by spec 11 to colour by SEIR state.
func colour_of(_npc: NPC) -> Color:
	return DEFAULT_COLOUR
