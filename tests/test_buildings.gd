extends BaseTest

const T := CityMap.TileType
const WORKER_SHARE := 0.65  # spec 05 occupation share


func test_every_building_tile_has_exactly_one_building() -> void:
	var map := CityMap.load_default()
	var reg := BuildingRegistry.load_default()
	var claimed := PackedInt32Array()
	claimed.resize(CityMap.SIZE * CityMap.SIZE)
	var overlap := false
	var off_building := false
	for b in reg.buildings:
		for y in range(b.rect.position.y, b.rect.end.y):
			for x in range(b.rect.position.x, b.rect.end.x):
				claimed[y * CityMap.SIZE + x] += 1
				if claimed[y * CityMap.SIZE + x] > 1:
					overlap = true
				if map.tile(x, y) != T.BUILDING:
					off_building = true
	check(not overlap, "building rects overlap")
	check(not off_building, "a building rect covers non-BUILDING tiles")
	var unowned := 0
	for y in CityMap.SIZE:
		for x in CityMap.SIZE:
			if map.tile(x, y) == T.BUILDING and reg.at_tile(x, y) == -1:
				unowned += 1
	check(unowned == 0, "%d BUILDING tiles belong to no building" % unowned)


func test_entrances_touch_sidewalk() -> void:
	var map := CityMap.load_default()
	var reg := BuildingRegistry.load_default()
	var bad: Array[int] = []
	for b in reg.buildings:
		var inside := b.rect.has_point(b.entrance)
		var touches := false
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q := b.entrance + d
			if map.tile(q.x, q.y) == T.SIDEWALK:
				touches = true
		if not inside or not touches:
			bad.append(b.id)
	check(bad.is_empty(), "bad entrances on buildings %s" % [bad.slice(0, 10)])


func test_two_large_malls_on_different_islands() -> void:
	var reg := BuildingRegistry.load_default()
	var malls := reg.with_purpose("mall")
	check(malls.size() == 2, "expected 2 malls, got %d" % malls.size())
	if malls.size() == 2:
		check(malls[0].island != malls[1].island, "both malls are on island %d" % malls[0].island)
	for m in malls:
		check(m.rect.size.x >= 10 and m.rect.size.y >= 10, "mall %d is only %s" % [m.id, m.rect.size])


func test_purposes_and_slots_are_consistent() -> void:
	var reg := BuildingRegistry.load_default()
	for b in reg.buildings:
		for p in b.purposes:
			check(Building.PURPOSES.has(p), "building %d has unknown purpose '%s'" % [b.id, p])
		check((b.home_capacity > 0) == b.has_purpose("home"), "building %d: home_capacity doesn't match purpose" % b.id)
		var works := false
		for p in Building.WORK_PURPOSES:
			works = works or b.has_purpose(p)
		check((b.jobs > 0) == works, "building %d: jobs doesn't match purpose" % b.id)


func test_city_mix_and_capacity() -> void:
	var reg := BuildingRegistry.load_default()
	var population := ConfigStore.new()
	var pop := population.get_int("population")
	population.free()
	var homes := 0
	var jobs := 0
	for b in reg.buildings:
		homes += b.home_capacity
		jobs += b.jobs
	check(homes >= 1.2 * pop, "home capacity %d < 1.2 x %d" % [homes, pop])
	check(jobs >= WORKER_SHARE * pop, "jobs %d < workers %d" % [jobs, int(WORKER_SHARE * pop)])
	check(reg.with_purpose("school").size() == 3, "expected 3 schools")
	check(reg.with_purpose("nightclub").size() >= 5, "too few nightclubs")
	check(reg.with_purpose("restaurant").size() >= 12, "too few restaurants")
	var mixed := 0
	for b in reg.buildings:
		if b.purposes.size() > 1:
			mixed += 1
	check(mixed > 0, "no mixed-purpose buildings")


func test_at_tile_and_closed_flag() -> void:
	var reg := BuildingRegistry.load_default()
	var b := reg.by_id(0)
	check(reg.at_tile(b.rect.position.x, b.rect.position.y) == 0, "at_tile of building 0's corner isn't 0")
	check(reg.at_tile(0, 0) == -1, "water tile has a building")
	check(not reg.is_closed(0), "buildings should start open")
	reg.set_closed(0, true)
	check(reg.is_closed(0), "set_closed didn't close the building")
