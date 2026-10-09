extends Node
## Autoload: the loaded city, shared by every system.

var map: CityMap
var buildings: BuildingRegistry


func _init() -> void:
	map = CityMap.load_default()
	buildings = BuildingRegistry.load_default()
