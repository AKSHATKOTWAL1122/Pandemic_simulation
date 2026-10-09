class_name RunExporter
extends RefCounted
## Spec 14: writes one run to output/<experiment>/run_<i>/ — config.json, seir.csv, contacts.csv,
## infections.csv (streamed, flushed every game hour) and npcs.csv (at the end).

const SEIR_HEADER := "tick,day,hour,S,E,I,R,immune_forever"
const CONTACTS_HEADER := "tick,a,b,x,y,building_id,in_car"
const INFECTIONS_HEADER := "tick,infector,infected,x,y,building_id,in_car"
const NPCS_HEADER := "id,household_id,home_id,occupation,work_id,school_id,has_car,immune_forever,contact_count,first_infected_tick"

var dir: String
var _sim: Simulation
var _seir: FileAccess
var _contacts: FileAccess
var _infections: FileAccess
var _seir_rows := PackedStringArray()
var _contact_rows := PackedStringArray()
var _infection_rows := PackedStringArray()
var _ticks_per_hour: int
var _tick_seconds: int


## dir_path may be res:// or absolute. `extra` is merged into config.json.
func open(dir_path: String, sim: Simulation, extra: Dictionary) -> Error:
	dir = ProjectSettings.globalize_path(dir_path)
	_sim = sim
	_tick_seconds = sim.clock.tick_seconds
	_ticks_per_hour = maxi(1, roundi(3600.0 / _tick_seconds))
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		push_error("RunExporter: cannot create %s" % dir)
		return err
	var config := {
		"seed": sim.config.get_int("seed"),
		"tick_seconds": _tick_seconds,
		"days": sim.config.get_value("days"),
		"population": sim.population.count(),
		"virus": sim.config.get_value("virus"),
		"map_path": "data/map.png",
		"buildings_path": "data/buildings.json",
	}
	config.merge(extra, true)
	var config_file := FileAccess.open(dir.path_join("config.json"), FileAccess.WRITE)
	config_file.store_string(JSON.stringify(config, "  ", true) + "\n")
	config_file.close()
	_seir = _open_csv("seir.csv", SEIR_HEADER)
	_contacts = _open_csv("contacts.csv", CONTACTS_HEADER)
	_infections = _open_csv("infections.csv", INFECTIONS_HEADER)
	sim.listeners.append(_on_tick)
	return OK


func _open_csv(file_name: String, header: String) -> FileAccess:
	var file := FileAccess.open(dir.path_join(file_name), FileAccess.WRITE)
	file.store_string(header + "\n")
	return file


func _on_tick(tick: int, contact_events: Array, infection_events: Array) -> void:
	var c := _sim.epidemic.counts
	var seconds := tick * _tick_seconds
	@warning_ignore("integer_division")
	_seir_rows.append("%d,%d,%d,%d,%d,%d,%d,%d" % [
		tick, seconds / 86400, (seconds % 86400) / 3600, c[0], c[1], c[2], c[3], _sim.epidemic.immune_forever_count])
	for e: Dictionary in contact_events:
		_contact_rows.append("%d,%d,%d,%.3f,%.3f,%d,%d" % [
			e["tick"], e["a"], e["b"], e["x"], e["y"], e["building_id"], 1 if e["in_car"] else 0])
	for e: Dictionary in infection_events:
		_infection_rows.append("%d,%d,%d,%.3f,%.3f,%d,%d" % [
			e["tick"], e["infector"], e["infected"], e["x"], e["y"], e["building_id"], 1 if e["in_car"] else 0])
	if (tick + 1) % _ticks_per_hour == 0:
		flush()


func flush() -> void:
	_write(_seir, _seir_rows)
	_write(_contacts, _contact_rows)
	_write(_infections, _infection_rows)


static func _write(file: FileAccess, rows: PackedStringArray) -> void:
	if rows.is_empty():
		return
	file.store_string("\n".join(rows) + "\n")
	file.flush()
	rows.clear()


## Writes npcs.csv and closes everything. Call once, after the last tick.
func finish() -> void:
	flush()
	for file in [_seir, _contacts, _infections]:
		(file as FileAccess).close()
	_sim.listeners.erase(_on_tick)
	var npcs := _open_csv("npcs.csv", NPCS_HEADER)
	var rows := PackedStringArray()
	for npc in _sim.population.npcs:
		var household := _sim.population.households[npc.household_id]
		rows.append("%d,%d,%d,%s,%d,%d,%d,%d,%d,%d" % [
			npc.id, npc.household_id, npc.home_id, npc.occupation_name(), npc.work_id, npc.school_id,
			1 if household.has_car else 0, 1 if npc.immune_forever else 0, npc.contact_count, npc.first_infected_tick])
	npcs.store_string("\n".join(rows) + "\n")
	npcs.close()
