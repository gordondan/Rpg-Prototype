extends GutTest
## Integration test: Encounter trigger flow — tests the encounter system's data flow.
## Verifies encounter table loading, weighted random selection, creature instantiation,
## and level range enforcement.
##
## Mirrors the weighted selection logic from GrassArea._weighted_random_select()
## and BattleManager._roll_encounter() without requiring scene tree operations.


func before_each():
	TestHelpers.reset_game_manager()


# --- Helper: mirror GrassArea._weighted_random_select() ---

func _weighted_random_select(table: Array) -> Dictionary:
	var total_weight := 0.0
	for entry in table:
		total_weight += entry.get("weight", 1.0)
	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in table:
		cumulative += entry.get("weight", 1.0)
		if roll <= cumulative:
			return entry
	return table[-1]


# ---------------------------------------------------------------------------
# Test: DataLoader loads encounter table for route_1
# ---------------------------------------------------------------------------
func test_encounter_table_loads():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty(), "route_1 encounter table should be loaded")
	assert_gt(table.size(), 0, "Should have at least one encounter entry")


# ---------------------------------------------------------------------------
# Test: Each encounter entry has required fields
# ---------------------------------------------------------------------------
func test_encounter_entries_have_required_fields():
	var table: Array = DataLoader.get_encounter_table("route_1")
	for entry in table:
		assert_true(entry.has("creature_id"),
			"Entry should have creature_id: %s" % str(entry))
		assert_true(entry.has("level_min"),
			"Entry should have level_min: %s" % str(entry))
		assert_true(entry.has("level_max"),
			"Entry should have level_max: %s" % str(entry))
		assert_true(entry.has("weight"),
			"Entry should have weight: %s" % str(entry))
		assert_true(int(entry["level_min"]) <= int(entry["level_max"]),
			"level_min should be <= level_max for %s" % entry["creature_id"])


# ---------------------------------------------------------------------------
# Test: Weighted distribution roughly matches expected weights over 1000 runs
# ---------------------------------------------------------------------------
func test_weighted_distribution_matches_expected():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty(), "Need encounter table for distribution test")

	# Calculate total weight
	var total_weight := 0.0
	for entry in table:
		total_weight += float(entry.get("weight", 1.0))

	# Run 1000 selections
	var counts: Dictionary = {}
	for entry in table:
		counts[entry["creature_id"]] = 0

	var iterations := 1000
	for _i in range(iterations):
		var selected := _weighted_random_select(table)
		counts[selected["creature_id"]] += 1

	# Verify each creature's selection rate is within reasonable bounds
	# Allow +/- 5 percentage points from expected proportion
	for entry in table:
		var creature_id: String = entry["creature_id"]
		var expected_pct: float = float(entry["weight"]) / total_weight
		var actual_pct: float = float(counts[creature_id]) / float(iterations)
		var tolerance := 0.05  # 5 percentage points

		assert_almost_eq(actual_pct, expected_pct, tolerance,
			"%s: expected ~%.1f%% got %.1f%% (count=%d)" % [
				creature_id,
				expected_pct * 100.0,
				actual_pct * 100.0,
				counts[creature_id],
			])


# ---------------------------------------------------------------------------
# Test: Highest weight creature appears most often
# ---------------------------------------------------------------------------
func test_highest_weight_appears_most():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty())

	# Find the highest-weight entry
	var max_weight := 0.0
	var max_id := ""
	for entry in table:
		if float(entry.get("weight", 1.0)) > max_weight:
			max_weight = float(entry.get("weight", 1.0))
			max_id = entry["creature_id"]

	# Run selections
	var counts: Dictionary = {}
	for entry in table:
		counts[entry["creature_id"]] = 0

	for _i in range(1000):
		var selected := _weighted_random_select(table)
		counts[selected["creature_id"]] += 1

	# The highest-weight creature should have the most selections
	var max_count := 0
	var most_selected_id := ""
	for cid in counts:
		if counts[cid] > max_count:
			max_count = counts[cid]
			most_selected_id = cid

	assert_eq(most_selected_id, max_id,
		"Creature with highest weight (%s, weight=%s) should appear most often" % [max_id, str(max_weight)])


# ---------------------------------------------------------------------------
# Test: Lowest weight creature still appears (non-zero probability)
# ---------------------------------------------------------------------------
func test_lowest_weight_still_appears():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty())

	# Find the lowest-weight entry
	var min_weight := INF
	var min_id := ""
	for entry in table:
		if float(entry.get("weight", 1.0)) < min_weight:
			min_weight = float(entry.get("weight", 1.0))
			min_id = entry["creature_id"]

	# Over 1000 runs, even 5% weight should appear at least once
	var appeared := false
	for _i in range(1000):
		var selected := _weighted_random_select(table)
		if selected["creature_id"] == min_id:
			appeared = true
			break

	assert_true(appeared,
		"Lowest weight creature (%s) should appear at least once in 1000 runs" % min_id)


# ---------------------------------------------------------------------------
# Test: All selected creatures can be instantiated with valid stats
# ---------------------------------------------------------------------------
func test_selected_creatures_instantiate_with_valid_stats():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty())

	for entry in table:
		var creature_id: String = entry["creature_id"]
		var level_min: int = int(entry.get("level_min", 2))
		var level_max: int = int(entry.get("level_max", 5))

		# Test instantiation at both min and max level
		for test_level in [level_min, level_max]:
			var creature := CreatureInstance.create(creature_id, test_level)

			assert_ne(creature, null,
				"%s should instantiate at level %d" % [creature_id, test_level])
			assert_eq(creature.creature_id, creature_id,
				"creature_id should match")
			assert_eq(creature.level, test_level,
				"Level should match requested level")
			assert_gt(creature.max_hp, 0,
				"%s max_hp should be positive at level %d" % [creature_id, test_level])
			assert_gt(creature.attack, 0,
				"%s attack should be positive" % creature_id)
			assert_gt(creature.defense, 0,
				"%s defense should be positive" % creature_id)
			assert_gt(creature.speed, 0,
				"%s speed should be positive" % creature_id)
			assert_eq(creature.current_hp, creature.max_hp,
				"%s should start at full HP" % creature_id)
			assert_false(creature.types.is_empty(),
				"%s should have at least one type" % creature_id)


# ---------------------------------------------------------------------------
# Test: Instantiated creatures have valid moves
# ---------------------------------------------------------------------------
func test_selected_creatures_have_valid_moves():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty())

	for entry in table:
		var creature_id: String = entry["creature_id"]
		var level: int = int(entry.get("level_max", 5))

		var creature := CreatureInstance.create(creature_id, level)
		assert_gt(creature.moves.size(), 0,
			"%s at level %d should know at least one move" % [creature_id, level])

		for move in creature.moves:
			assert_true(move.has("id"), "Move should have an id field")
			assert_true(move.has("current_pp"), "Move should have current_pp")
			assert_true(move.has("max_pp"), "Move should have max_pp")
			assert_gt(move["max_pp"], 0, "Move PP should be positive")
			assert_eq(move["current_pp"], move["max_pp"],
				"Fresh creature should have full PP")

			# Verify the move exists in DataLoader
			var move_data := DataLoader.get_move_data(move["id"])
			assert_false(move_data.is_empty(),
				"Move '%s' should exist in DataLoader" % move["id"])


# ---------------------------------------------------------------------------
# Test: Level ranges are respected in BattleManager._roll_encounter style
# ---------------------------------------------------------------------------
func test_level_ranges_respected():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty())

	# Simulate rolling encounters the same way BattleManager does
	for _i in range(200):
		var entry := _weighted_random_select(table)
		var level_min: int = int(entry.get("level_min", 2))
		var level_max: int = int(entry.get("level_max", 5))
		var level := randi_range(level_min, level_max)

		assert_gte(level, level_min,
			"Rolled level should be >= level_min (%d)" % level_min)
		assert_lte(level, level_max,
			"Rolled level should be <= level_max (%d)" % level_max)

		# Actually create the creature at that level and verify
		var creature := CreatureInstance.create(entry["creature_id"], level)
		assert_eq(creature.level, level,
			"Creature level should match rolled level")


# ---------------------------------------------------------------------------
# Test: Encounter table weights sum correctly
# ---------------------------------------------------------------------------
func test_encounter_weights_sum():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty())

	var total := 0.0
	for entry in table:
		var weight: float = float(entry.get("weight", 1.0))
		assert_gt(weight, 0.0, "Weight should be positive for %s" % entry["creature_id"])
		total += weight

	# route_1 weights: 35 + 25 + 20 + 15 + 5 = 100
	assert_eq(total, 100.0,
		"route_1 weights should sum to 100")


# ---------------------------------------------------------------------------
# Test: Invalid encounter table returns empty
# ---------------------------------------------------------------------------
func test_invalid_encounter_table_returns_empty():
	var table: Array = DataLoader.get_encounter_table("nonexistent_area_xyz")
	assert_true(table.is_empty(),
		"Non-existent encounter table should return empty array")


# ---------------------------------------------------------------------------
# Test: All creature IDs in encounter table exist in DataLoader
# ---------------------------------------------------------------------------
func test_all_encounter_creature_ids_exist():
	var table: Array = DataLoader.get_encounter_table("route_1")
	assert_false(table.is_empty())

	for entry in table:
		var creature_id: String = entry["creature_id"]
		var data := DataLoader.get_creature_data(creature_id)
		assert_false(data.is_empty(),
			"Creature '%s' from encounter table should exist in DataLoader" % creature_id)
