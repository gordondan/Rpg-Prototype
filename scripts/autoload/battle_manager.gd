extends Node
## Manages transitioning in and out of battles.
## Autoloaded as "BattleManager".

const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")
const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"

signal battle_started()
signal battle_finished(result: String)


func start_wild_battle(encounter_table_id: String, enemy_count: int = 1) -> void:
	## Initiate a hostile encounter with 1-3 random creatures from the encounter table.
	var team_data := GameManager.get_battle_team(3)
	var player_active: Array = team_data["active"]
	var reserves: Array = team_data["reserves"]

	if player_active.is_empty():
		push_error("No alive allies in company!")
		return

	# Roll enemies from the encounter table
	var enemy_team: Array = []
	var encounters: Array = DataLoader.get_encounter_table(encounter_table_id)
	if encounters.is_empty():
		push_warning("No encounter table found for: %s" % encounter_table_id)
		return

	for i in range(enemy_count):
		var creature := _roll_encounter(encounters)
		if creature:
			enemy_team.append(creature)

	if enemy_team.is_empty():
		return

	GameManager.set_state(GameManager.GameState.BATTLE)
	battle_started.emit()

	_launch_battle(player_active, enemy_team, true, reserves)


func start_wild_battle_single(creature_id: String, level: int) -> void:
	## Legacy helper — start a wild battle with a specific single creature.
	var team_data := GameManager.get_battle_team(3)
	var player_active: Array = team_data["active"]
	var reserves: Array = team_data["reserves"]

	if player_active.is_empty():
		push_error("No alive allies in company!")
		return

	var wild_creature := CreatureInstance.create(creature_id, level)
	var enemy_team: Array = [wild_creature]

	GameManager.set_state(GameManager.GameState.BATTLE)
	battle_started.emit()

	_launch_battle(player_active, enemy_team, true, reserves)


func start_wild_battle_with_ids(enemy_defs: Array) -> void:
	## Start a wild battle with a specific list of creatures by ID and level.
	## enemy_defs: Array of {creature_id, level} dicts.
	var team_data := GameManager.get_battle_team(3)
	var player_active: Array = team_data["active"]
	var reserves: Array = team_data["reserves"]

	if player_active.is_empty():
		push_error("No alive allies in company!")
		return

	var enemy_team: Array = []
	for def in enemy_defs:
		var creature := CreatureInstance.create(def["creature_id"], int(def["level"]))
		if creature:
			enemy_team.append(creature)

	if enemy_team.is_empty():
		return

	GameManager.set_state(GameManager.GameState.BATTLE)
	battle_started.emit()
	_launch_battle(player_active, enemy_team, true, reserves)


func start_rival_battle(enemy_creatures: Array, enemy_reserves: Array = []) -> void:
	## Duel with an NPC rival or boss — can't retreat.
	var team_data := GameManager.get_battle_team(3)
	var player_active: Array = team_data["active"]
	var reserves: Array = team_data["reserves"]

	if player_active.is_empty():
		return

	GameManager.set_state(GameManager.GameState.BATTLE)
	battle_started.emit()

	_launch_battle(player_active, enemy_creatures, false, reserves, enemy_reserves)


func _launch_battle(player_active: Array, enemy_team: Array,
		is_wild: bool, reserves: Array, enemy_reserves: Array = []) -> void:
	var battle_scene = load(BATTLE_SCENE_PATH)
	if not battle_scene:
		push_error("[BattleManager] Could not load battle scene: %s" % BATTLE_SCENE_PATH)
		return

	var current := get_tree().current_scene
	if not is_instance_valid(current):
		push_error("[BattleManager] current_scene is invalid — cannot launch battle")
		return

	var instance: Node = battle_scene.instantiate()
	current.add_child(instance)

	if instance.has_method("setup_battle"):
		instance.call("setup_battle", player_active, enemy_team, is_wild, reserves, enemy_reserves)
	else:
		push_error("[BattleManager] setup_battle method NOT FOUND — script likely failed to load!")


func _roll_encounter(encounters: Array) -> CreatureInstance:
	## Roll a single random creature from an encounter table.
	var total_weight := 0.0
	for entry in encounters:
		total_weight += entry.get("weight", 1.0)

	var roll := randf() * total_weight
	var cumulative := 0.0

	for entry in encounters:
		cumulative += entry.get("weight", 1.0)
		if roll <= cumulative:
			var creature_id: String = entry["creature_id"]
			var level_min: int = entry.get("level_min", 2)
			var level_max: int = entry.get("level_max", 5)
			var level := randi_range(level_min, level_max)
			return CreatureInstance.create(creature_id, level)

	return null


func end_battle(result: String) -> void:
	## Called by the battle scene when the battle is over.
	GameManager.return_from_battle()
	battle_finished.emit(result)
	print("[BattleManager] Battle ended: %s" % result)

	if result == "lose":
		_handle_party_wipe()


func _handle_party_wipe() -> void:
	## Revive the party at the tavern after a loss.
	# Heal the whole party back to full
	GameManager.heal_all_party()

	# Lose some gold as a penalty
	var gold_lost: int = max(1, GameManager.gold / 10)
	GameManager.gold -= gold_lost
	print("[BattleManager] Lost %d gold. Remaining: %d" % [gold_lost, GameManager.gold])

	# Move the player to the road near the tavern (not inside its collision)
	var tavern_respawn := Vector2(13, 13) * 16 + Vector2(8, 8)  # On the road south of tavern
	var player := _find_player()
	if player:
		player.position = tavern_respawn

	# Show a revival message via dialogue
	await get_tree().create_timer(0.5).timeout
	DialogueManager.show_lines([
		{"text": "You were carried back to the tavern after being defeated...", "speaker": ""},
		{"text": "You're lucky I was able to patch you up. Now get back out there!", "speaker": "Tavern Keeper"},
		{"text": "The tavern keeper charged you for rescue expenses.", "speaker": ""},
		{"text": "-%d gold" % gold_lost, "speaker": ""},
	])


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
