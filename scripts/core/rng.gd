class_name SeededRng
extends Node
## The only source of randomness in the simulation.
## Never call randi(), randf(), Array.shuffle() or pick_random() anywhere else.

var _rng := RandomNumberGenerator.new()


func reseed(seed_value: int) -> void:
	_rng.seed = seed_value


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## True with probability p.
func chance(p: float) -> bool:
	return _rng.randf() < p


func pick(items: Array) -> Variant:
	assert(not items.is_empty(), "Rng.pick: empty array")
	return items[_rng.randi_range(0, items.size() - 1)]


## Fisher–Yates, in place.
func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


## Returns an index into weights, chosen in proportion to its weight.
func weighted_pick(weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	assert(total > 0.0, "Rng.weighted_pick: weights sum to 0")
	var r := _rng.randf() * total
	var last := -1
	for i in weights.size():
		if weights[i] <= 0.0:
			continue
		last = i
		r -= weights[i]
		if r < 0.0:
			return i
	return last
