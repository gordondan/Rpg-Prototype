extends RefCounted
class_name BattleCalculator
## Handles all damage and accuracy calculations for the battle system.
## Uses a simplified version of the Gen III damage formula.

# Preload user-defined classes to avoid class_name resolution order issues
# (Godot 4 parses scripts alphabetically; 'b' files are parsed before 'c' and 't')
const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")
const TypeChart = preload("res://scripts/battle/type_chart.gd")


static func calculate_damage(attacker: CreatureInstance, defender: CreatureInstance, move: Dictionary) -> Dictionary:
	## Calculate damage for a move. Returns a dict with damage amount and metadata.
	## move: {id, power, type, category, accuracy, pp, ...} from DataLoader

	var result := {
		"damage": 0,
		"effectiveness": 1.0,
		"effectiveness_text": "",
		"critical": false,
		"missed": false,
	}

	# Accuracy check
	var accuracy: int = move.get("accuracy", 100)
	if accuracy < 100:
		if randi() % 100 >= accuracy:
			result["missed"] = true
			return result

	var power: int = move.get("power", 0)
	if power == 0:
		# Status move — no damage
		return result

	var category: String = move.get("category", "physical")

	# Pick the right attack/defense stats
	var atk_stat: int
	var def_stat: int
	if category == "physical":
		atk_stat = attacker.attack
		def_stat = defender.defense
	else:
		atk_stat = attacker.sp_attack
		def_stat = defender.sp_defense

	# Critical hit check (Gen III: ~6.25% base rate)
	var crit_roll := randf()
	var critical := crit_roll < 0.0625
	result["critical"] = critical
	var crit_multiplier := 2.0 if critical else 1.0

	# STAB (Same Type Attack Bonus)
	var stab := 1.5 if move.get("type", "normal") in attacker.types else 1.0

	# Type effectiveness
	var type_effectiveness := TypeChart.get_effectiveness(
		move.get("type", "normal"),
		defender.types
	)
	result["effectiveness"] = type_effectiveness
	result["effectiveness_text"] = TypeChart.get_effectiveness_text(type_effectiveness)

	# Random factor (85% to 100%)
	var random_factor := randf_range(0.85, 1.0)

	# Damage formula (simplified Gen III)
	# ((2 * Level / 5 + 2) * Power * A/D) / 50 + 2) * modifiers
	var base_damage := ((2.0 * attacker.level / 5.0 + 2.0) * power * float(atk_stat) / float(def_stat)) / 50.0 + 2.0
	var final_damage := int(base_damage * crit_multiplier * stab * type_effectiveness * random_factor)

	# Minimum 1 damage (unless immune)
	if type_effectiveness > 0.0:
		final_damage = max(1, final_damage)

	result["damage"] = final_damage
	return result


static func calculate_exp_yield(defeated: CreatureInstance, is_wild: bool) -> int:
	## Calculate experience gained from defeating a creature.
	var base_exp: int = DataLoader.get_creature_data(defeated.creature_id).get("base_exp", 64)
	var trainer_bonus := 1.0 if is_wild else 1.5
	return int((base_exp * defeated.level * trainer_bonus) / 7.0)
