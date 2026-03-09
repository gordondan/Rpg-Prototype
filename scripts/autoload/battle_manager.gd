extends Node
## Manages transitioning in and out of battles.
## Autoloaded as "BattleManager".

const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"

signal battle_started()
signal battle_finished(result: String)


func start_wild_battle(creature_id: String, level: int) -> void:
	## Initiate a hostile encounter with a wandering character.
	var player_creature := GameManager.get_first_alive_creature()
	if player_creature == null:
		push_error("No alive allies in company!")
		return

	var wild_creature := CreatureInstance.create(creature_id, level)

	print("[BattleManager] Encounter: %s (Lv.%d) vs %s (Lv.%d)" % [
		player_creature.nickname, player_creature.level,
		wild_creature.nickname, wild_creature.level
	])

	GameManager.set_state(GameManager.GameState.BATTLE)
	battle_started.emit()

	# Load battle scene
	var battle_scene = load(BATTLE_SCENE_PATH)
	if battle_scene:
		var instance: Node = battle_scene.instantiate()
		get_tree().current_scene.add_child(instance)

		# If the battle scene has a setup function, call it
		if instance.has_method("setup_battle"):
			instance.setup_battle(player_creature, wild_creature, true)
	else:
		push_error("Could not load battle scene: %s" % BATTLE_SCENE_PATH)


func start_rival_battle(rival_creature_id: String, rival_level: int) -> void:
	## Duel with an NPC rival or boss — can't retreat.
	var player_creature = GameManager.get_first_alive_creature()
	if player_creature == null:
		return

	var enemy = CreatureInstance.create(rival_creature_id, rival_level)

	GameManager.set_state(GameManager.GameState.BATTLE)
	battle_started.emit()

	var battle_scene = load(BATTLE_SCENE_PATH)
	if battle_scene:
		var instance: Node = battle_scene.instantiate()
		get_tree().current_scene.add_child(instance)
		if instance.has_method("setup_battle"):
			instance.setup_battle(player_creature, enemy, false)


func end_battle(result: String) -> void:
	## Called by the battle scene when the battle is over.
	GameManager.return_from_battle()
	battle_finished.emit(result)
	print("[BattleManager] Battle ended: %s" % result)
