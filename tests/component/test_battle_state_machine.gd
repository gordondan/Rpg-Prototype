extends GutTest
## Component tests for BattleStateMachine — state transitions, signals, battle flow.

var _bsm: BattleStateMachine
var _player: CreatureInstance
var _enemy: CreatureInstance


func before_each():
	_bsm = BattleStateMachine.new()
	add_child_autoqfree(_bsm)

	_player = TestHelpers.make_creature({
		"creature_id": "flame_squire", "nickname": "Player",
		"level": 10, "types": ["fire"],
		"speed": 50, "max_hp": 100, "current_hp": 100,
		"attack": 30, "defense": 18, "sp_attack": 30, "sp_defense": 18,
		"moves": [
			{"id": "sword_strike", "current_pp": 35, "max_pp": 35},
			{"id": "fire_bolt", "current_pp": 25, "max_pp": 25},
		],
	})

	_enemy = TestHelpers.make_creature({
		"creature_id": "goblin", "nickname": "Enemy",
		"level": 3, "types": ["poison"],
		"speed": 5, "max_hp": 10, "current_hp": 10,
		"attack": 10, "defense": 7, "sp_attack": 7, "sp_defense": 7,
		"moves": [
			{"id": "dagger_jab", "current_pp": 35, "max_pp": 35},
		],
	})


func _wait_for_state(state: BattleStateMachine.BattleState, timeout_sec: float = 10.0) -> bool:
	## Helper: wait until BSM reaches the given state, or timeout.
	var start := Time.get_ticks_msec()
	while _bsm.current_state != state:
		if (Time.get_ticks_msec() - start) / 1000.0 > timeout_sec:
			return false
		await wait_for_signal(_bsm.state_changed, timeout_sec)
	return true


func _wait_for_any_state(states: Array, timeout_sec: float = 10.0) -> bool:
	## Helper: wait until BSM reaches any of the given states, or timeout.
	var start := Time.get_ticks_msec()
	while not _bsm.current_state in states:
		if (Time.get_ticks_msec() - start) / 1000.0 > timeout_sec:
			return false
		await wait_for_signal(_bsm.state_changed, timeout_sec)
	return true


func test_initial_state_is_intro():
	watch_signals(_bsm)
	_bsm.start_battle([_player], [_enemy], true)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.INTRO)


func test_transitions_to_player_select():
	watch_signals(_bsm)
	_bsm.start_battle([_player], [_enemy], true)
	# start_battle awaits 1.5s timer then moves to TURN_START -> PLAYER_SELECT
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.PLAYER_SELECT)


func test_battle_message_emits_on_intro():
	watch_signals(_bsm)
	_bsm.start_battle([_player], [_enemy], true)
	assert_signal_emitted(_bsm, "battle_message")


func test_select_fight_only_in_player_select():
	_bsm.start_battle([_player], [_enemy], true)
	# Still in INTRO — select_fight should do nothing (_waiting_for_player is false)
	_bsm.select_fight(0, 0)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.INTRO,
		"Should not change state when not in PLAYER_SELECT")


func test_player_goes_first_when_faster():
	# Player speed 50 >> enemy speed 5, so player should get PLAYER_SELECT first.
	# The fact that we reach PLAYER_SELECT before any EXECUTE_ACTION proves
	# the player is first in the turn order.
	var states_seen: Array = []
	_bsm.state_changed.connect(func(s): states_seen.append(s))

	_bsm.start_battle([_player], [_enemy], true)
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	# Verify PLAYER_SELECT came before any EXECUTE_ACTION — meaning the player
	# was first in the turn order (enemy would have caused EXECUTE_ACTION first).
	var select_idx := states_seen.find(BattleStateMachine.BattleState.PLAYER_SELECT)
	var execute_idx := states_seen.find(BattleStateMachine.BattleState.EXECUTE_ACTION)
	if execute_idx == -1:
		# No EXECUTE_ACTION yet at all — player was definitely first
		assert_true(true, "Player acted first (no EXECUTE_ACTION before PLAYER_SELECT)")
	else:
		assert_lt(select_idx, execute_idx,
			"PLAYER_SELECT should come before EXECUTE_ACTION when player is faster")


func test_defeating_enemy_emits_win():
	_enemy.current_hp = 1

	_bsm.start_battle([_player], [_enemy], true)
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	watch_signals(_bsm)
	_bsm.select_fight(0, 0)

	await wait_for_signal(_bsm.battle_ended, 15.0)
	assert_signal_emitted(_bsm, "battle_ended")
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.WIN)


func test_player_fainting_emits_lose():
	_player.current_hp = 1
	_player.speed = 1
	_enemy.speed = 100
	_enemy.attack = 100

	# Enemy is faster (100 vs 1), so enemy acts first in turn order.
	# Enemy attack=100 vs player HP=1, so the enemy will one-shot the player
	# before the player ever gets a PLAYER_SELECT. The battle should go
	# directly to LOSE without player input.
	watch_signals(_bsm)
	_bsm.start_battle([_player], [_enemy], true)

	await wait_for_signal(_bsm.battle_ended, 20.0)
	assert_signal_emitted(_bsm, "battle_ended")
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.LOSE)


func test_cannot_run_from_trainer_battle():
	watch_signals(_bsm)
	_bsm.start_battle([_player], [_enemy], false)  # not wild
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	_bsm.select_run()
	# _attempt_escape for non-wild: emits message, waits 1s, then sets
	# _waiting_for_player = true and emits request_player_action
	# State stays at PLAYER_SELECT (set earlier; _attempt_escape doesn't change it for non-wild)
	await wait_for_signal(_bsm.request_player_action, 5.0)
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.PLAYER_SELECT,
		"Should return to PLAYER_SELECT after failed run from trainer battle")


func test_exp_gained_on_win():
	_enemy.current_hp = 1
	_bsm.start_battle([_player], [_enemy], true)
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	watch_signals(_bsm)
	_bsm.select_fight(0, 0)

	await wait_for_signal(_bsm.exp_gained, 15.0)
	assert_signal_emitted(_bsm, "exp_gained")


func test_poison_deals_damage_at_end_of_turn():
	_player.status_effect = "poison"
	var hp_before := _player.current_hp

	# Give enemy enough HP to survive the round so RESOLVE phase runs
	_enemy.max_hp = 999
	_enemy.current_hp = 999
	_enemy.defense = 99
	_enemy.sp_defense = 99

	_bsm.start_battle([_player], [_enemy], true)
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	_bsm.select_fight(0, 0)

	# Wait for the round to resolve and come back to PLAYER_SELECT (next round)
	# After all turns execute, _resolve_round runs poison, then starts a new round
	# which leads back to PLAYER_SELECT.
	var end_reached := await _wait_for_any_state([
		BattleStateMachine.BattleState.PLAYER_SELECT,
		BattleStateMachine.BattleState.WIN,
		BattleStateMachine.BattleState.LOSE,
	], 20.0)
	if not end_reached:
		fail_test("Timed out waiting for round to complete")
		return

	# Poison damage = max(1, max_hp / 8) = max(1, 100/8) = 12
	assert_lt(_player.current_hp, hp_before, "Poison should have reduced HP")


func test_request_player_action_emitted():
	watch_signals(_bsm)
	_bsm.start_battle([_player], [_enemy], true)
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return
	assert_signal_emitted(_bsm, "request_player_action")


func test_creature_hp_changed_on_attack():
	_bsm.start_battle([_player], [_enemy], true)
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	watch_signals(_bsm)
	_bsm.select_fight(0, 0)

	# Wait for at least one state change (the attack execution)
	await wait_for_signal(_bsm.creature_hp_changed, 10.0)
	assert_signal_emitted(_bsm, "creature_hp_changed")


func test_wild_battle_intro_message():
	var messages: Array = []
	_bsm.battle_message.connect(func(text): messages.append(text))
	_bsm.start_battle([_player], [_enemy], true)
	assert_true(messages.size() > 0, "Should emit at least one intro message")
	assert_true("Enemy" in messages[0] or "hostile" in messages[0],
		"Wild battle intro should mention the enemy")


func test_trainer_battle_intro_message():
	var messages: Array = []
	_bsm.battle_message.connect(func(text): messages.append(text))
	_bsm.start_battle([_player], [_enemy], false)
	assert_true(messages.size() > 0, "Should emit at least one intro message")
	assert_true("commanders" in messages[0] or "warriors" in messages[0],
		"Trainer battle intro should mention commanders/warriors")
