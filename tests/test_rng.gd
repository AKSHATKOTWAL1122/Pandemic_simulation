extends BaseTest


func test_same_seed_gives_same_values() -> void:
	var a := SeededRng.new()
	var b := SeededRng.new()
	a.reseed(42)
	b.reseed(42)
	var same := true
	for i in 1000:
		if a.randf() != b.randf():
			same = false
			break
	check(same, "same seed produced different values")
	a.free()
	b.free()


func test_different_seed_gives_different_values() -> void:
	var a := SeededRng.new()
	var b := SeededRng.new()
	a.reseed(42)
	b.reseed(43)
	var differences := 0
	for i in 1000:
		if a.randf() != b.randf():
			differences += 1
	check(differences > 990, "different seeds produced mostly equal values (%d differ)" % differences)
	a.free()
	b.free()


func test_shuffle_is_repeatable() -> void:
	var a := SeededRng.new()
	var b := SeededRng.new()
	a.reseed(7)
	b.reseed(7)
	var x: Array = range(100)
	var y: Array = range(100)
	a.shuffle(x)
	b.shuffle(y)
	check(x == y, "shuffle with the same seed gave different orders")
	check(x != range(100), "shuffle left the array unchanged")
	var sorted_x := x.duplicate()
	sorted_x.sort()
	check(sorted_x == range(100), "shuffle lost or duplicated elements")
	a.free()
	b.free()


func test_weighted_pick_skips_zero_weights() -> void:
	var r := SeededRng.new()
	r.reseed(1)
	var ok := true
	for i in 200:
		if r.weighted_pick([0.0, 1.0, 0.0]) != 1:
			ok = false
	check(ok, "weighted_pick chose an index with weight 0")
	r.free()
