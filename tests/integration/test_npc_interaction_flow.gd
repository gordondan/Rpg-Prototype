extends GutTest
## Integration test: NPC interaction flow — tests DialogueManager + GameManager working
## together for the full dialogue lifecycle, state transitions, and choice handling.
##
## NOTE: We cannot call DialogueManager._begin_dialogue() fully because it tries to
## instantiate a scene and add it to current_scene (null in headless mode). Instead we
## test the state management and signal chain by calling internal methods directly.


func before_each():
	TestHelpers.reset_game_manager()
	# Clean up DialogueManager state
	DialogueManager._is_active = false
	if DialogueManager._dialogue_box and is_instance_valid(DialogueManager._dialogue_box):
		DialogueManager._dialogue_box.queue_free()
		DialogueManager._dialogue_box = null


func after_each():
	if DialogueManager._is_active:
		DialogueManager._is_active = false
	if DialogueManager._dialogue_box and is_instance_valid(DialogueManager._dialogue_box):
		DialogueManager._dialogue_box.queue_free()
		DialogueManager._dialogue_box = null
	TestHelpers.reset_game_manager()


# ---------------------------------------------------------------------------
# Test: start_dialogue sets GameManager state to DIALOGUE
# ---------------------------------------------------------------------------
func test_start_dialogue_sets_dialogue_state():
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD,
		"Should start in OVERWORLD")

	# start_dialogue will call _begin_dialogue which sets DIALOGUE state
	# It will fail on scene instantiation but state is set first
	DialogueManager.start_dialogue("village_guard")

	assert_eq(GameManager.current_state, GameManager.GameState.DIALOGUE,
		"GameManager should be in DIALOGUE state after starting dialogue")
	assert_true(DialogueManager.is_active(),
		"DialogueManager should be active")


# ---------------------------------------------------------------------------
# Test: _on_dialogue_finished restores OVERWORLD state
# ---------------------------------------------------------------------------
func test_dialogue_finished_restores_overworld():
	# Simulate being in dialogue state
	GameManager.set_state(GameManager.GameState.DIALOGUE)
	DialogueManager._is_active = true

	# Call the finish handler
	DialogueManager._on_dialogue_finished()

	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD,
		"Should return to OVERWORLD after dialogue finishes")
	assert_false(DialogueManager.is_active(),
		"DialogueManager should no longer be active")


# ---------------------------------------------------------------------------
# Test: Full dialogue lifecycle — start → finish restores state
# ---------------------------------------------------------------------------
func test_full_dialogue_lifecycle():
	# Verify initial state
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)
	assert_false(DialogueManager.is_active())

	# Start dialogue
	DialogueManager.start_dialogue("village_guard")
	assert_eq(GameManager.current_state, GameManager.GameState.DIALOGUE)
	assert_true(DialogueManager.is_active())

	# Finish dialogue
	DialogueManager._on_dialogue_finished()
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)
	assert_false(DialogueManager.is_active())


# ---------------------------------------------------------------------------
# Test: "rest" choice heals party through DialogueManager → GameManager
# ---------------------------------------------------------------------------
func test_rest_choice_heals_party():
	# Set up a wounded party
	var creature1 := TestHelpers.make_creature({
		"nickname": "Wounded A",
		"max_hp": 100, "current_hp": 25,
	})
	var creature2 := TestHelpers.make_creature({
		"nickname": "Wounded B",
		"max_hp": 80, "current_hp": 1,
	})
	creature2.status_effect = "poison"
	creature2.moves = [
		{"id": "sword_strike", "current_pp": 0, "max_pp": 35},
	]

	GameManager.player_party.append(creature1)
	GameManager.player_party.append(creature2)

	# Trigger the rest choice through DialogueManager
	DialogueManager._on_choice_made(0, "rest")

	# Verify healing through the full chain: DialogueManager → GameManager.heal_all_party()
	assert_eq(creature1.current_hp, 100,
		"Creature 1 should be fully healed after rest")
	assert_eq(creature2.current_hp, 80,
		"Creature 2 should be fully healed after rest")
	assert_eq(creature2.status_effect, "",
		"Status effects should be cleared after rest")
	assert_eq(creature2.moves[0]["current_pp"], 35,
		"PP should be restored after rest")


# ---------------------------------------------------------------------------
# Test: Signal chain fires in correct order: dialogue_started → game_state_changed
# ---------------------------------------------------------------------------
func test_signal_chain_order():
	var signal_order: Array = []

	DialogueManager.dialogue_started.connect(
		func(): signal_order.append("dialogue_started")
	)
	GameManager.game_state_changed.connect(
		func(_state): signal_order.append("game_state_changed")
	)

	# Start dialogue — _begin_dialogue calls:
	# 1. GameManager.set_state(DIALOGUE) → emits game_state_changed
	# 2. dialogue_started.emit()
	DialogueManager.start_dialogue("village_guard")

	assert_true(signal_order.size() >= 2,
		"At least 2 signals should have fired, got: %s" % str(signal_order))
	# game_state_changed fires first (from set_state), then dialogue_started
	assert_eq(signal_order[0], "game_state_changed",
		"game_state_changed should fire first")
	assert_eq(signal_order[1], "dialogue_started",
		"dialogue_started should fire second")

	# Clean up connections
	# (handled by after_each resetting state; signals are on autoloads so
	# we need to be careful — but GUT manages test lifecycle)


# ---------------------------------------------------------------------------
# Test: Signal chain on finish: dialogue_ended + game_state_changed
# ---------------------------------------------------------------------------
func test_finish_signal_chain():
	# Put DialogueManager in active state
	DialogueManager._is_active = true
	GameManager.set_state(GameManager.GameState.DIALOGUE)

	var signal_order: Array = []

	GameManager.game_state_changed.connect(
		func(_state): signal_order.append("game_state_changed")
	)
	DialogueManager.dialogue_ended.connect(
		func(): signal_order.append("dialogue_ended")
	)

	DialogueManager._on_dialogue_finished()

	assert_true(signal_order.size() >= 2,
		"At least 2 signals should have fired on finish")
	# _on_dialogue_finished: set_state(OVERWORLD) → game_state_changed, then dialogue_ended
	assert_eq(signal_order[0], "game_state_changed",
		"game_state_changed should fire first on finish")
	assert_eq(signal_order[1], "dialogue_ended",
		"dialogue_ended should fire second on finish")


# ---------------------------------------------------------------------------
# Test: choice_selected signal fires with the correct choice_id
# ---------------------------------------------------------------------------
func test_choice_selected_signal_carries_id():
	watch_signals(DialogueManager)
	DialogueManager._on_choice_made(2, "rest")
	assert_signal_emitted_with_parameters(DialogueManager, "choice_selected", ["rest"])


# ---------------------------------------------------------------------------
# Test: Cannot start dialogue during battle state
# ---------------------------------------------------------------------------
func test_cannot_start_dialogue_while_in_battle():
	GameManager.set_state(GameManager.GameState.BATTLE)

	# Manually set _is_active to true to simulate a conflict
	DialogueManager._is_active = true

	watch_signals(DialogueManager)
	DialogueManager.start_dialogue("village_guard")

	# The second call should be rejected because _is_active is already true
	assert_signal_not_emitted(DialogueManager, "dialogue_started")


# ---------------------------------------------------------------------------
# Test: Multiple rest choices heal correctly each time
# ---------------------------------------------------------------------------
func test_multiple_rests_heal_each_time():
	var creature := TestHelpers.make_creature({
		"nickname": "Tank",
		"max_hp": 200, "current_hp": 200,
	})
	GameManager.player_party.append(creature)

	# Damage the creature
	creature.take_damage(100)
	assert_eq(creature.current_hp, 100)

	# First rest
	DialogueManager._on_choice_made(0, "rest")
	assert_eq(creature.current_hp, 200, "First rest should heal to full")

	# Damage again
	creature.take_damage(150)
	assert_eq(creature.current_hp, 50)

	# Second rest
	DialogueManager._on_choice_made(0, "rest")
	assert_eq(creature.current_hp, 200, "Second rest should also heal to full")
