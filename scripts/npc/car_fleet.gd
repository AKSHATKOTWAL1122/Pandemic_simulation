class_name CarFleet
extends RefCounted
## Spec 09: one car per car-owning household, parked at the road nearest its home.

var cars: Array[Car] = []
var _by_household: Dictionary = {}  # household id -> car id


static func create(population: Population, buildings: BuildingRegistry, paths: Paths) -> CarFleet:
	var fleet := CarFleet.new()
	for household_id in population.households_with_car():
		var car := Car.new()
		car.id = fleet.cars.size()
		car.household_id = household_id
		var home := buildings.by_id(population.households[household_id].home_id)
		car.tile = paths.nearest_road(home.entrance)
		fleet._by_household[household_id] = car.id
		fleet.cars.append(car)
	return fleet


## The household's car, or null.
func of_household(household_id: int) -> Car:
	if not _by_household.has(household_id):
		return null
	return cars[_by_household[household_id]]
