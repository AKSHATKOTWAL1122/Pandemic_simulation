class_name Experiment
extends RefCounted
## Spec 13: one experiment file (experiments/<name>.json) — a setup to run `runs` times with seeds
## base_seed + i. Missing keys fall back to config/default.json.

const OVERRIDABLE: Array[String] = ["days", "population", "tick_seconds"]

var path: String
var name: String
var base_seed: int
var runs: int
var data: Dictionary


## Returns null and pushes an error if the file can't be read.
static func load_file(file_path: String) -> Experiment:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Experiment: cannot read %s" % file_path)
		return null
	return from_dict(parsed, file_path)


static func from_dict(values: Dictionary, file_path: String = "") -> Experiment:
	var e := Experiment.new()
	e.path = file_path
	e.data = values
	e.name = str(values.get("name", file_path.get_file().get_basename()))
	e.base_seed = int(values.get("base_seed", 1000))
	e.runs = int(values.get("runs", 1))
	return e


## Empty string if valid, otherwise what's wrong.
func validate(buildings: BuildingRegistry) -> String:
	var closed := closed_ids(buildings)
	for id in closed:
		if id < 0 or id >= buildings.count():
			return "closed_buildings: no building %d" % id
		if buildings.by_id(id).has_purpose("home"):
			return "closed_buildings: building %d is a home; homes can't be closed" % id
	for purpose: String in data.get("closed_buildings", {}).get("purposes", []):
		if purpose == "home":
			return "closed_buildings: homes can't be closed"
		if not Building.PURPOSES.has(purpose):
			return "closed_buildings: unknown purpose '%s'" % purpose
	var mode := str(data.get("patient_zero", {}).get("mode", "random"))
	if not ["ids", "random", "top_contacts"].has(mode):
		return "patient_zero.mode must be ids, random or top_contacts, not '%s'" % mode
	var share := float(data.get("immune_share", 0.0))
	if share < 0.0 or share > 1.0:
		return "immune_share must be between 0 and 1"
	return ""


## The config for run i: defaults, then this file's overrides, then seed = base_seed + i.
func make_config(run_index: int) -> ConfigStore:
	var config := ConfigStore.new()
	for key in OVERRIDABLE:
		if data.has(key):
			config.set_value(key, data[key])
	if data.has("virus"):
		config.set_value("virus", data["virus"])
	config.set_value("seed", base_seed + run_index)
	return config


## Ids of every building closed by `ids` or `purposes`, sorted.
func closed_ids(buildings: BuildingRegistry) -> Array[int]:
	var spec: Dictionary = data.get("closed_buildings", {})
	var ids: Array[int] = []
	for id: Variant in spec.get("ids", []):
		if not ids.has(int(id)):
			ids.append(int(id))
	for purpose: String in spec.get("purposes", []):
		for b in buildings.with_purpose(purpose):
			if not ids.has(b.id):
				ids.append(b.id)
	ids.sort()
	return ids


## Seeded setup after the population exists (spec 13 order): closures, immune share, patient zero.
## Returns {"immune": [...ids], "patient_zero": [...ids], "closed": [...ids]}.
func apply(sim: Simulation) -> Dictionary:
	var closed := closed_ids(sim.buildings)
	for id in closed:
		sim.buildings.set_closed(id, true)

	var ids: Array = range(sim.population.count())
	sim.rng.shuffle(ids)
	var immune_count := roundi(float(data.get("immune_share", 0.0)) * sim.population.count())
	var immune: Array[int] = []
	for k in immune_count:
		var npc: NPC = sim.population.npcs[ids[k]]
		npc.immune_forever = true
		npc.health = NPC.Health.R
		immune.append(npc.id)
	immune.sort()
	sim.epidemic.recount()

	var zeros := _patient_zero_ids(sim)
	for id in zeros:
		sim.infect(id)
	return {"immune": immune, "patient_zero": zeros, "closed": closed}


func _patient_zero_ids(sim: Simulation) -> Array[int]:
	var spec: Dictionary = data.get("patient_zero", {"mode": "random", "count": 1})
	var mode := str(spec.get("mode", "random"))
	var count := int(spec.get("count", 1))
	var result: Array[int] = []
	match mode:
		"ids":
			for id: Variant in spec.get("ids", []):
				result.append(int(id))
		"random":
			var candidates: Array = []
			for npc in sim.population.npcs:
				if not npc.immune_forever:
					candidates.append(npc.id)
			sim.rng.shuffle(candidates)
			for k in mini(count, candidates.size()):
				result.append(candidates[k])
		"top_contacts":
			result = _top_contacts(sim, str(spec.get("from_run", "")), count)
	result.sort()
	return result


## The `count` non-immune NPCs with the most contacts in a previous run's npcs.csv.
static func _top_contacts(sim: Simulation, npcs_csv: String, count: int) -> Array[int]:
	var file := FileAccess.open(npcs_csv, FileAccess.READ)
	if file == null:
		push_error("Experiment: cannot read %s for top_contacts" % npcs_csv)
		return []
	var header := file.get_csv_line()
	var id_col := header.find("id")
	var contacts_col := header.find("contact_count")
	var rows: Array[Vector2i] = []  # (contact_count, id)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size():
			continue
		rows.append(Vector2i(int(row[contacts_col]), int(row[id_col])))
	rows.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y))
	var result: Array[int] = []
	for r in rows:
		if result.size() >= count:
			break
		if r.y < sim.population.count() and not sim.population.npcs[r.y].immune_forever:
			result.append(r.y)
	return result


## Number of ticks in a run of this config.
static func total_ticks(config: ConfigStore) -> int:
	return roundi(config.get_float("days") * 86400.0 / config.get_float("tick_seconds"))


## Extra keys for config.json (spec 14) describing this run's setup.
func describe(run_index: int, applied: Dictionary) -> Dictionary:
	return {
		"name": name,
		"experiment_file": path,
		"run": run_index,
		"base_seed": base_seed,
		"immune_share": float(data.get("immune_share", 0.0)),
		"immune_count": (applied["immune"] as Array).size(),
		"patient_zero": data.get("patient_zero", {"mode": "random", "count": 1}),
		"patient_zero_ids": applied["patient_zero"],
		"closed_buildings": data.get("closed_buildings", {}),
		"closed_building_ids": applied["closed"],
	}


## Runs run_index start to finish without the scene, writing to <out_root>/<name>/run_<i>.
## Returns the run folder. Used by tests; the scene's BatchRunner does the same in the window.
func run_standalone(run_index: int, out_root: String) -> String:
	var config := make_config(run_index)
	var sim := Simulation.standalone(config)
	var applied := apply(sim)
	var exporter := RunExporter.new()
	var dir := out_root.path_join(name).path_join("run_%d" % run_index)
	exporter.open(dir, sim, describe(run_index, applied))
	for t in total_ticks(config):
		sim.step()
	exporter.finish()
	sim.free_standalone()
	config.free()
	return exporter.dir
