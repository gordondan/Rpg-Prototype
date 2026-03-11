extends RefCounted
class_name TypeChart
## Type effectiveness chart — handles all type matchup calculations.

# Effectiveness multipliers
const SUPER_EFFECTIVE := 2.0
const NOT_EFFECTIVE := 0.5
const NO_EFFECT := 0.0
const NORMAL := 1.0

# The chart is stored as: effectiveness[attacking_type][defending_type] = multiplier
# Only non-1.0 matchups are listed to save space.
static var _chart: Dictionary = {
	"fire": {
		"nature": SUPER_EFFECTIVE, "frost": SUPER_EFFECTIVE, "witch": SUPER_EFFECTIVE,
		"machine": SUPER_EFFECTIVE, "fire": NOT_EFFECTIVE, "aqua": NOT_EFFECTIVE,
		"construct": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE
	},
	"aqua": {
		"fire": SUPER_EFFECTIVE, "earth": SUPER_EFFECTIVE, "construct": SUPER_EFFECTIVE,
		"aqua": NOT_EFFECTIVE, "nature": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE
	},
	"nature": {
		"aqua": SUPER_EFFECTIVE, "earth": SUPER_EFFECTIVE, "construct": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "nature": NOT_EFFECTIVE, "poison": NOT_EFFECTIVE,
		"wind": NOT_EFFECTIVE, "witch": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE,
		"machine": NOT_EFFECTIVE
	},
	"storm": {
		"aqua": SUPER_EFFECTIVE, "wind": SUPER_EFFECTIVE,
		"storm": NOT_EFFECTIVE, "nature": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE,
		"earth": NO_EFFECT
	},
	"no_affinity": {
		"construct": NOT_EFFECTIVE, "machine": NOT_EFFECTIVE, "specter": NO_EFFECT
	},
	"warrior": {
		"no_affinity": SUPER_EFFECTIVE, "frost": SUPER_EFFECTIVE, "construct": SUPER_EFFECTIVE,
		"shadow": SUPER_EFFECTIVE, "machine": SUPER_EFFECTIVE,
		"poison": NOT_EFFECTIVE, "wind": NOT_EFFECTIVE, "arcane": NOT_EFFECTIVE,
		"witch": NOT_EFFECTIVE, "fey": NOT_EFFECTIVE, "specter": NO_EFFECT
	},
	"wind": {
		"nature": SUPER_EFFECTIVE, "warrior": SUPER_EFFECTIVE, "witch": SUPER_EFFECTIVE,
		"storm": NOT_EFFECTIVE, "construct": NOT_EFFECTIVE, "machine": NOT_EFFECTIVE
	},
	"poison": {
		"nature": SUPER_EFFECTIVE, "fey": SUPER_EFFECTIVE,
		"poison": NOT_EFFECTIVE, "earth": NOT_EFFECTIVE, "construct": NOT_EFFECTIVE,
		"specter": NOT_EFFECTIVE, "machine": NO_EFFECT
	},
	"earth": {
		"fire": SUPER_EFFECTIVE, "storm": SUPER_EFFECTIVE, "poison": SUPER_EFFECTIVE,
		"construct": SUPER_EFFECTIVE, "machine": SUPER_EFFECTIVE,
		"nature": NOT_EFFECTIVE, "witch": NOT_EFFECTIVE, "wind": NO_EFFECT
	},
	"construct": {
		"fire": SUPER_EFFECTIVE, "frost": SUPER_EFFECTIVE, "wind": SUPER_EFFECTIVE,
		"witch": SUPER_EFFECTIVE, "warrior": NOT_EFFECTIVE, "earth": NOT_EFFECTIVE,
		"machine": NOT_EFFECTIVE
	},
	"witch": {
		"nature": SUPER_EFFECTIVE, "arcane": SUPER_EFFECTIVE, "shadow": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "warrior": NOT_EFFECTIVE, "poison": NOT_EFFECTIVE,
		"wind": NOT_EFFECTIVE, "specter": NOT_EFFECTIVE, "machine": NOT_EFFECTIVE,
		"fey": NOT_EFFECTIVE
	},
	"specter": {
		"arcane": SUPER_EFFECTIVE, "specter": SUPER_EFFECTIVE,
		"shadow": NOT_EFFECTIVE, "no_affinity": NO_EFFECT
	},
	"arcane": {
		"warrior": SUPER_EFFECTIVE, "poison": SUPER_EFFECTIVE,
		"arcane": NOT_EFFECTIVE, "machine": NOT_EFFECTIVE, "shadow": NO_EFFECT
	},
	"frost": {
		"nature": SUPER_EFFECTIVE, "earth": SUPER_EFFECTIVE, "wind": SUPER_EFFECTIVE,
		"dragon": SUPER_EFFECTIVE, "fire": NOT_EFFECTIVE, "aqua": NOT_EFFECTIVE,
		"frost": NOT_EFFECTIVE, "machine": NOT_EFFECTIVE
	},
	"dragon": {
		"dragon": SUPER_EFFECTIVE, "machine": NOT_EFFECTIVE, "fey": NO_EFFECT
	},
	"shadow": {
		"arcane": SUPER_EFFECTIVE, "specter": SUPER_EFFECTIVE,
		"warrior": NOT_EFFECTIVE, "shadow": NOT_EFFECTIVE, "fey": NOT_EFFECTIVE
	},
	"machine": {
		"frost": SUPER_EFFECTIVE, "construct": SUPER_EFFECTIVE, "fey": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "aqua": NOT_EFFECTIVE, "storm": NOT_EFFECTIVE,
		"machine": NOT_EFFECTIVE
	},
	"fey": {
		"warrior": SUPER_EFFECTIVE, "dragon": SUPER_EFFECTIVE, "shadow": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "poison": NOT_EFFECTIVE, "machine": NOT_EFFECTIVE
	}
}


static func get_effectiveness(attack_type: String, defender_types: Array) -> float:
	## Calculate the combined effectiveness of an attack type against a defender's type(s).
	## For dual types, multiply the individual effectiveness values.
	var multiplier := 1.0

	for def_type in defender_types:
		var atk_type_lower: String = attack_type.to_lower()
		var def_type_lower: String = String(def_type).to_lower()

		if atk_type_lower in _chart:
			if def_type_lower in _chart[atk_type_lower]:
				multiplier *= _chart[atk_type_lower][def_type_lower]
			# else: normal effectiveness (1.0)
		# else: unknown type, treat as normal

	return multiplier


static func get_effectiveness_text(multiplier: float) -> String:
	if multiplier >= 2.0:
		return "It's super effective!"
	elif multiplier > 0.0 and multiplier < 1.0:
		return "It's not very effective..."
	elif multiplier == 0.0:
		return "It doesn't affect the target..."
	return ""
