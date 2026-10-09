extends BaseTest

const OUT := "user://test_runs"


static func _experiment(values: Dictionary) -> Experiment:
	var base := {"name": "t", "base_seed": 77, "runs": 1, "days": 0.25,
		"patient_zero": {"mode": "random", "count": 5}}
	base.merge(values, true)
	return Experiment.from_dict(base)


static func _lines(path: String) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(path)
	return text.strip_edges().split("\n")


func test_same_seed_gives_byte_identical_files() -> void:
	var e := _experiment({"name": "same_a"})
	var a := e.run_standalone(0, OUT)
	e.name = "same_b"
	var b := e.run_standalone(0, OUT)
	for f in ["seir.csv", "contacts.csv", "infections.csv", "npcs.csv"]:
		var ta := FileAccess.get_file_as_string(a.path_join(f))
		var tb := FileAccess.get_file_as_string(b.path_join(f))
		check(ta != "" and ta == tb, "%s differs between two runs with the same seed" % f)


func test_different_seed_gives_different_run() -> void:
	var e := _experiment({"name": "seed_diff", "runs": 2})
	var a := e.run_standalone(0, OUT)
	var b := e.run_standalone(1, OUT)
	check(FileAccess.get_file_as_string(a.path_join("contacts.csv")) != FileAccess.get_file_as_string(b.path_join("contacts.csv")),
		"runs 0 and 1 (different seeds) produced identical contacts")


func test_immune_share_and_patient_zero_not_immune() -> void:
	var e := _experiment({"immune_share": 0.2, "patient_zero": {"mode": "random", "count": 10}})
	var config := e.make_config(0)
	var sim := Simulation.standalone(config)
	var applied := e.apply(sim)
	var immune := 0
	for npc in sim.population.npcs:
		if npc.immune_forever:
			immune += 1
	check(immune == 200, "immune_share 0.2 gave %d immune, expected 200" % immune)
	check((applied["patient_zero"] as Array).size() == 10, "expected 10 patient zeros")
	for id: int in applied["patient_zero"]:
		check(not sim.population.npcs[id].immune_forever, "patient zero %d is immune" % id)
		check(sim.population.npcs[id].health == NPC.Health.I, "patient zero %d isn't infected" % id)
	check(sim.epidemic.counts[NPC.Health.R] == 200 and sim.epidemic.immune_forever_count == 200, "counts don't show 200 immune in R")
	sim.free_standalone()
	config.free()


func test_closing_homes_is_rejected() -> void:
	var buildings := BuildingRegistry.load_default()
	var by_purpose := _experiment({"closed_buildings": {"purposes": ["home"]}})
	check(by_purpose.validate(buildings) != "", "closing purpose 'home' was accepted")
	var home := buildings.with_purpose("home")[0]
	var by_id := _experiment({"closed_buildings": {"ids": [home.id]}})
	check(by_id.validate(buildings) != "", "closing home building %d by id was accepted" % home.id)
	var malls := _experiment({"closed_buildings": {"purposes": ["mall"]}})
	check(malls.validate(buildings) == "", "closing malls was rejected: %s" % malls.validate(buildings))
	check(malls.closed_ids(buildings).size() == 2, "malls_closed should close 2 buildings")
	check(_experiment({"patient_zero": {"mode": "nope"}}).validate(buildings) != "", "bad patient_zero mode accepted")


func test_example_files_are_valid() -> void:
	var buildings := BuildingRegistry.load_default()
	for f in DirAccess.get_files_at("res://experiments"):
		if not f.ends_with(".json"):
			continue
		var e := Experiment.load_file("res://experiments/" + f)
		check(e != null, "%s doesn't load" % f)
		if e != null:
			check(e.validate(buildings) == "", "%s: %s" % [f, e.validate(buildings)])
			check(e.name == f.get_basename(), "%s: name '%s' should match the file name" % [f, e.name])


func test_malls_closed_two_runs_write_two_folders() -> void:
	var e := Experiment.load_file("res://experiments/malls_closed.json")
	e.data["days"] = 0.05
	e.name = "malls_closed_test"
	for i in 2:
		e.run_standalone(i, OUT)
	for i in 2:
		var dir := ProjectSettings.globalize_path(OUT).path_join("malls_closed_test/run_%d" % i)
		check(FileAccess.file_exists(dir.path_join("seir.csv")), "run_%d has no seir.csv" % i)
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("config.json")))
		check((config["closed_building_ids"] as Array).size() == 2, "run_%d config doesn't list 2 closed malls" % i)
		check(int(config["seed"]) == 1000 + i, "run_%d seed is %s" % [i, config["seed"]])


func test_top_contacts_picks_the_most_connected() -> void:
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	var csv := dir.path_join("fake_npcs.csv")
	var f := FileAccess.open(csv, FileAccess.WRITE)
	f.store_string("id,household_id,home_id,occupation,work_id,school_id,has_car,immune_forever,contact_count,first_infected_tick\n")
	f.store_string("0,0,0,NONE,-1,-1,0,0,5,-1\n1,0,0,NONE,-1,-1,0,0,900,-1\n2,0,0,NONE,-1,-1,0,0,40,-1\n3,0,0,NONE,-1,-1,0,0,900,-1\n")
	f.close()
	var e := _experiment({"patient_zero": {"mode": "top_contacts", "count": 2, "from_run": csv}})
	var config := e.make_config(0)
	var sim := Simulation.standalone(config)
	var applied := e.apply(sim)
	check(applied["patient_zero"] == [1, 3], "top_contacts picked %s, expected [1, 3]" % [applied["patient_zero"]])
	sim.free_standalone()
	config.free()


# --- Spec 14: export format ---------------------------------------------------

func test_one_day_export_files_and_row_counts() -> void:
	var e := _experiment({"name": "export_day", "days": 1})
	var dir := e.run_standalone(0, OUT)
	var headers := {
		"seir.csv": RunExporter.SEIR_HEADER, "contacts.csv": RunExporter.CONTACTS_HEADER,
		"infections.csv": RunExporter.INFECTIONS_HEADER, "npcs.csv": RunExporter.NPCS_HEADER,
	}
	for f: String in headers:
		var lines := _lines(dir.path_join(f))
		check(lines[0] == headers[f], "%s header is '%s'" % [f, lines[0]])
	check(FileAccess.file_exists(dir.path_join("config.json")), "config.json missing")
	var seir := _lines(dir.path_join("seir.csv"))
	check(seir.size() - 1 == 1440, "seir.csv has %d rows, expected 1440 ticks" % (seir.size() - 1))
	var population := 0
	var first_infected := 0
	var npcs := _lines(dir.path_join("npcs.csv"))
	population = npcs.size() - 1
	for k in range(1, npcs.size()):
		if int(npcs[k].split(",")[9]) >= 0:
			first_infected += 1
	check(population == 1000, "npcs.csv has %d rows" % population)
	var infections := _lines(dir.path_join("infections.csv"))
	var zero_rows := 0
	for k in range(1, infections.size()):
		if int(infections[k].split(",")[1]) == -1:
			zero_rows += 1
	check(zero_rows == 5, "expected 5 patient-zero rows, got %d" % zero_rows)
	# No reinfection is possible within a day (immunity needs 3 + 5 days), so rows == NPCs ever infected.
	check(infections.size() - 1 == first_infected, "infections.csv has %d rows but %d NPCs were infected" % [infections.size() - 1, first_infected])
	var last := seir[seir.size() - 1].split(",")
	var total := int(last[3]) + int(last[4]) + int(last[5]) + int(last[6])
	check(total == 1000, "last seir row adds up to %d" % total)
	check(int(seir[1].split(",")[5]) == 5, "first seir row should show the 5 patient zeros as I")
