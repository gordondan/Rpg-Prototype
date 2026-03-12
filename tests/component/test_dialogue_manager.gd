extends GutTest
## Component tests for DialogueManager — dialogue state, signals, flag gating.


func before_each():
	TestHelpers.reset_game_manager()
	# Reset DialogueManager active state
	if DialogueManager._is_active:
		DialogueManager._is_active = false
	if DialogueManager._dialogue_box and is_instance_valid(DialogueManager._dialogue_box):
		DialogueManager._dialogue_box.queue_free()
		DialogueManager._dialogue_box = null


func test_initially_not_active():
	assert_false(DialogueManager.is_active())


func test_start_dialogue_sets_active():
	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("village_guard")
	assert_true(DialogueManager.is_active())


func test_start_dialogue_emits_started():
	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("village_guard")
	assert_signal_emitted(DialogueManager, "dialogue_started")


func test_start_dialogue_sets_game_state():
	DialogueManager.start_dialogue("village_guard")
	assert_eq(GameManager.current_state, GameManager.GameState.DIALOGUE)


func test_cannot_start_while_active():
	DialogueManager.start_dialogue("village_guard")
	assert_true(DialogueManager.is_active())
	# Attempting a second dialogue while one is active should be ignored
	DialogueManager.start_dialogue("old_scholar")
	assert_true(DialogueManager.is_active())


func test_flag_gated_dialogue_blocked():
	# Inject a test dialogue entry that requires a flag
	DialogueManager._dialogue_data["_test_flagged"] = {
		"name": "Test NPC",
		"requires_flag": "test_quest_done",
		"lines": [{"text": "You passed!", "speaker": "Test NPC"}],
	}
	GameManager.set_flag("test_quest_done", false)

	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("_test_flagged")
	assert_false(DialogueManager.is_active(), "Should not start when flag is unset")
	assert_signal_not_emitted(DialogueManager, "dialogue_started")

	# Clean up injected data
	DialogueManager._dialogue_data.erase("_test_flagged")


func test_flag_gated_dialogue_allowed_when_flag_set():
	# Inject a test dialogue entry that requires a flag
	DialogueManager._dialogue_data["_test_flagged2"] = {
		"name": "Test NPC",
		"requires_flag": "test_quest_done2",
		"lines": [{"text": "You passed!", "speaker": "Test NPC"}],
	}
	GameManager.set_flag("test_quest_done2", true)

	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("_test_flagged2")
	assert_true(DialogueManager.is_active(), "Should start when flag is set")
	assert_signal_emitted(DialogueManager, "dialogue_started")

	# Clean up injected data
	DialogueManager._dialogue_data.erase("_test_flagged2")


func test_invalid_dialogue_id_stays_inactive():
	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("nonexistent_dialogue_xyz")
	assert_false(DialogueManager.is_active())
	assert_signal_not_emitted(DialogueManager, "dialogue_started")


func test_get_dialogue_data():
	var data := DialogueManager.get_dialogue_data("village_guard")
	assert_false(data.is_empty(), "Should have village_guard dialogue data")
	assert_true(data.has("lines"), "Dialogue should have lines array")


func test_get_invalid_dialogue_data():
	var data := DialogueManager.get_dialogue_data("nonexistent_xyz")
	assert_true(data.is_empty())


func test_show_line_sets_active():
	watch_signals(DialogueManager)
	DialogueManager.show_line("Hello world", "Narrator")
	assert_true(DialogueManager.is_active())
	assert_signal_emitted(DialogueManager, "dialogue_started")


func test_show_lines_sets_active():
	watch_signals(DialogueManager)
	DialogueManager.show_lines(["Line 1", "Line 2"])
	assert_true(DialogueManager.is_active())


func test_show_lines_empty_stays_inactive():
	watch_signals(DialogueManager)
	DialogueManager.show_lines([])
	assert_false(DialogueManager.is_active())
	assert_signal_not_emitted(DialogueManager, "dialogue_started")


func test_choice_rest_heals_party():
	var c := TestHelpers.make_creature({"max_hp": 50, "current_hp": 10})
	GameManager.add_creature_to_party(c)
	DialogueManager._on_choice_made(0, "rest")
	assert_eq(c.current_hp, 50, "Rest choice should heal party")


func test_choice_emits_choice_selected():
	watch_signals(DialogueManager)
	DialogueManager._on_choice_made(0, "brave")
	assert_signal_emitted(DialogueManager, "choice_selected")


func test_dialogue_finished_clears_active():
	DialogueManager.start_dialogue("village_guard")
	assert_true(DialogueManager.is_active())
	DialogueManager._on_dialogue_finished()
	assert_false(DialogueManager.is_active())


func test_dialogue_finished_restores_overworld():
	DialogueManager.start_dialogue("village_guard")
	assert_eq(GameManager.current_state, GameManager.GameState.DIALOGUE)
	DialogueManager._on_dialogue_finished()
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)


func test_dialogue_finished_emits_ended():
	DialogueManager.start_dialogue("village_guard")
	watch_signals(DialogueManager)
	DialogueManager._on_dialogue_finished()
	assert_signal_emitted(DialogueManager, "dialogue_ended")


func test_dialogue_data_loaded():
	# DialogueManager loads data from res://data/dialogue/ on _ready().
	# Verify that the autoload has populated _dialogue_data.
	assert_true(DialogueManager._dialogue_data.size() > 0,
		"Dialogue data should be loaded from JSON files")


func after_each():
	if DialogueManager._is_active:
		DialogueManager._on_dialogue_finished()
	if DialogueManager._dialogue_box and is_instance_valid(DialogueManager._dialogue_box):
		DialogueManager._dialogue_box.queue_free()
		DialogueManager._dialogue_box = null
	TestHelpers.reset_game_manager()
