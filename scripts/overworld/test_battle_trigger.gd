extends Node
## Temporary test script for triggering battles and dialogue.
## Space = random battle | 1-4 = test different NPC dialogues
## Remove this once you have proper NPCs and encounter zones.

var _test_dialogues := ["village_guard", "old_scholar", "tavern_keeper", "mysterious_stranger"]


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_player_free():
		return

	if event.is_action_pressed("interact"):
		_start_test_battle()

	# Number keys 1-4 trigger test dialogues
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_start_test_dialogue(0)
			KEY_2:
				_start_test_dialogue(1)
			KEY_3:
				_start_test_dialogue(2)
			KEY_4:
				_start_test_dialogue(3)


func _start_test_dialogue(index: int) -> void:
	if index < 0 or index >= _test_dialogues.size():
		return
	if DialogueManager.is_active():
		return

	var id: String = _test_dialogues[index]
	print("[TEST] Starting dialogue: %s" % id)
	DialogueManager.start_dialogue(id)


func _start_test_battle() -> void:
	if DialogueManager.is_active():
		return

	var encounters: Array = DataLoader.get_encounter_table("route_1")

	if encounters.is_empty():
		print("[TEST] No encounters found in route_1 table!")
		return

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

			print("[TEST] Triggering battle with %s (Lv.%d)" % [creature_id, level])
			BattleManager.start_wild_battle(creature_id, level)
			return
