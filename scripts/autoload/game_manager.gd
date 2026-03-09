extends Node
## Global game state manager — handles scene transitions, player party, and save/load.
## Autoloaded as "GameManager".

enum GameState { OVERWORLD, BATTLE, MENU, DIALOGUE, CUTSCENE }

signal game_state_changed(new_state: GameState)

var current_state: GameState = GameState.OVERWORLD

# Player's company (up to 6 allies)
var player_party: Array[CreatureInstance] = []

# Player inventory
var inventory: Dictionary = {}  # {item_id: quantity}

# Player info
var player_name: String = "Captain"
var gold: int = 500
var guild_ranks: Array[String] = []  # Replaces "badges" — earned from guild halls

# Story flags — tracks events, defeated trainers, etc.
var story_flags: Dictionary = {}

# Saved player position for returning from battles
var _saved_player_position: Vector2 = Vector2.ZERO
var _saved_map_path: String = ""


func _ready() -> void:
	# Give the player a starter for testing
	_setup_debug_party()


func _setup_debug_party() -> void:
	## Create a starter party for testing. Remove this once you have a proper
	## intro sequence with guild master / ally selection.
	var starter := CreatureInstance.create("flame_squire", 5)
	starter.nickname = "Flame Squire"
	player_party.append(starter)
	print("[GameManager] Debug company created: %s (Lv.%d)" % [starter.nickname, starter.level])


# ─── State Management ────────────────────────────────────────────

func set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)


func is_player_free() -> bool:
	return current_state == GameState.OVERWORLD


# ─── Party Management ────────────────────────────────────────────

func get_first_alive_creature() -> CreatureInstance:
	for creature in player_party:
		if not creature.is_fainted():
			return creature
	return null


func add_creature_to_party(creature: CreatureInstance) -> bool:
	if player_party.size() < 6:
		player_party.append(creature)
		return true
	return false  # Company is full — would need a guild hall / barracks


func heal_all_party() -> void:
	for creature in player_party:
		creature.full_heal()


func is_party_wiped() -> bool:
	for creature in player_party:
		if not creature.is_fainted():
			return false
	return true


# ─── Story Flags ─────────────────────────────────────────────────

func set_flag(flag_name: String, value: bool = true) -> void:
	story_flags[flag_name] = value


func get_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)


# ─── Scene Transitions ───────────────────────────────────────────

func transition_to_battle(player_pos: Vector2, map_path: String) -> void:
	_saved_player_position = player_pos
	_saved_map_path = map_path
	set_state(GameState.BATTLE)


func return_from_battle() -> void:
	set_state(GameState.OVERWORLD)


# ─── Save / Load (basic) ─────────────────────────────────────────

func save_game(slot: int = 0) -> void:
	var save_data := {
		"player_name": player_name,
		"gold": gold,
		"guild_ranks": guild_ranks,
		"story_flags": story_flags,
		"party": _serialize_party(),
		"inventory": inventory,
		"position": {"x": _saved_player_position.x, "y": _saved_player_position.y},
		"map": _saved_map_path,
	}

	var path := "user://save_%d.json" % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	print("[GameManager] Game saved to %s" % path)


func load_game(slot: int = 0) -> bool:
	var path := "user://save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false

	var data: Dictionary = json.data
	player_name = data.get("player_name", "Captain")
	gold = data.get("gold", 500)
	guild_ranks = data.get("guild_ranks", [])
	story_flags = data.get("story_flags", {})
	inventory = data.get("inventory", {})

	# Restore party
	player_party.clear()
	for creature_data in data.get("party", []):
		var creature := CreatureInstance.create(
			creature_data["creature_id"],
			creature_data["level"]
		)
		creature.nickname = creature_data.get("nickname", creature.nickname)
		creature.current_hp = creature_data.get("current_hp", creature.max_hp)
		creature.experience = creature_data.get("experience", 0)
		player_party.append(creature)

	print("[GameManager] Game loaded from %s" % path)
	return true


func _serialize_party() -> Array:
	var result := []
	for creature in player_party:
		result.append({
			"creature_id": creature.creature_id,
			"nickname": creature.nickname,
			"level": creature.level,
			"current_hp": creature.current_hp,
			"experience": creature.experience,
		})
	return result
