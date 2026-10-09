extends Node
## Autoload: the loaded city, shared by every system.

var map: CityMap
var buildings: BuildingRegistry
var paths: Paths


func _ready() -> void:
	map = CityMap.load_default()
	buildings = BuildingRegistry.load_default()
	paths = Paths.build(map, buildings, Config)
