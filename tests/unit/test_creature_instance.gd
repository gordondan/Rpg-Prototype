extends GutTest
## Unit tests for CreatureInstance — stat calculation, moves, damage, healing.


func test_create_level_5_stats():
	var c := CreatureInstance.create("flame_squire", 5)
	assert_eq(c.creature_id, "flame_squire")
	assert_eq(c.level, 5)
	assert_eq(c.max_hp, 20, "HP at level 5")
	assert_eq(c.attack, 11, "Attack at level 5")
	assert_eq(c.defense, 10, "Defense at level 5")
	assert_eq(c.sp_attack, 12, "Sp.Attack at level 5")
	assert_eq(c.sp_defense, 11, "Sp.Defense at level 5")
	assert_eq(c.speed, 13, "Speed at level 5")
	assert_eq(c.current_hp, c.max_hp, "Should start at full HP")


func test_create_level_50_stats():
	var c := CreatureInstance.create("flame_squire", 50)
	assert_eq(c.max_hp, 119, "HP at level 50")
	assert_eq(c.attack, 72, "Attack at level 50")


func test_types_loaded():
	var c := CreatureInstance.create("flame_squire", 5)
	assert_eq(c.types.size(), 1)
	assert_eq(c.types[0], "fire")


func test_dual_types():
	var c := CreatureInstance.create("wind_scout", 5)
	assert_eq(c.types.size(), 2)
	assert_has(c.types, "normal")
	assert_has(c.types, "flying")


func test_moves_at_level_5():
	var c := CreatureInstance.create("flame_squire", 5)
	assert_eq(c.moves.size(), 2, "Should learn 2 moves by level 5")
	assert_eq(c.moves[0]["id"], "sword_strike")
	assert_eq(c.moves[1]["id"], "war_cry")


func test_moves_at_level_10():
	var c := CreatureInstance.create("flame_squire", 10)
	assert_eq(c.moves.size(), 4, "Should learn 4 moves by level 10")
	assert_eq(c.moves[0]["id"], "sword_strike")
	assert_eq(c.moves[1]["id"], "war_cry")
	assert_eq(c.moves[2]["id"], "fire_bolt")
	assert_eq(c.moves[3]["id"], "smoke_bomb")


func test_moves_capped_at_4():
	var c := CreatureInstance.create("flame_squire", 50)
	assert_eq(c.moves.size(), 4, "Should cap at 4 moves")
	assert_eq(c.moves[0]["id"], "smoke_bomb")
	assert_eq(c.moves[1]["id"], "blazing_blade")
	assert_eq(c.moves[2]["id"], "cross_slash")
	assert_eq(c.moves[3]["id"], "inferno")


func test_take_damage():
	var c := TestHelpers.make_creature({"max_hp": 50, "current_hp": 50})
	c.take_damage(20)
	assert_eq(c.current_hp, 30)


func test_take_damage_clamps_to_zero():
	var c := TestHelpers.make_creature({"max_hp": 50, "current_hp": 10})
	c.take_damage(999)
	assert_eq(c.current_hp, 0)


func test_heal():
	var c := TestHelpers.make_creature({"max_hp": 50, "current_hp": 20})
	c.heal(15)
	assert_eq(c.current_hp, 35)


func test_heal_clamps_to_max():
	var c := TestHelpers.make_creature({"max_hp": 50, "current_hp": 40})
	c.heal(999)
	assert_eq(c.current_hp, 50)


func test_is_fainted_at_zero_hp():
	var c := TestHelpers.make_creature({"current_hp": 0})
	assert_true(c.is_fainted())


func test_is_not_fainted_with_hp():
	var c := TestHelpers.make_creature({"current_hp": 1})
	assert_false(c.is_fainted())


func test_full_heal_restores_everything():
	var c := TestHelpers.make_creature({"max_hp": 50, "current_hp": 10})
	c.status_effect = "poison"
	c.status_turns = 3
	c.moves = [
		{"id": "sword_strike", "current_pp": 2, "max_pp": 35},
	]
	c.full_heal()
	assert_eq(c.current_hp, 50)
	assert_eq(c.status_effect, "")
	assert_eq(c.status_turns, 0)
	assert_eq(c.moves[0]["current_pp"], 35)


func test_gain_experience_no_level_up():
	var c := TestHelpers.make_creature({"level": 5})
	c.experience = 0
	var leveled := c.gain_experience(100)
	assert_false(leveled, "Should not level up with 100 EXP")
	assert_eq(c.experience, 100)
	assert_eq(c.level, 5)


func test_gain_experience_level_up():
	var c := TestHelpers.make_creature({"level": 5})
	c.experience = 0
	var leveled := c.gain_experience(216)
	assert_true(leveled, "Should level up at 216 EXP")
	assert_eq(c.level, 6)
	assert_eq(c.experience, 0, "Leftover exp should be 0")


func test_gain_experience_overflow():
	var c := TestHelpers.make_creature({"level": 5})
	c.experience = 0
	var leveled := c.gain_experience(300)
	assert_true(leveled)
	assert_eq(c.level, 6)
	assert_eq(c.experience, 84, "300 - 216 = 84 leftover")


func test_create_invalid_creature():
	var c := CreatureInstance.create("nonexistent_id", 5)
	assert_eq(c.creature_id, "", "Should have empty creature_id for invalid data")
