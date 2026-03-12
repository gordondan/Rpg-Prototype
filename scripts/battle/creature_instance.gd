extends Resource
class_name CreatureInstance
## A living instance of a creature — holds current HP, level, stats, and known moves.
## This is what exists in the player's party or as a wild encounter.

var creature_id: String
var nickname: String
var level: int
var experience: int

# Base stats from data definition
var base_hp: int
var base_attack: int
var base_defense: int
var base_sp_attack: int
var base_sp_defense: int
var base_speed: int

# Calculated stats (based on level + base stats)
var max_hp: int
var attack: int
var defense: int
var sp_attack: int
var sp_defense: int
var speed: int

# Current battle state
var current_hp: int
var status_effect: String = ""  # "poison", "burn", "sleep", "paralysis", "freeze", ""
var status_turns: int = 0

# Type(s)
var types: Array[String] = []

# Known moves (max 4)
var moves: Array[Dictionary] = []  # [{id, current_pp, max_pp}]


static func create(id: String, lvl: int) -> CreatureInstance:
	## Factory method: create a creature instance from data definitions.
	var instance: CreatureInstance = load("res://scripts/battle/creature_instance.gd").new()
	var data: Dictionary = DataLoader.get_creature_data(id)

	if data.is_empty():
		push_error("Creature data not found for: %s" % id)
		return instance

	instance.creature_id = id
	instance.nickname = data.get("name", id)
	instance.level = lvl
	instance.experience = 0

	instance.base_hp = data.get("base_hp", 45)
	instance.base_attack = data.get("base_attack", 49)
	instance.base_defense = data.get("base_defense", 49)
	instance.base_sp_attack = data.get("base_sp_attack", 65)
	instance.base_sp_defense = data.get("base_sp_defense", 65)
	instance.base_speed = data.get("base_speed", 45)

	var raw_types: Array = data.get("types", ["normal"])
	instance.types.clear()
	for t in raw_types:
		instance.types.append(String(t))

	instance._calculate_stats()
	instance.current_hp = instance.max_hp

	# Learn moves up to this level
	instance._learn_moves_for_level(data.get("learnset", []))

	return instance


func _calculate_stats() -> void:
	## Simplified stat formula inspired by Pokémon (without IVs/EVs for now).
	## Formula: ((2 * base + 31) * level / 100) + 5
	## HP formula: ((2 * base + 31) * level / 100) + level + 10
	max_hp = int(((2.0 * base_hp + 31.0) * level / 100.0) + level + 10)
	attack = int(((2.0 * base_attack + 31.0) * level / 100.0) + 5)
	defense = int(((2.0 * base_defense + 31.0) * level / 100.0) + 5)
	sp_attack = int(((2.0 * base_sp_attack + 31.0) * level / 100.0) + 5)
	sp_defense = int(((2.0 * base_sp_defense + 31.0) * level / 100.0) + 5)
	speed = int(((2.0 * base_speed + 31.0) * level / 100.0) + 5)


func _learn_moves_for_level(learnset: Array) -> void:
	## Populate the move list with moves the creature would know at this level.
	## Takes the last 4 moves it would have learned.
	var learnable: Array = []
	for entry in learnset:
		if entry.get("level", 1) <= level:
			learnable.append(entry)

	# Take the last 4
	var start_idx: int = max(0, learnable.size() - 4)
	for i in range(start_idx, learnable.size()):
		var move_data = DataLoader.get_move_data(learnable[i]["move_id"])
		if not move_data.is_empty():
			moves.append({
				"id": learnable[i]["move_id"],
				"current_pp": move_data.get("pp", 10),
				"max_pp": move_data.get("pp", 10)
			})


func is_fainted() -> bool:
	return current_hp <= 0


func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)


func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)


func full_heal() -> void:
	current_hp = max_hp
	status_effect = ""
	status_turns = 0
	for m in moves:
		m["current_pp"] = m["max_pp"]


const MAX_LEVEL := 100

func gain_experience(amount: int) -> bool:
	## Add experience and return true if the creature leveled up.
	if level >= MAX_LEVEL:
		return false

	experience += amount
	var needed := _exp_for_next_level()

	if experience >= needed:
		experience -= needed
		level = min(level + 1, MAX_LEVEL)
		var old_max_hp := max_hp
		_calculate_stats()
		# Heal by the amount max_hp increased
		current_hp += max_hp - old_max_hp
		return true

	return false


func _exp_for_next_level() -> int:
	## Medium-fast experience curve.
	return int(pow(level + 1, 3))


func level_up() -> void:
	## Directly increment level, recalculate stats, learn any new moves, and restore HP.
	if level >= MAX_LEVEL:
		return
	level += 1
	var old_max_hp := max_hp
	_calculate_stats()
	current_hp += max_hp - old_max_hp  # Heal by the HP increase
	experience = 0  # Reset XP within the new level

	# Learn any move unlocked at this exact level
	var data: Dictionary = DataLoader.get_creature_data(creature_id)
	for entry in data.get("learnset", []):
		if entry.get("level", 0) == level and moves.size() < 4:
			var move_data: Dictionary = DataLoader.get_move_data(entry["move_id"])
			if not move_data.is_empty():
				var already_known := false
				for m in moves:
					if m["id"] == entry["move_id"]:
						already_known = true
						break
				if not already_known:
					moves.append({
						"id": entry["move_id"],
						"current_pp": move_data.get("pp", 10),
						"max_pp": move_data.get("pp", 10)
					})
