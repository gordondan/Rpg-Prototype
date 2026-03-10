extends Node
## Global game state manager — handles scene transitions, player party, and save/load.
## Autoloaded as "GameManager".

const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")

enum GameState { OVERWORLD, BATTLE, MENU, DIALOGUE, CUTSCENE }

signal game_state_changed(new_state: GameState)

var current_state: GameState = GameState.OVERWORLD

# Player's active company (up to 6: first 3 active in battle, rest are reserves)
# Note: untyped to avoid Godot 4 typed-array issues with script-defined classes
var player_party: Array = []

# Barracks — all recruited creatures not currently in the party
var barracks: Array = []

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

	var second := CreatureInstance.create("grove_druid", 4)
	second.nickname = "Grove Druid"
	player_party.append(second)

	var third := CreatureInstance.create("tide_cleric", 5)
	third.nickname = "Tide Cleric"
	player_party.append(third)

	for c in player_party:
		print("[GameManager] Debug party: %s (Lv.%d)" % [c.nickname, c.level])
	for c in barracks:
		print("[GameManager] Debug barracks: %s (Lv.%d)" % [c.nickname, c.level])


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


func get_battle_team(max_active: int = 3) -> Dictionary:
	## Returns {"active": Array, "reserves": Array} of CreatureInstance objects.
	## Active team is the first N alive creatures, reserves are the rest.
	## Note: Uses untyped arrays to avoid Godot 4 typed-array-through-Dictionary issues.
	var active: Array = []
	var reserves: Array = []

	for creature in player_party:
		if creature.is_fainted():
			continue
		if active.size() < max_active:
			active.append(creature)
		else:
			reserves.append(creature)

	return {"active": active, "reserves": reserves}


func add_creature_to_party(creature: CreatureInstance) -> bool:
	## Add a creature to the party if there's room, otherwise send to barracks.
	if player_party.size() < 6:
		player_party.append(creature)
		return true
	# Party full — send to barracks automatically
	barracks.append(creature)
	return false


func move_to_barracks(party_index: int) -> bool:
	## Move a creature from the party to the barracks.
	## Fails if it would leave the party empty.
	if player_party.size() <= 1:
		return false
	if party_index < 0 or party_index >= player_party.size():
		return false
	var creature = player_party[party_index]
	player_party.remove_at(party_index)
	barracks.append(creature)
	return true


func move_to_party(barracks_index: int) -> bool:
	## Move a creature from the barracks to the party.
	## Fails if party is already full (6).
	if player_party.size() >= 6:
		return false
	if barracks_index < 0 or barracks_index >= barracks.size():
		return false
	var creature = barracks[barracks_index]
	barracks.remove_at(barracks_index)
	player_party.append(creature)
	return true


func swap_party_positions(index_a: int, index_b: int) -> void:
	## Swap two creatures' positions within the party (reorder active/reserve).
	if index_a < 0 or index_a >= player_party.size():
		return
	if index_b < 0 or index_b >= player_party.size():
		return
	var temp = player_party[index_a]
	player_party[index_a] = player_party[index_b]
	player_party[index_b] = temp


func heal_all_party() -> void:
	for creature in player_party:
		creature.full_heal()


# ─── Inventory ───────────────────────────────────────────────────

func add_item(item_id: String, quantity: int = 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + quantity
	print("[GameManager] Added %dx %s (total: %d)" % [quantity, item_id, inventory[item_id]])


func remove_item(item_id: String, quantity: int = 1) -> bool:
	if inventory.get(item_id, 0) < quantity:
		return false
	inventory[item_id] -= quantity
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true


func has_item(item_id: String, quantity: int = 1) -> bool:
	return inventory.get(item_id, 0) >= quantity


func use_item(item_id: String, creature) -> bool:
	## Use an item on a creature. Returns true if the item was successfully used.
	var item_data: Dictionary = DataLoader.get_item_data(item_id)
	if item_data.is_empty():
		push_warning("[GameManager] Unknown item: %s" % item_id)
		return false

	var effect: Dictionary = item_data.get("effect", {})
	var used := false

	match effect.get("type", ""):
		"heal_hp":
			if not creature.is_fainted():
				var amount: int = effect.get("amount", 0)
				creature.current_hp = min(creature.current_hp + amount, creature.max_hp)
				used = true
		"full_heal":
			if not creature.is_fainted():
				creature.current_hp = creature.max_hp
				used = true
		"revive":
			if creature.is_fainted():
				creature.current_hp = creature.max_hp / 2
				used = true

	if used:
		remove_item(item_id)
		print("[GameManager] Used %s on %s" % [item_id, creature.nickname])

	return used


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
		"party": _serialize_creatures(player_party),
		"barracks": _serialize_creatures(barracks),
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
	gold = int(data.get("gold", 500))
	guild_ranks.clear()
	for rank in data.get("guild_ranks", []):
		guild_ranks.append(String(rank))
	story_flags = data.get("story_flags", {})
	inventory = data.get("inventory", {})

	# Restore party
	player_party.clear()
	for creature_data in data.get("party", []):
		player_party.append(_deserialize_creature(creature_data))

	# Restore barracks
	barracks.clear()
	for creature_data in data.get("barracks", []):
		barracks.append(_deserialize_creature(creature_data))

	print("[GameManager] Game loaded from %s" % path)
	return true


func _serialize_creatures(creatures: Array) -> Array:
	var result := []
	for creature in creatures:
		result.append({
			"creature_id": creature.creature_id,
			"nickname": creature.nickname,
			"level": creature.level,
			"current_hp": creature.current_hp,
			"experience": creature.experience,
		})
	return result


func _deserialize_creature(creature_data: Dictionary) -> CreatureInstance:
	var creature := CreatureInstance.create(
		creature_data["creature_id"],
		int(creature_data["level"])
	)
	creature.nickname = creature_data.get("nickname", creature.nickname)
	creature.current_hp = int(creature_data.get("current_hp", creature.max_hp))
	creature.experience = int(creature_data.get("experience", 0))
	return creature
