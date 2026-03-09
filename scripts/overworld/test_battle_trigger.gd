extends Node
## Temporary test script for triggering battles and dialogue.
## B = random battle | 1-4 = test different NPC dialogues | Space = talk to NPCs
## Remove this once you have proper NPCs and encounter zones.

var _test_dialogues := ["village_guard", "old_scholar", "tavern_keeper", "mysterious_stranger"]


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_player_free():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				_start_test_battle()
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

	# Random 1-3 enemies (60% chance of 1, 30% chance of 2, 10% chance of 3)
	var roll := randf()
	var enemy_count := 1
	if roll < 0.1:
		enemy_count = 3
	elif roll < 0.4:
		enemy_count = 2
	BattleManager.start_wild_battle("route_1", enemy_count)
