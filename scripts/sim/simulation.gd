class_name Simulation
extends RefCounted
## One run of the city: population and every per-tick system, in a fixed order.
## Plain object, so tests can run it without the scene.

var config: ConfigStore
var rng: SeededRng
var clock: GameClock
var buildings: BuildingRegistry
var paths: Paths
var population: Population
var timetable: Timetable
var desires: Desires
var fleet: CarFleet
var behaviour: NpcBehaviour
var contacts: ContactTracker


func _init(p_config: ConfigStore, p_rng: SeededRng, p_clock: GameClock, p_buildings: BuildingRegistry, p_paths: Paths) -> void:
	config = p_config
	rng = p_rng
	clock = p_clock
	buildings = p_buildings
	paths = p_paths
	rng.reseed(config.get_int("seed"))
	clock.setup(config.get_int("tick_seconds"))
	population = Population.generate(rng, buildings, config)
	timetable = Timetable.new(config, buildings)
	desires = Desires.new(config, buildings, population.npcs, rng)
	fleet = CarFleet.create(population, buildings, paths)
	behaviour = NpcBehaviour.new(config, clock, rng, buildings, paths, population, timetable, desires, fleet)
	contacts = ContactTracker.new(config, population.npcs)


## Builds a self-contained run (own RNG, clock and buildings) for tests and batch runs.
static func standalone(p_config: ConfigStore) -> Simulation:
	var buildings := BuildingRegistry.load_default()
	var paths := Paths.build(CityMap.load_default(), buildings, p_config)
	return Simulation.new(p_config, SeededRng.new(), GameClock.new(), buildings, paths)


func step() -> void:
	var tick := clock.tick
	behaviour.step(tick)
	contacts.step(tick)
	clock.advance()


## Frees the Node-based helpers a standalone run owns.
func free_standalone() -> void:
	rng.free()
	clock.free()
