extends Node
## Global data loader — reads all JSON data files and provides lookup functions.
## Autoloaded as "DataLoader".

var _creatures: Dictionary = {}
var _moves: Dictionary = {}
var _encounter_tables: Dictionary = {}


func _ready() -> void:
	_load_all_data()


func _load_all_data() -> void:
	_load_creatures("res://data/creatures/starters.json")
	_load_creatures("res://data/creatures/wild.json")
	_load_moves("res://data/moves/moves.json")
	_load_encounter_tables("res://data/maps/")

	print("[DataLoader] Loaded %d creatures, %d moves, %d encounter tables" % [
		_creatures.size(), _moves.size(), _encounter_tables.size()
	])


func _load_creatures(path: String) -> void:
	var data = _load_json(path)
	if data is Dictionary:
		_creatures.merge(data)


func _load_moves(path: String) -> void:
	var data = _load_json(path)
	if data is Dictionary:
		_moves.merge(data)


func _load_encounter_tables(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("Could not open directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var map_data = _load_json(dir_path + file_name)
			if map_data is Dictionary:
				var table_id := file_name.get_basename()
				_encounter_tables[table_id] = map_data.get("encounters", [])
		file_name = dir.get_next()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("JSON file not found: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var error := json.parse(file.get_as_text())

	if error != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}

	return json.data


# ─── Public API ──────────────────────────────────────────────────

func get_creature_data(creature_id: String) -> Dictionary:
	return _creatures.get(creature_id, {})


func get_move_data(move_id: String) -> Dictionary:
	return _moves.get(move_id, {})


func get_encounter_table(table_id: String) -> Array:
	return _encounter_tables.get(table_id, [])


func get_all_creature_ids() -> Array:
	return _creatures.keys()


func get_all_move_ids() -> Array:
	return _moves.keys()
