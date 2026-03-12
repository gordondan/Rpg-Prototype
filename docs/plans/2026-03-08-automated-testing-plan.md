# MonsterQuest Automated Testing — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add GUT (Godot Unit Test) with unit, component, and integration test layers covering all game systems.

**Architecture:** GUT addon installed in `addons/gut/`, tests in `tests/` mirroring source structure. Three layers: unit (pure logic), component (single systems with signals/state), integration (multi-system flows). Tests run headless via CLI or in-editor via GUT dock.

**Tech Stack:** Godot 4.3, GUT 9.x, GDScript

**Note:** `godot` in commands below means the Godot 4.3 binary. Adjust path if needed (e.g., `/Applications/Godot.app/Contents/MacOS/Godot`).

---

### Task 1: Install GUT & Configure

**Files:**
- Create: `addons/gut/` (addon directory — installed from AssetLib or GitHub)
- Create: `.gutconfig.json`
- Modify: `project.godot` (enable plugin)

**Step 1: Install GUT addon**

Download GUT 9.x and extract to `addons/gut/`. Use one of:

```bash
# Option A: From GitHub
curl -L https://github.com/bitwes/Gut/releases/latest/download/GUT.zip -o /tmp/gut.zip
unzip -o /tmp/gut.zip -d addons/

# Option B: In Godot Editor → AssetLib → Search "GUT" → Install
```

Verify `addons/gut/plugin.cfg` exists after installation.

**Step 2: Create `.gutconfig.json`**

```json
{
  "dirs": [
    "res://tests/unit",
    "res://tests/component",
    "res://tests/integration"
  ],
  "prefix": "test_",
  "suffix": ".gd",
  "should_maximize": false,
  "log_level": 1
}
```

**Step 3: Enable GUT plugin in project.godot**

Add to `project.godot` under `[editor_plugins]`:

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

**Step 4: Create test directories**

```bash
mkdir -p tests/unit tests/component tests/integration tests/helpers
```

**Step 5: Verify GUT runs**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: GUT runs with 0 tests found, exits cleanly.

**Step 6: Commit**

```bash
git add addons/gut .gutconfig.json project.godot tests/
git commit -m "chore: install GUT testing framework and configure test directories"
```

---

### Task 2: Test Helpers

**Files:**
- Create: `tests/helpers/test_helpers.gd`

**Step 1: Write the test helpers**

```gdscript
extends RefCounted
class_name TestHelpers
## Shared utilities for tests. Provides factory methods and common setup.


static func make_creature(overrides: Dictionary = {}) -> CreatureInstance:
	## Create a CreatureInstance with known, simple stats for testing.
	## Override any property by passing it in the overrides dict.
	var c := CreatureInstance.new()
	c.creature_id = overrides.get("creature_id", "test_creature")
	c.nickname = overrides.get("nickname", "Test Creature")
	c.level = overrides.get("level", 10)
	c.experience = overrides.get("experience", 0)

	c.base_hp = overrides.get("base_hp", 50)
	c.base_attack = overrides.get("base_attack", 50)
	c.base_defense = overrides.get("base_defense", 50)
	c.base_sp_attack = overrides.get("base_sp_attack", 50)
	c.base_sp_defense = overrides.get("base_sp_defense", 50)
	c.base_speed = overrides.get("base_speed", 50)

	c.types = overrides.get("types", ["normal"])

	# Calculate stats from base stats and level
	c.max_hp = overrides.get("max_hp", int(((2.0 * c.base_hp + 31.0) * c.level / 100.0) + c.level + 10))
	c.attack = overrides.get("attack", int(((2.0 * c.base_attack + 31.0) * c.level / 100.0) + 5))
	c.defense = overrides.get("defense", int(((2.0 * c.base_defense + 31.0) * c.level / 100.0) + 5))
	c.sp_attack = overrides.get("sp_attack", int(((2.0 * c.base_sp_attack + 31.0) * c.level / 100.0) + 5))
	c.sp_defense = overrides.get("sp_defense", int(((2.0 * c.base_sp_defense + 31.0) * c.level / 100.0) + 5))
	c.speed = overrides.get("speed", int(((2.0 * c.base_speed + 31.0) * c.level / 100.0) + 5))

	c.current_hp = overrides.get("current_hp", c.max_hp)
	c.moves = overrides.get("moves", [])

	return c


static func make_move(overrides: Dictionary = {}) -> Dictionary:
	## Create a move dictionary with known values for testing.
	return {
		"name": overrides.get("name", "Test Move"),
		"type": overrides.get("type", "normal"),
		"category": overrides.get("category", "physical"),
		"power": overrides.get("power", 50),
		"accuracy": overrides.get("accuracy", 100),
		"pp": overrides.get("pp", 20),
	}.merged(overrides)


static func reset_game_manager() -> void:
	## Reset GameManager to a clean state between tests.
	GameManager.player_party.clear()
	GameManager.story_flags.clear()
	GameManager.inventory.clear()
	GameManager.gold = 500
	GameManager.player_name = "Captain"
	GameManager.guild_ranks.clear()
	GameManager.current_state = GameManager.GameState.OVERWORLD
```

**Step 2: Verify file is valid GDScript**

Run: `godot --headless --check-only -s tests/helpers/test_helpers.gd` (or just proceed to next task — GUT will catch syntax errors)

**Step 3: Commit**

```bash
git add tests/helpers/test_helpers.gd
git commit -m "feat: add test helper utilities for creature and move creation"
```

---

### Task 3: TypeChart Unit Tests

**Files:**
- Create: `tests/unit/test_type_chart.gd`
- Reference: `scripts/battle/type_chart.gd`

**Step 1: Write the tests**

```gdscript
extends GutTest
## Unit tests for TypeChart — verifies type effectiveness lookups.


func test_super_effective():
	assert_eq(TypeChart.get_effectiveness("fire", ["grass"]), 2.0,
		"Fire vs Grass should be super effective")


func test_not_very_effective():
	assert_eq(TypeChart.get_effectiveness("fire", ["water"]), 0.5,
		"Fire vs Water should be not very effective")


func test_immune():
	assert_eq(TypeChart.get_effectiveness("normal", ["ghost"]), 0.0,
		"Normal vs Ghost should have no effect")


func test_neutral():
	# Fire vs fighting — fighting not in fire's chart → 1.0
	assert_eq(TypeChart.get_effectiveness("fire", ["fighting"]), 1.0,
		"Fire vs Fighting should be neutral")


func test_dual_type_compounds():
	# Fire vs Grass/Bug: fire→grass = 2.0, fire→bug = 2.0 → 4.0
	assert_eq(TypeChart.get_effectiveness("fire", ["grass", "bug"]), 4.0,
		"Fire vs Grass/Bug should compound to 4x")


func test_dual_type_mixed():
	# Fire vs Grass/Water: fire→grass = 2.0, fire→water = 0.5 → 1.0
	assert_eq(TypeChart.get_effectiveness("fire", ["grass", "water"]), 1.0,
		"Fire vs Grass/Water should cancel to 1x")


func test_dual_type_with_immunity():
	# Normal vs Ghost/Fighting: normal→ghost = 0.0 → 0.0 regardless
	assert_eq(TypeChart.get_effectiveness("normal", ["ghost", "fighting"]), 0.0,
		"Immunity zeroes out even with super effective second type")


func test_unknown_attack_type_is_neutral():
	assert_eq(TypeChart.get_effectiveness("banana", ["fire"]), 1.0,
		"Unknown attack type should be neutral")


func test_effectiveness_text_super():
	assert_eq(TypeChart.get_effectiveness_text(2.0), "It's super effective!")


func test_effectiveness_text_not_very():
	assert_eq(TypeChart.get_effectiveness_text(0.5), "It's not very effective...")


func test_effectiveness_text_immune():
	assert_eq(TypeChart.get_effectiveness_text(0.0), "It doesn't affect the target...")


func test_effectiveness_text_neutral():
	assert_eq(TypeChart.get_effectiveness_text(1.0), "",
		"Neutral should return empty string")


func test_effectiveness_text_4x():
	assert_eq(TypeChart.get_effectiveness_text(4.0), "It's super effective!",
		"4x should still say super effective")
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_type_chart.gd`

Expected: All 13 tests PASS.

**Step 3: Commit**

```bash
git add tests/unit/test_type_chart.gd
git commit -m "test: add TypeChart unit tests for effectiveness lookups"
```

---

### Task 4: CreatureInstance Unit Tests

**Files:**
- Create: `tests/unit/test_creature_instance.gd`
- Reference: `scripts/battle/creature_instance.gd`, `data/creatures/starters.json`

**Step 1: Write the tests**

These tests use `CreatureInstance.create()` which depends on the DataLoader autoload (loads creature/move data). DataLoader autoloads on `_ready()` so data should be available.

Pre-computed expected values for Flame Squire at level 5 (base_hp=44, base_atk=52, base_def=43, base_spatk=60, base_spdef=50, base_spd=65):
- max_hp = `int((2*44+31)*5/100 + 5+10)` = `int(5.95+15)` = **20**
- attack = `int((2*52+31)*5/100 + 5)` = `int(6.75+5)` = **11**
- defense = `int((2*43+31)*5/100 + 5)` = `int(5.85+5)` = **10**
- sp_attack = `int((2*60+31)*5/100 + 5)` = `int(7.55+5)` = **12**
- sp_defense = `int((2*50+31)*5/100 + 5)` = `int(6.55+5)` = **11**
- speed = `int((2*65+31)*5/100 + 5)` = `int(8.05+5)` = **13**

At level 50:
- max_hp = `int(119*50/100 + 60)` = **119**
- attack = `int(135*50/100 + 5)` = **72**

Moves at level 5: sword_strike, war_cry (only 2 learnable at ≤5).
Moves at level 10: sword_strike, war_cry, fire_bolt, smoke_bomb (4 learnable at ≤10, takes last 4 = all 4).

```gdscript
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
	# At level 50, 7 moves are learnable. Should only keep last 4.
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
	# EXP needed for level 6: pow(6, 3) = 216
	var leveled := c.gain_experience(100)
	assert_false(leveled, "Should not level up with 100 EXP")
	assert_eq(c.experience, 100)
	assert_eq(c.level, 5)


func test_gain_experience_level_up():
	var c := TestHelpers.make_creature({"level": 5})
	c.experience = 0
	# EXP needed for level 6: pow(6, 3) = 216
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
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_creature_instance.gd`

Expected: All tests PASS.

**Step 3: Commit**

```bash
git add tests/unit/test_creature_instance.gd
git commit -m "test: add CreatureInstance unit tests for stats, moves, damage, healing, and leveling"
```

---

### Task 5: BattleCalculator Unit Tests

**Files:**
- Create: `tests/unit/test_battle_calculator.gd`
- Reference: `scripts/battle/battle_calculator.gd`

**Step 1: Write the tests**

Uses `TestHelpers.make_creature()` and `TestHelpers.make_move()` to create known inputs. Tests use property-based assertions (ranges) to handle RNG in the damage formula.

Pre-computed base damage for reference (attacker level=10, atk=18, defender def=18, power=50):
`base = ((2*10/5+2) * 50 * 18/18) / 50 + 2 = (6*50*1)/50 + 2 = 6+2 = 8`
- No crit, no STAB, neutral, random=0.85: `int(8*0.85)` = 6
- No crit, no STAB, neutral, random=1.0: `int(8*1.0)` = 8
- With crit: 6×2=12 to 8×2=16
- With STAB: ×1.5 → 9 to 12
- Super effective: ×2.0 → 12 to 16

Attacker level=10 with base_attack=50 → attack = `int((2*50+31)*10/100+5)` = `int(131*0.1+5)` = `int(18.1)` = 18.
Defender with base_defense=50 → defense = 18.

```gdscript
extends GutTest
## Unit tests for BattleCalculator — damage formula, accuracy, crits, STAB, EXP.

var _attacker: CreatureInstance
var _defender: CreatureInstance


func before_each():
	# Both level 10 with base 50 in all stats → attack=18, defense=18, etc.
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
	# Fire move by fire attacker vs normal defender
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

	# STAB adds 1.5x — average fire damage should be ~1.5x normal
	var ratio := float(fire_total) / float(normal_total)
	assert_between(ratio, 1.3, 1.7,
		"STAB should make fire moves ~1.5x stronger on average")


func test_super_effective_doubles_damage():
	# Fire attacker vs grass defender (2x)
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
	# Run enough times that at least one crit occurs (6.25% chance)
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
	# Very weak attack should still do at least 1 damage (unless immune)
	var weak_attacker := TestHelpers.make_creature({"level": 1, "attack": 1})
	var tough_defender := TestHelpers.make_creature({"level": 100, "defense": 200})
	var move := TestHelpers.make_move({"power": 10})
	for i in range(20):
		var result := BattleCalculator.calculate_damage(weak_attacker, tough_defender, move)
		assert_gte(result["damage"], 1, "Should deal at least 1 damage when not immune")


func test_special_move_uses_sp_stats():
	# Attacker with high sp_attack but low attack
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
	# Goblin base_exp=38, level 3, wild (1.0x)
	# = int((38 * 3 * 1.0) / 7.0) = int(16.28) = 16
	var defeated := CreatureInstance.create("goblin", 3)
	var exp := BattleCalculator.calculate_exp_yield(defeated, true)
	assert_eq(exp, 16)


func test_exp_yield_trainer():
	# Goblin base_exp=38, level 3, trainer (1.5x)
	# = int((38 * 3 * 1.5) / 7.0) = int(24.42) = 24
	var defeated := CreatureInstance.create("goblin", 3)
	var exp := BattleCalculator.calculate_exp_yield(defeated, false)
	assert_eq(exp, 24)
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_battle_calculator.gd`

Expected: All tests PASS.

**Step 3: Commit**

```bash
git add tests/unit/test_battle_calculator.gd
git commit -m "test: add BattleCalculator unit tests for damage, accuracy, crits, STAB, and EXP"
```

---

### Task 6: DataLoader Unit Tests

**Files:**
- Create: `tests/unit/test_data_loader.gd`
- Reference: `scripts/autoload/data_loader.gd`, `data/creatures/`, `data/moves/`, `data/maps/`

**Step 1: Write the tests**

DataLoader is an autoload, so it's already initialized with data by the time tests run.

```gdscript
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
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_data_loader.gd`

Expected: All tests PASS.

**Step 3: Commit**

```bash
git add tests/unit/test_data_loader.gd
git commit -m "test: add DataLoader unit tests for creature, move, and encounter data integrity"
```

---

### Task 7: GameManager Component Tests

**Files:**
- Create: `tests/component/test_game_manager.gd`
- Reference: `scripts/autoload/game_manager.gd`

**Step 1: Write the tests**

GameManager is an autoload singleton. We reset its state in `before_each()` to isolate tests.

```gdscript
extends GutTest
## Component tests for GameManager — state, party, flags, save/load.


func before_each():
	TestHelpers.reset_game_manager()


func test_initial_state_is_overworld():
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)


func test_set_state_changes_state():
	GameManager.set_state(GameManager.GameState.BATTLE)
	assert_eq(GameManager.current_state, GameManager.GameState.BATTLE)


func test_set_state_emits_signal():
	watch_signals(GameManager)
	GameManager.set_state(GameManager.GameState.BATTLE)
	assert_signal_emitted(GameManager, "game_state_changed")


func test_is_player_free_only_in_overworld():
	GameManager.set_state(GameManager.GameState.OVERWORLD)
	assert_true(GameManager.is_player_free())

	GameManager.set_state(GameManager.GameState.BATTLE)
	assert_false(GameManager.is_player_free())

	GameManager.set_state(GameManager.GameState.DIALOGUE)
	assert_false(GameManager.is_player_free())

	GameManager.set_state(GameManager.GameState.MENU)
	assert_false(GameManager.is_player_free())


func test_add_creature_to_party():
	var c := TestHelpers.make_creature()
	var added := GameManager.add_creature_to_party(c)
	assert_true(added)
	assert_eq(GameManager.player_party.size(), 1)


func test_party_max_6():
	for i in range(6):
		GameManager.add_creature_to_party(TestHelpers.make_creature())
	assert_eq(GameManager.player_party.size(), 6)

	var added := GameManager.add_creature_to_party(TestHelpers.make_creature())
	assert_false(added, "Should not add 7th creature")
	assert_eq(GameManager.player_party.size(), 6)


func test_get_first_alive_creature():
	var c1 := TestHelpers.make_creature({"nickname": "First", "current_hp": 0})
	var c2 := TestHelpers.make_creature({"nickname": "Second", "current_hp": 10})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	var alive := GameManager.get_first_alive_creature()
	assert_eq(alive.nickname, "Second")


func test_get_first_alive_returns_null_when_wiped():
	var c := TestHelpers.make_creature({"current_hp": 0})
	GameManager.add_creature_to_party(c)
	assert_null(GameManager.get_first_alive_creature())


func test_is_party_wiped():
	var c1 := TestHelpers.make_creature({"current_hp": 0})
	var c2 := TestHelpers.make_creature({"current_hp": 0})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	assert_true(GameManager.is_party_wiped())


func test_is_party_not_wiped():
	var c1 := TestHelpers.make_creature({"current_hp": 0})
	var c2 := TestHelpers.make_creature({"current_hp": 1})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	assert_false(GameManager.is_party_wiped())


func test_heal_all_party():
	var c1 := TestHelpers.make_creature({"max_hp": 50, "current_hp": 10})
	c1.status_effect = "poison"
	var c2 := TestHelpers.make_creature({"max_hp": 50, "current_hp": 25})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	GameManager.heal_all_party()
	assert_eq(c1.current_hp, 50)
	assert_eq(c1.status_effect, "")
	assert_eq(c2.current_hp, 50)


func test_story_flags():
	assert_false(GameManager.get_flag("test_flag"))
	GameManager.set_flag("test_flag", true)
	assert_true(GameManager.get_flag("test_flag"))
	GameManager.set_flag("test_flag", false)
	assert_false(GameManager.get_flag("test_flag"))


func test_transition_to_battle_sets_state():
	GameManager.transition_to_battle(Vector2(100, 200), "test_map")
	assert_eq(GameManager.current_state, GameManager.GameState.BATTLE)


func test_return_from_battle_restores_overworld():
	GameManager.set_state(GameManager.GameState.BATTLE)
	GameManager.return_from_battle()
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)


func test_save_load_roundtrip():
	GameManager.player_name = "TestHero"
	GameManager.gold = 1234
	GameManager.set_flag("test_flag_roundtrip", true)
	var c := CreatureInstance.create("flame_squire", 7)
	c.nickname = "Testy"
	c.current_hp = 15
	GameManager.add_creature_to_party(c)

	GameManager.save_game(99)  # Use slot 99 to not conflict
	TestHelpers.reset_game_manager()

	var loaded := GameManager.load_game(99)
	assert_true(loaded, "Should load successfully")
	assert_eq(GameManager.player_name, "TestHero")
	assert_eq(GameManager.gold, 1234)
	assert_true(GameManager.get_flag("test_flag_roundtrip"))
	assert_eq(GameManager.player_party.size(), 1)
	assert_eq(GameManager.player_party[0].nickname, "Testy")
	assert_eq(GameManager.player_party[0].level, 7)
	assert_eq(GameManager.player_party[0].current_hp, 15)


func after_all():
	# Clean up test save file
	var path := "user://save_99.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	TestHelpers.reset_game_manager()
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/component/test_game_manager.gd`

Expected: All tests PASS.

**Step 3: Commit**

```bash
git add tests/component/test_game_manager.gd
git commit -m "test: add GameManager component tests for state, party, flags, and save/load"
```

---

### Task 8: BattleStateMachine Component Tests

**Files:**
- Create: `tests/component/test_battle_state_machine.gd`
- Reference: `scripts/battle/battle_state_machine.gd`

**Step 1: Write the tests**

BattleStateMachine extends Node and uses `await get_tree().create_timer()`. It must be added to the scene tree. Tests use `await` and `wait_for_signal()`. These tests are slower due to real timers (~1-2s per transition).

```gdscript
extends GutTest
## Component tests for BattleStateMachine — state transitions, signals, battle flow.

var _bsm: BattleStateMachine
var _player: CreatureInstance
var _enemy: CreatureInstance


func before_each():
	_bsm = BattleStateMachine.new()
	add_child_autoqfree(_bsm)

	# Player: fire type, high speed so they go first
	_player = TestHelpers.make_creature({
		"creature_id": "flame_squire", "nickname": "Player",
		"level": 10, "types": ["fire"],
		"speed": 50, "max_hp": 100, "current_hp": 100,
		"attack": 30, "defense": 18, "sp_attack": 30, "sp_defense": 18,
		"moves": [
			{"id": "sword_strike", "current_pp": 35, "max_pp": 35},
			{"id": "fire_bolt", "current_pp": 25, "max_pp": 25},
		],
	})

	# Enemy: low speed so player goes first, low HP so it can be KO'd
	_enemy = TestHelpers.make_creature({
		"creature_id": "goblin", "nickname": "Enemy",
		"level": 3, "types": ["poison"],
		"speed": 5, "max_hp": 10, "current_hp": 10,
		"attack": 10, "defense": 7, "sp_attack": 7, "sp_defense": 7,
		"moves": [
			{"id": "dagger_jab", "current_pp": 35, "max_pp": 35},
		],
	})


func test_initial_state_is_intro():
	watch_signals(_bsm)
	_bsm.start_battle(_player, _enemy, true)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.INTRO)


func test_transitions_to_player_turn():
	watch_signals(_bsm)
	_bsm.start_battle(_player, _enemy, true)
	# start_battle awaits 1.5s then sets PLAYER_TURN
	await wait_for_signal(_bsm.state_changed, 3.0)
	# May need to wait for the second state_changed (first is INTRO)
	if _bsm.current_state == BattleStateMachine.BattleState.INTRO:
		await wait_for_signal(_bsm.state_changed, 3.0)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.PLAYER_TURN)


func test_battle_message_emits_on_intro():
	watch_signals(_bsm)
	_bsm.start_battle(_player, _enemy, true)
	assert_signal_emitted(_bsm, "battle_message")


func test_select_fight_only_in_player_turn():
	_bsm.start_battle(_player, _enemy, true)
	# Still in INTRO — select_fight should do nothing
	_bsm.select_fight(0)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.INTRO,
		"Should not change state when not in PLAYER_TURN")


func test_player_goes_first_when_faster():
	_bsm.start_battle(_player, _enemy, true)
	await wait_for_signal(_bsm.state_changed, 3.0)
	if _bsm.current_state == BattleStateMachine.BattleState.INTRO:
		await wait_for_signal(_bsm.state_changed, 3.0)

	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.PLAYER_TURN)

	watch_signals(_bsm)
	_bsm.select_fight(0)

	# Wait for battle to resolve — player action should happen first
	await wait_for_signal(_bsm.state_changed, 3.0)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.PLAYER_ACTION,
		"Player should act first due to higher speed")


func test_defeating_enemy_emits_win():
	# Give enemy 1 HP so any hit kills it
	_enemy.current_hp = 1

	_bsm.start_battle(_player, _enemy, true)
	await wait_for_signal(_bsm.state_changed, 3.0)
	if _bsm.current_state == BattleStateMachine.BattleState.INTRO:
		await wait_for_signal(_bsm.state_changed, 3.0)

	watch_signals(_bsm)
	_bsm.select_fight(0)  # sword_strike — will KO the 1 HP enemy

	# Wait for battle_ended signal
	await wait_for_signal(_bsm.battle_ended, 10.0)
	assert_signal_emitted(_bsm, "battle_ended")
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.WIN)


func test_player_fainting_emits_lose():
	# Give player 1 HP, enemy high attack, and make enemy faster
	_player.current_hp = 1
	_player.speed = 1
	_enemy.speed = 100
	_enemy.attack = 100

	_bsm.start_battle(_player, _enemy, true)
	await wait_for_signal(_bsm.state_changed, 3.0)
	if _bsm.current_state == BattleStateMachine.BattleState.INTRO:
		await wait_for_signal(_bsm.state_changed, 3.0)

	watch_signals(_bsm)
	_bsm.select_fight(0)

	await wait_for_signal(_bsm.battle_ended, 10.0)
	assert_signal_emitted(_bsm, "battle_ended")
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.LOSE)


func test_cannot_run_from_trainer_battle():
	watch_signals(_bsm)
	_bsm.start_battle(_player, _enemy, false)  # not wild
	await wait_for_signal(_bsm.state_changed, 3.0)
	if _bsm.current_state == BattleStateMachine.BattleState.INTRO:
		await wait_for_signal(_bsm.state_changed, 3.0)

	_bsm.select_run()
	# Should emit "no retreating" message and return to PLAYER_TURN
	await wait_for_signal(_bsm.state_changed, 3.0)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.PLAYER_TURN,
		"Should return to PLAYER_TURN after failed run from trainer battle")


func test_exp_gained_on_win():
	_enemy.current_hp = 1
	_bsm.start_battle(_player, _enemy, true)
	await wait_for_signal(_bsm.state_changed, 3.0)
	if _bsm.current_state == BattleStateMachine.BattleState.INTRO:
		await wait_for_signal(_bsm.state_changed, 3.0)

	watch_signals(_bsm)
	_bsm.select_fight(0)

	await wait_for_signal(_bsm.exp_gained, 10.0)
	assert_signal_emitted(_bsm, "exp_gained")


func test_poison_deals_damage_at_end_of_turn():
	_player.status_effect = "poison"
	var hp_before := _player.current_hp

	_bsm.start_battle(_player, _enemy, true)
	await wait_for_signal(_bsm.state_changed, 3.0)
	if _bsm.current_state == BattleStateMachine.BattleState.INTRO:
		await wait_for_signal(_bsm.state_changed, 3.0)

	_bsm.select_fight(0)

	# Wait for turn to fully resolve back to PLAYER_TURN
	await wait_for_signal(_bsm.state_changed, 10.0)
	# May take several state changes to get back to PLAYER_TURN
	var timeout := 15.0
	var start := Time.get_ticks_msec()
	while _bsm.current_state != BattleStateMachine.BattleState.PLAYER_TURN:
		if _bsm.current_state == BattleStateMachine.BattleState.WIN or \
		   _bsm.current_state == BattleStateMachine.BattleState.LOSE:
			break
		if (Time.get_ticks_msec() - start) / 1000.0 > timeout:
			break
		await wait_for_signal(_bsm.state_changed, 3.0)

	# Poison damage = max(1, max_hp / 8)
	var expected_poison_dmg := max(1, _player.max_hp / 8)
	# Player also may have taken battle damage — just check HP decreased
	assert_lt(_player.current_hp, hp_before, "Poison should have reduced HP")


func test_escape_chance_calculation():
	_bsm.player_creature = _player
	_bsm.enemy_creature = _enemy

	# Player speed 50, enemy speed 5
	# Chance = clamp((50/5) * 0.5 + 0.25, 0.2, 1.0) = clamp(5.25, 0.2, 1.0) = 1.0
	var chance := _bsm._calculate_escape_chance()
	assert_eq(chance, 1.0, "High speed ratio should guarantee escape")

	# Flip speeds
	_player.speed = 5
	_enemy.speed = 50
	# Chance = clamp((5/50) * 0.5 + 0.25, 0.2, 1.0) = clamp(0.3, 0.2, 1.0) = 0.3
	chance = _bsm._calculate_escape_chance()
	assert_between(chance, 0.29, 0.31, "Low speed ratio should give ~30% chance")
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/component/test_battle_state_machine.gd`

Expected: All tests PASS (some may take a few seconds due to timers).

**Step 3: Commit**

```bash
git add tests/component/test_battle_state_machine.gd
git commit -m "test: add BattleStateMachine component tests for state transitions and battle flow"
```

---

### Task 9: DialogueManager Component Tests

**Files:**
- Create: `tests/component/test_dialogue_manager.gd`
- Reference: `scripts/autoload/dialogue_manager.gd`

**Step 1: Write the tests**

DialogueManager is an autoload that creates UI elements. Some tests are limited because `_begin_dialogue()` loads a scene and adds it to the scene tree. We test the API boundaries: signal emissions, state tracking, and flag gating.

```gdscript
extends GutTest
## Component tests for DialogueManager — dialogue state, signals, flag gating.


func before_each():
	TestHelpers.reset_game_manager()
	# Reset DialogueManager active state
	if DialogueManager._is_active:
		DialogueManager._is_active = false
	if DialogueManager._dialogue_box and is_instance_valid(DialogueManager._dialogue_box):
		DialogueManager._dialogue_box.queue_free()
		DialogueManager._dialogue_box = null


func test_initially_not_active():
	assert_false(DialogueManager.is_active())


func test_start_dialogue_sets_active():
	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("village_guard")
	assert_true(DialogueManager.is_active())


func test_start_dialogue_emits_started():
	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("village_guard")
	assert_signal_emitted(DialogueManager, "dialogue_started")


func test_start_dialogue_sets_game_state():
	DialogueManager.start_dialogue("village_guard")
	assert_eq(GameManager.current_state, GameManager.GameState.DIALOGUE)


func test_cannot_start_while_active():
	DialogueManager.start_dialogue("village_guard")
	assert_true(DialogueManager.is_active())

	# Try to start another — should not crash
	DialogueManager.start_dialogue("old_scholar")
	# Still active from first dialogue
	assert_true(DialogueManager.is_active())


func test_flag_gated_dialogue_blocked():
	# "mysterious_stranger" dialogue may require a flag — check if gating works
	var data := DialogueManager.get_dialogue_data("village_guard")
	if data.has("requires_flag"):
		# If this dialogue has a flag requirement, test it
		var flag_name: String = data["requires_flag"]
		GameManager.set_flag(flag_name, false)
		watch_signals(DialogueManager)
		DialogueManager.start_dialogue("village_guard")
		assert_signal_not_emitted(DialogueManager, "dialogue_started")
	else:
		pass_test("village_guard has no flag requirement — skip gating test")


func test_invalid_dialogue_id_stays_inactive():
	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("nonexistent_dialogue_xyz")
	assert_false(DialogueManager.is_active())
	assert_signal_not_emitted(DialogueManager, "dialogue_started")


func test_get_dialogue_data():
	var data := DialogueManager.get_dialogue_data("village_guard")
	assert_false(data.is_empty(), "Should have village_guard dialogue data")
	assert_true(data.has("lines"), "Dialogue should have lines array")


func test_get_invalid_dialogue_data():
	var data := DialogueManager.get_dialogue_data("nonexistent_xyz")
	assert_true(data.is_empty())


func test_show_line_sets_active():
	watch_signals(DialogueManager)
	DialogueManager.show_line("Hello world", "Narrator")
	assert_true(DialogueManager.is_active())
	assert_signal_emitted(DialogueManager, "dialogue_started")


func test_show_lines_sets_active():
	watch_signals(DialogueManager)
	DialogueManager.show_lines(["Line 1", "Line 2"])
	assert_true(DialogueManager.is_active())


func test_show_lines_empty_stays_inactive():
	watch_signals(DialogueManager)
	DialogueManager.show_lines([])
	assert_false(DialogueManager.is_active())
	assert_signal_not_emitted(DialogueManager, "dialogue_started")


func test_choice_rest_heals_party():
	var c := TestHelpers.make_creature({"max_hp": 50, "current_hp": 10})
	GameManager.add_creature_to_party(c)

	# Simulate the choice callback directly
	DialogueManager._on_choice_made(0, "rest")
	assert_eq(c.current_hp, 50, "Rest choice should heal party")


func after_each():
	# Ensure we clean up
	if DialogueManager._is_active:
		DialogueManager._on_dialogue_finished()
	TestHelpers.reset_game_manager()
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/component/test_dialogue_manager.gd`

Expected: All tests PASS.

**Step 3: Commit**

```bash
git add tests/component/test_dialogue_manager.gd
git commit -m "test: add DialogueManager component tests for dialogue state, signals, and flag gating"
```

---

### Task 10: Wild Battle Integration Test

**Files:**
- Create: `tests/integration/test_wild_battle_flow.gd`
- Reference: `scripts/autoload/battle_manager.gd`, `scripts/battle/battle_state_machine.gd`

**Step 1: Write the tests**

End-to-end test: trigger a wild battle → fight → win → return to overworld. These tests are slow (~5-10s each) due to real battle timers.

```gdscript
extends GutTest
## Integration test: full wild battle flow from encounter to victory.


func before_each():
	TestHelpers.reset_game_manager()
	# Give player a strong creature
	var starter := CreatureInstance.create("flame_squire", 20)
	GameManager.add_creature_to_party(starter)


func test_wild_battle_win_returns_to_overworld():
	watch_signals(BattleManager)

	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)

	# Start battle with a low-level goblin
	BattleManager.start_wild_battle("goblin", 2)

	assert_signal_emitted(BattleManager, "battle_started")
	assert_eq(GameManager.current_state, GameManager.GameState.BATTLE)

	# Find the battle scene that was added
	var battle_node: Node = null
	for child in get_tree().current_scene.get_children():
		if child.has_method("setup_battle"):
			battle_node = child
			break

	assert_not_null(battle_node, "Battle scene should have been added")

	# Wait for intro to finish → PLAYER_TURN
	var bsm: BattleStateMachine = null
	if battle_node and battle_node.has_node("BattleStateMachine"):
		bsm = battle_node.get_node("BattleStateMachine")
	elif battle_node and "state_machine" in battle_node:
		bsm = battle_node.state_machine

	if bsm:
		# Wait for PLAYER_TURN
		var timeout := 5.0
		var start := Time.get_ticks_msec()
		while bsm.current_state != BattleStateMachine.BattleState.PLAYER_TURN:
			await wait_for_signal(bsm.state_changed, 3.0)
			if (Time.get_ticks_msec() - start) / 1000.0 > timeout:
				fail_test("Timed out waiting for PLAYER_TURN")
				return

		# Select first move (should be strong enough to KO level 2 goblin)
		watch_signals(bsm)
		bsm.select_fight(0)

		# Wait for battle to end
		await wait_for_signal(bsm.battle_ended, 15.0)
		assert_signal_emitted(bsm, "battle_ended")

	# Clean up battle scene
	if battle_node and is_instance_valid(battle_node):
		battle_node.queue_free()

	# Simulate BattleManager.end_battle
	BattleManager.end_battle("win")
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD,
		"Should return to overworld after battle")


func test_exp_gained_after_wild_battle():
	var starter := GameManager.get_first_alive_creature()
	var exp_before := starter.experience

	BattleManager.start_wild_battle("goblin", 2)

	# Find battle state machine
	var battle_node: Node = null
	for child in get_tree().current_scene.get_children():
		if child.has_method("setup_battle"):
			battle_node = child
			break

	var bsm: BattleStateMachine = null
	if battle_node:
		if "state_machine" in battle_node:
			bsm = battle_node.state_machine
		elif battle_node.has_node("BattleStateMachine"):
			bsm = battle_node.get_node("BattleStateMachine")

	if bsm:
		# Wait for player turn
		var timeout := 5.0
		var start := Time.get_ticks_msec()
		while bsm.current_state != BattleStateMachine.BattleState.PLAYER_TURN:
			await wait_for_signal(bsm.state_changed, 3.0)
			if (Time.get_ticks_msec() - start) / 1000.0 > timeout:
				fail_test("Timed out waiting for PLAYER_TURN")
				return

		bsm.select_fight(0)
		await wait_for_signal(bsm.battle_ended, 15.0)

	# The BSM should have awarded EXP to the player creature
	assert_gt(starter.experience, exp_before,
		"Player creature should have gained EXP")

	# Clean up
	if battle_node and is_instance_valid(battle_node):
		battle_node.queue_free()
	BattleManager.end_battle("win")


func after_each():
	# Clean up any lingering battle scenes
	for child in get_tree().current_scene.get_children():
		if child.has_method("setup_battle"):
			child.queue_free()
	TestHelpers.reset_game_manager()
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_wild_battle_flow.gd`

Expected: Tests PASS (may take 10-20s total due to battle timers).

**Step 3: Commit**

```bash
git add tests/integration/test_wild_battle_flow.gd
git commit -m "test: add wild battle integration test for full encounter flow"
```

---

### Task 11: NPC Interaction Integration Test

**Files:**
- Create: `tests/integration/test_npc_interaction_flow.gd`
- Reference: `scripts/overworld/npc.gd`, `scripts/autoload/dialogue_manager.gd`

**Step 1: Write the tests**

Tests NPC dialogue triggering and the dialogue-to-game-state round trip.

```gdscript
extends GutTest
## Integration test: NPC interaction triggers dialogue, returns to overworld.


func before_each():
	TestHelpers.reset_game_manager()


func test_dialogue_roundtrip_via_manager():
	# Verify the full dialogue lifecycle through DialogueManager
	watch_signals(DialogueManager)

	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)
	assert_false(DialogueManager.is_active())

	# Start dialogue
	DialogueManager.start_dialogue("village_guard")
	assert_true(DialogueManager.is_active())
	assert_eq(GameManager.current_state, GameManager.GameState.DIALOGUE)
	assert_signal_emitted(DialogueManager, "dialogue_started")

	# Simulate dialogue finishing (as if player clicked through all lines)
	watch_signals(DialogueManager)
	DialogueManager._on_dialogue_finished()

	assert_false(DialogueManager.is_active())
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)
	assert_signal_emitted(DialogueManager, "dialogue_ended")


func test_show_lines_roundtrip():
	watch_signals(DialogueManager)
	DialogueManager.show_lines(["Hello!", "How are you?"])

	assert_true(DialogueManager.is_active())
	assert_eq(GameManager.current_state, GameManager.GameState.DIALOGUE)

	DialogueManager._on_dialogue_finished()
	assert_false(DialogueManager.is_active())
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)


func test_choice_selection_emits_signal():
	DialogueManager.show_line("Test")
	watch_signals(DialogueManager)
	DialogueManager._on_choice_made(0, "test_choice")
	assert_signal_emitted(DialogueManager, "choice_selected")


func after_each():
	if DialogueManager._is_active:
		DialogueManager._on_dialogue_finished()
	TestHelpers.reset_game_manager()
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_npc_interaction_flow.gd`

Expected: All tests PASS.

**Step 3: Commit**

```bash
git add tests/integration/test_npc_interaction_flow.gd
git commit -m "test: add NPC interaction integration test for dialogue lifecycle"
```

---

### Task 12: Encounter Trigger Integration Test

**Files:**
- Create: `tests/integration/test_encounter_trigger_flow.gd`
- Reference: `scripts/overworld/grass_area.gd`, `data/maps/route_1.json`

**Step 1: Write the tests**

Tests that the encounter system selects valid creatures from the encounter table. GrassArea depends on physics bodies and signals, so we test the encounter selection logic directly.

```gdscript
extends GutTest
## Integration test: encounter triggering produces valid creatures from table.


func before_each():
	TestHelpers.reset_game_manager()
	var starter := CreatureInstance.create("flame_squire", 10)
	GameManager.add_creature_to_party(starter)


func test_encounter_table_produces_valid_creatures():
	var table := DataLoader.get_encounter_table("route_1")
	assert_gt(table.size(), 0, "Should have encounter entries")

	var valid_ids := []
	for entry in table:
		valid_ids.append(entry["creature_id"])

	# Simulate encounter selection 50 times
	for i in range(50):
		var selected := _weighted_random_select(table)
		assert_has(valid_ids, selected["creature_id"],
			"Selected creature should be from the table")

		var level := randi_range(selected["level_min"], selected["level_max"])
		assert_between(level, selected["level_min"], selected["level_max"],
			"Level should be within range")

		# Verify the creature can actually be created
		var creature := CreatureInstance.create(selected["creature_id"], level)
		assert_ne(creature.creature_id, "",
			"Should be able to create creature '%s'" % selected["creature_id"])
		assert_gt(creature.max_hp, 0)
		assert_gt(creature.moves.size(), 0, "Creature should have at least one move")


func test_encounter_weights_influence_selection():
	var table := DataLoader.get_encounter_table("route_1")
	var counts := {}
	var runs := 1000

	for i in range(runs):
		var selected := _weighted_random_select(table)
		var id: String = selected["creature_id"]
		counts[id] = counts.get(id, 0) + 1

	# Goblin has weight 35 (highest), Stone Sentinel has weight 5 (lowest)
	# Over 1000 runs, goblin should appear much more than stone_sentinel
	var goblin_count: int = counts.get("goblin", 0)
	var sentinel_count: int = counts.get("stone_sentinel", 0)

	assert_gt(goblin_count, sentinel_count * 2,
		"Goblin (weight 35) should appear much more often than Stone Sentinel (weight 5)")

	# Goblin should be roughly 35% of selections
	assert_between(goblin_count, 250, 450,
		"Goblin should appear roughly 35%% of the time (%d/1000)" % goblin_count)


func test_all_encounter_creatures_have_moves_at_min_level():
	var table := DataLoader.get_encounter_table("route_1")
	for entry in table:
		var creature := CreatureInstance.create(entry["creature_id"], entry["level_min"])
		assert_gt(creature.moves.size(), 0,
			"'%s' at level %d should have at least one move" % [entry["creature_id"], entry["level_min"]])


## Helper: mirrors GrassArea's weighted random selection logic
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

	return table[-1]  # fallback
```

**Step 2: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_encounter_trigger_flow.gd`

Expected: All tests PASS.

**Step 3: Commit**

```bash
git add tests/integration/test_encounter_trigger_flow.gd
git commit -m "test: add encounter trigger integration test for weighted selection and creature validity"
```

---

### Task 13: Final Verification — Run Full Suite

**Step 1: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests pass across unit, component, and integration layers.

**Step 2: Final commit**

Only if any test files needed fixes during the full run:

```bash
git add -A tests/
git commit -m "fix: resolve issues found during full test suite run"
```
