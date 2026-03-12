extends GutTest
## Unit tests for DataLoader — verifies all JSON data loads correctly.


func test_starters_loaded():
	for id in ["flame_squire", "tide_cleric", "grove_druid"]:
		var data := DataLoader.get_creature_data(id)
		assert_false(data.is_empty(), "Starter '%s' should be loaded" % id)


func test_wild_creatures_loaded():
	for id in ["spark_thief", "wind_scout", "stone_sentinel", "goblin", "hex_weaver"]:
		var data := DataLoader.get_creature_data(id)
		assert_false(data.is_empty(), "Wild creature '%s' should be loaded" % id)


func test_creature_has_required_fields():
	var required := ["name", "types", "base_hp", "base_attack", "base_defense",
		"base_sp_attack", "base_sp_defense", "base_speed", "base_exp", "learnset"]
	for id in DataLoader.get_all_creature_ids():
		var data := DataLoader.get_creature_data(id)
		for field in required:
			assert_true(data.has(field),
				"Creature '%s' missing required field '%s'" % [id, field])


func test_creature_types_are_arrays():
	for id in DataLoader.get_all_creature_ids():
		var data := DataLoader.get_creature_data(id)
		assert_true(data["types"] is Array,
			"Creature '%s' types should be an Array" % id)
		assert_gt(data["types"].size(), 0,
			"Creature '%s' should have at least one type" % id)


func test_creature_base_stats_positive():
	var stat_fields := ["base_hp", "base_attack", "base_defense",
		"base_sp_attack", "base_sp_defense", "base_speed"]
	for id in DataLoader.get_all_creature_ids():
		var data := DataLoader.get_creature_data(id)
		for field in stat_fields:
			assert_gt(data[field], 0,
				"Creature '%s' %s should be positive" % [id, field])


func test_moves_loaded():
	var move_ids := DataLoader.get_all_move_ids()
	assert_gt(move_ids.size(), 0, "Should have loaded at least one move")


func test_move_has_required_fields():
	var required := ["name", "type", "category", "power", "accuracy", "pp"]
	for id in DataLoader.get_all_move_ids():
		var data := DataLoader.get_move_data(id)
		for field in required:
			assert_true(data.has(field),
				"Move '%s' missing required field '%s'" % [id, field])


func test_move_categories_valid():
	var valid_categories := ["physical", "special", "status"]
	for id in DataLoader.get_all_move_ids():
		var data := DataLoader.get_move_data(id)
		assert_has(valid_categories, data["category"],
			"Move '%s' has invalid category '%s'" % [id, data["category"]])


func test_status_moves_have_zero_power():
	for id in DataLoader.get_all_move_ids():
		var data := DataLoader.get_move_data(id)
		if data["category"] == "status":
			assert_eq(data["power"], 0,
				"Status move '%s' should have 0 power" % id)


func test_encounter_table_loaded():
	var table := DataLoader.get_encounter_table("route_1")
	assert_gt(table.size(), 0, "Route 1 encounter table should have entries")


func test_encounter_table_weights_positive():
	var table := DataLoader.get_encounter_table("route_1")
	for entry in table:
		assert_gt(entry.get("weight", 0), 0,
			"Encounter weight should be positive for '%s'" % entry.get("creature_id", "?"))


func test_encounter_creatures_exist():
	var table := DataLoader.get_encounter_table("route_1")
	for entry in table:
		var creature_data := DataLoader.get_creature_data(entry["creature_id"])
		assert_false(creature_data.is_empty(),
			"Encounter creature '%s' should exist in creature data" % entry["creature_id"])


func test_encounter_level_ranges_valid():
	var table := DataLoader.get_encounter_table("route_1")
	for entry in table:
		assert_lte(entry["level_min"], entry["level_max"],
			"level_min should be <= level_max for '%s'" % entry["creature_id"])
		assert_gt(entry["level_min"], 0, "level_min should be positive")


func test_learnset_moves_exist():
	for creature_id in DataLoader.get_all_creature_ids():
		var data := DataLoader.get_creature_data(creature_id)
		for entry in data.get("learnset", []):
			var move_data := DataLoader.get_move_data(entry["move_id"])
			assert_false(move_data.is_empty(),
				"Learnset move '%s' for creature '%s' should exist" % [entry["move_id"], creature_id])


func test_get_invalid_creature_returns_empty():
	var data := DataLoader.get_creature_data("nonexistent_creature_xyz")
	assert_true(data.is_empty())


func test_get_invalid_move_returns_empty():
	var data := DataLoader.get_move_data("nonexistent_move_xyz")
	assert_true(data.is_empty())


func test_get_invalid_encounter_table_returns_empty():
	var table := DataLoader.get_encounter_table("nonexistent_table_xyz")
	assert_true(table.is_empty())
