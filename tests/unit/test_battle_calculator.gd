extends GutTest
## Unit tests for BattleCalculator — damage formula, accuracy, crits, STAB, EXP.

var _attacker: CreatureInstance
var _defender: CreatureInstance


func before_each():
	_attacker = TestHelpers.make_creature({
		"level": 10, "types": ["fire"],
	})
	_defender = TestHelpers.make_creature({
		"level": 10, "types": ["normal"],
	})


func test_status_move_deals_no_damage():
	var move := TestHelpers.make_move({"power": 0, "category": "status"})
	var result := BattleCalculator.calculate_damage(_attacker, _defender, move)
	assert_eq(result["damage"], 0, "Status moves should deal 0 damage")
	assert_false(result["missed"])


func test_damage_in_expected_range():
	var move := TestHelpers.make_move({"power": 50, "type": "normal"})
	# Base = ((2*10/5+2)*50*18/18)/50+2 = 8
	# Min = int(8*0.85) = 6, Max = int(8*2.0*1.0) = 16 (with possible crit)
	for i in range(50):
		var result := BattleCalculator.calculate_damage(_attacker, _defender, move)
		if not result["missed"]:
			assert_between(result["damage"], 6, 16,
				"Damage should be within expected range")


func test_stab_increases_damage():
	var fire_move := TestHelpers.make_move({"power": 50, "type": "fire"})
	var normal_move := TestHelpers.make_move({"power": 50, "type": "normal"})

	var fire_total := 0
	var normal_total := 0
	var runs := 200

	for i in range(runs):
		seed(i * 1000)
		var fire_result := BattleCalculator.calculate_damage(_attacker, _defender, fire_move)
		seed(i * 1000)
		var normal_result := BattleCalculator.calculate_damage(_attacker, _defender, normal_move)
		fire_total += fire_result["damage"]
		normal_total += normal_result["damage"]

	var ratio := float(fire_total) / float(normal_total)
	assert_between(ratio, 1.3, 1.7,
		"STAB should make fire moves ~1.5x stronger on average")


func test_super_effective_doubles_damage():
	var grass_defender := TestHelpers.make_creature({"level": 10, "types": ["grass"]})
	var move := TestHelpers.make_move({"power": 50, "type": "fire"})

	for i in range(50):
		var result := BattleCalculator.calculate_damage(_attacker, grass_defender, move)
		assert_eq(result["effectiveness"], 2.0)
		assert_eq(result["effectiveness_text"], "It's super effective!")


func test_immune_deals_zero():
	var ghost_defender := TestHelpers.make_creature({"level": 10, "types": ["ghost"]})
	var move := TestHelpers.make_move({"power": 50, "type": "normal"})
	var result := BattleCalculator.calculate_damage(_attacker, ghost_defender, move)
	assert_eq(result["damage"], 0, "Normal vs Ghost should deal 0")
	assert_eq(result["effectiveness"], 0.0)


func test_critical_hit_flag():
	var got_crit := false
	var got_no_crit := false
	var move := TestHelpers.make_move({"power": 50})
	for i in range(200):
		var result := BattleCalculator.calculate_damage(_attacker, _defender, move)
		if result["critical"]:
			got_crit = true
		else:
			got_no_crit = true
		if got_crit and got_no_crit:
			break

	assert_true(got_crit, "Should get at least one crit in 200 tries")
	assert_true(got_no_crit, "Should get at least one non-crit in 200 tries")


func test_miss_with_low_accuracy():
	var move := TestHelpers.make_move({"power": 50, "accuracy": 50})
	var missed := false
	var hit := false
	for i in range(100):
		var result := BattleCalculator.calculate_damage(_attacker, _defender, move)
		if result["missed"]:
			missed = true
		else:
			hit = true
		if missed and hit:
			break

	assert_true(missed, "50% accuracy should miss sometimes")
	assert_true(hit, "50% accuracy should hit sometimes")


func test_100_accuracy_never_misses():
	var move := TestHelpers.make_move({"power": 50, "accuracy": 100})
	for i in range(50):
		var result := BattleCalculator.calculate_damage(_attacker, _defender, move)
		assert_false(result["missed"], "100% accuracy should never miss")


func test_minimum_1_damage():
	var weak_attacker := TestHelpers.make_creature({"level": 1, "attack": 1})
	var tough_defender := TestHelpers.make_creature({"level": 100, "defense": 200})
	var move := TestHelpers.make_move({"power": 10})
	for i in range(20):
		var result := BattleCalculator.calculate_damage(weak_attacker, tough_defender, move)
		assert_gte(result["damage"], 1, "Should deal at least 1 damage when not immune")


func test_special_move_uses_sp_stats():
	var sp_attacker := TestHelpers.make_creature({
		"level": 10, "attack": 5, "sp_attack": 50,
	})
	var sp_move := TestHelpers.make_move({"power": 50, "category": "special"})
	var phys_move := TestHelpers.make_move({"power": 50, "category": "physical"})

	var sp_total := 0
	var phys_total := 0
	for i in range(100):
		seed(i * 1000)
		sp_total += BattleCalculator.calculate_damage(sp_attacker, _defender, sp_move)["damage"]
		seed(i * 1000)
		phys_total += BattleCalculator.calculate_damage(sp_attacker, _defender, phys_move)["damage"]

	assert_gt(sp_total, phys_total * 2,
		"Special moves should deal much more damage with high sp_attack / low attack")


func test_exp_yield_wild():
	var defeated := CreatureInstance.create("goblin", 3)
	var exp := BattleCalculator.calculate_exp_yield(defeated, true)
	assert_eq(exp, 16)


func test_exp_yield_trainer():
	var defeated := CreatureInstance.create("goblin", 3)
	var exp := BattleCalculator.calculate_exp_yield(defeated, false)
	assert_eq(exp, 24)
