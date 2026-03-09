extends RefCounted
class_name TypeChart
## Type effectiveness chart — handles all type matchup calculations.
## Mirrors the classic 18-type system.

# Effectiveness multipliers
const SUPER_EFFECTIVE := 2.0
const NOT_EFFECTIVE := 0.5
const NO_EFFECT := 0.0
const NORMAL := 1.0

# The chart is stored as: effectiveness[attacking_type][defending_type] = multiplier
# Only non-1.0 matchups are listed to save space.
static var _chart: Dictionary = {
	"fire": {
		"grass": SUPER_EFFECTIVE, "ice": SUPER_EFFECTIVE, "bug": SUPER_EFFECTIVE,
		"steel": SUPER_EFFECTIVE, "fire": NOT_EFFECTIVE, "water": NOT_EFFECTIVE,
		"rock": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE
	},
	"water": {
		"fire": SUPER_EFFECTIVE, "ground": SUPER_EFFECTIVE, "rock": SUPER_EFFECTIVE,
		"water": NOT_EFFECTIVE, "grass": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE
	},
	"grass": {
		"water": SUPER_EFFECTIVE, "ground": SUPER_EFFECTIVE, "rock": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "grass": NOT_EFFECTIVE, "poison": NOT_EFFECTIVE,
		"flying": NOT_EFFECTIVE, "bug": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE,
		"steel": NOT_EFFECTIVE
	},
	"electric": {
		"water": SUPER_EFFECTIVE, "flying": SUPER_EFFECTIVE,
		"electric": NOT_EFFECTIVE, "grass": NOT_EFFECTIVE, "dragon": NOT_EFFECTIVE,
		"ground": NO_EFFECT
	},
	"normal": {
		"rock": NOT_EFFECTIVE, "steel": NOT_EFFECTIVE, "ghost": NO_EFFECT
	},
	"fighting": {
		"normal": SUPER_EFFECTIVE, "ice": SUPER_EFFECTIVE, "rock": SUPER_EFFECTIVE,
		"dark": SUPER_EFFECTIVE, "steel": SUPER_EFFECTIVE,
		"poison": NOT_EFFECTIVE, "flying": NOT_EFFECTIVE, "psychic": NOT_EFFECTIVE,
		"bug": NOT_EFFECTIVE, "fairy": NOT_EFFECTIVE, "ghost": NO_EFFECT
	},
	"flying": {
		"grass": SUPER_EFFECTIVE, "fighting": SUPER_EFFECTIVE, "bug": SUPER_EFFECTIVE,
		"electric": NOT_EFFECTIVE, "rock": NOT_EFFECTIVE, "steel": NOT_EFFECTIVE
	},
	"poison": {
		"grass": SUPER_EFFECTIVE, "fairy": SUPER_EFFECTIVE,
		"poison": NOT_EFFECTIVE, "ground": NOT_EFFECTIVE, "rock": NOT_EFFECTIVE,
		"ghost": NOT_EFFECTIVE, "steel": NO_EFFECT
	},
	"ground": {
		"fire": SUPER_EFFECTIVE, "electric": SUPER_EFFECTIVE, "poison": SUPER_EFFECTIVE,
		"rock": SUPER_EFFECTIVE, "steel": SUPER_EFFECTIVE,
		"grass": NOT_EFFECTIVE, "bug": NOT_EFFECTIVE, "flying": NO_EFFECT
	},
	"rock": {
		"fire": SUPER_EFFECTIVE, "ice": SUPER_EFFECTIVE, "flying": SUPER_EFFECTIVE,
		"bug": SUPER_EFFECTIVE, "fighting": NOT_EFFECTIVE, "ground": NOT_EFFECTIVE,
		"steel": NOT_EFFECTIVE
	},
	"bug": {
		"grass": SUPER_EFFECTIVE, "psychic": SUPER_EFFECTIVE, "dark": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "fighting": NOT_EFFECTIVE, "poison": NOT_EFFECTIVE,
		"flying": NOT_EFFECTIVE, "ghost": NOT_EFFECTIVE, "steel": NOT_EFFECTIVE,
		"fairy": NOT_EFFECTIVE
	},
	"ghost": {
		"psychic": SUPER_EFFECTIVE, "ghost": SUPER_EFFECTIVE,
		"dark": NOT_EFFECTIVE, "normal": NO_EFFECT
	},
	"psychic": {
		"fighting": SUPER_EFFECTIVE, "poison": SUPER_EFFECTIVE,
		"psychic": NOT_EFFECTIVE, "steel": NOT_EFFECTIVE, "dark": NO_EFFECT
	},
	"ice": {
		"grass": SUPER_EFFECTIVE, "ground": SUPER_EFFECTIVE, "flying": SUPER_EFFECTIVE,
		"dragon": SUPER_EFFECTIVE, "fire": NOT_EFFECTIVE, "water": NOT_EFFECTIVE,
		"ice": NOT_EFFECTIVE, "steel": NOT_EFFECTIVE
	},
	"dragon": {
		"dragon": SUPER_EFFECTIVE, "steel": NOT_EFFECTIVE, "fairy": NO_EFFECT
	},
	"dark": {
		"psychic": SUPER_EFFECTIVE, "ghost": SUPER_EFFECTIVE,
		"fighting": NOT_EFFECTIVE, "dark": NOT_EFFECTIVE, "fairy": NOT_EFFECTIVE
	},
	"steel": {
		"ice": SUPER_EFFECTIVE, "rock": SUPER_EFFECTIVE, "fairy": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "water": NOT_EFFECTIVE, "electric": NOT_EFFECTIVE,
		"steel": NOT_EFFECTIVE
	},
	"fairy": {
		"fighting": SUPER_EFFECTIVE, "dragon": SUPER_EFFECTIVE, "dark": SUPER_EFFECTIVE,
		"fire": NOT_EFFECTIVE, "poison": NOT_EFFECTIVE, "steel": NOT_EFFECTIVE
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
