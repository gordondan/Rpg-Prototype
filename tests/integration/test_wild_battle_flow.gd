extends GutTest
## Integration test: Wild battle flow — tests BattleStateMachine + CreatureInstance + BattleCalculator
## working together to simulate a full battle lifecycle, including EXP gain and state restoration.
##
## NOTE: We cannot use BattleManager.start_wild_battle() in headless mode because
## get_tree().current_scene is null. Instead we manually wire the components.

var _bsm: BattleStateMachine


func before_each():
	TestHelpers.reset_game_manager()
	_bsm = BattleStateMachine.new()
	add_child_autoqfree(_bsm)


func _wait_for_state(state: BattleStateMachine.BattleState, timeout_sec: float = 15.0) -> bool:
	var start := Time.get_ticks_msec()
	while _bsm.current_state != state:
		if (Time.get_ticks_msec() - start) / 1000.0 > timeout_sec:
			return false
		await wait_for_signal(_bsm.state_changed, timeout_sec)
	return true


func _wait_for_any_state(states: Array, timeout_sec: float = 15.0) -> bool:
	var start := Time.get_ticks_msec()
	while not _bsm.current_state in states:
		if (Time.get_ticks_msec() - start) / 1000.0 > timeout_sec:
			return false
		await wait_for_signal(_bsm.state_changed, timeout_sec)
	return true


# ---------------------------------------------------------------------------
# Test: Full battle flow ending in a WIN — player defeats a weak enemy
# ---------------------------------------------------------------------------
func test_full_battle_player_wins():
	# Create a strong player creature
	var player_creature := TestHelpers.make_creature({
		"creature_id": "flame_squire", "nickname": "Hero",
		"level": 10, "types": ["fire"],
		"speed": 100, "max_hp": 200, "current_hp": 200,
		"attack": 80, "defense": 50, "sp_attack": 80, "sp_defense": 50,
		"moves": [
			{"id": "sword_strike", "current_pp": 35, "max_pp": 35},
		],
	})

	# Create a weak enemy that will be one-shot
	var enemy_creature := TestHelpers.make_creature({
		"creature_id": "goblin", "nickname": "Goblin",
		"level": 2, "types": ["poison"],
		"speed": 5, "max_hp": 8, "current_hp": 8,
		"attack": 8, "defense": 5, "sp_attack": 5, "sp_defense": 5,
		"moves": [
			{"id": "dagger_jab", "current_pp": 35, "max_pp": 35},
		],
	})

	var exp_before := player_creature.experience

	watch_signals(_bsm)

	# Start the battle
	_bsm.start_battle([player_creature], [enemy_creature], true)

	# Wait for PLAYER_SELECT (player is faster)
	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	# Player attacks with sword_strike targeting enemy index 0
	_bsm.select_fight(0, 0)

	# Wait for battle_ended signal directly
	await wait_for_signal(_bsm.battle_ended, 20.0)

	# Verify win
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.WIN,
		"State should be WIN")
	assert_signal_emitted_with_parameters(_bsm, "battle_ended", ["win"])

	# Verify enemy is fainted
	assert_true(enemy_creature.is_fainted(), "Enemy should be fainted after being defeated")

	# Verify EXP was gained
	assert_signal_emitted(_bsm, "exp_gained")

	# Player should have more exp now (or leveled up, resetting exp)
	var gained_exp: bool = player_creature.experience > exp_before or player_creature.level > 10
	assert_true(gained_exp, "Player creature should have gained experience")


# ---------------------------------------------------------------------------
# Test: Full battle flow ending in a LOSE — enemy defeats the player
# ---------------------------------------------------------------------------
func test_full_battle_player_loses():
	# Create a weak player creature that will be one-shot
	var player_creature := TestHelpers.make_creature({
		"creature_id": "flame_squire", "nickname": "Hero",
		"level": 2, "types": ["fire"],
		"speed": 1, "max_hp": 8, "current_hp": 1,
		"attack": 5, "defense": 3, "sp_attack": 5, "sp_defense": 3,
		"moves": [
			{"id": "sword_strike", "current_pp": 35, "max_pp": 35},
		],
	})

	# Create a strong enemy that goes first and one-shots the player
	var enemy_creature := TestHelpers.make_creature({
		"creature_id": "goblin", "nickname": "Boss Goblin",
		"level": 20, "types": ["poison"],
		"speed": 200, "max_hp": 300, "current_hp": 300,
		"attack": 150, "defense": 50, "sp_attack": 50, "sp_defense": 50,
		"moves": [
			{"id": "dagger_jab", "current_pp": 35, "max_pp": 35},
		],
	})

	watch_signals(_bsm)

	# Start the battle — enemy is faster, so enemy acts first and kills player
	_bsm.start_battle([player_creature], [enemy_creature], true)

	# Wait for battle_ended signal (no player input needed; enemy kills player)
	await wait_for_signal(_bsm.battle_ended, 20.0)

	# Verify loss
	assert_signal_emitted_with_parameters(_bsm, "battle_ended", ["lose"])
	assert_eq(_bsm.current_state, BattleStateMachine.BattleState.LOSE)
	assert_true(player_creature.is_fainted(), "Player creature should be fainted")


# ---------------------------------------------------------------------------
# Test: BattleManager.end_battle() restores OVERWORLD state
# ---------------------------------------------------------------------------
func test_end_battle_restores_overworld():
	# Set up GameManager in BATTLE state
	GameManager.set_state(GameManager.GameState.BATTLE)
	assert_eq(GameManager.current_state, GameManager.GameState.BATTLE)

	# Watch for signals
	watch_signals(BattleManager)

	# Call end_battle — this should restore OVERWORLD via GameManager.return_from_battle()
	BattleManager.end_battle("win")

	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD,
		"end_battle should restore OVERWORLD state")
	assert_signal_emitted(BattleManager, "battle_finished")


# ---------------------------------------------------------------------------
# Test: EXP gain causes level up when enough EXP is earned
# ---------------------------------------------------------------------------
func test_exp_gain_can_cause_level_up():
	# Create a player at level 2 with enough exp to almost level up
	var player_creature := TestHelpers.make_creature({
		"creature_id": "flame_squire", "nickname": "Hero",
		"level": 2, "types": ["fire"],
		"speed": 100, "max_hp": 200, "current_hp": 200,
		"attack": 80, "defense": 50, "sp_attack": 80, "sp_defense": 50,
		"moves": [
			{"id": "sword_strike", "current_pp": 35, "max_pp": 35},
		],
	})
	# Set experience just below the threshold so defeating any enemy levels up
	# EXP needed for next level = (level+1)^3 = 3^3 = 27
	player_creature.experience = 20

	# Weak enemy to one-shot
	var enemy_creature := TestHelpers.make_creature({
		"creature_id": "goblin", "nickname": "Goblin",
		"level": 5, "types": ["poison"],
		"speed": 1, "max_hp": 1, "current_hp": 1,
		"attack": 5, "defense": 5, "sp_attack": 5, "sp_defense": 5,
		"moves": [
			{"id": "dagger_jab", "current_pp": 35, "max_pp": 35},
		],
	})

	# Use an Array container so the lambda can mutate the outer state
	var level_up_result: Array = [false]
	_bsm.exp_gained.connect(func(_c, _amt, did_level): level_up_result[0] = did_level)

	watch_signals(_bsm)
	_bsm.start_battle([player_creature], [enemy_creature], true)

	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	_bsm.select_fight(0, 0)

	await wait_for_signal(_bsm.battle_ended, 20.0)

	assert_eq(player_creature.level, 3, "Player should have leveled up to 3")
	assert_signal_emitted(_bsm, "exp_gained")
	assert_true(level_up_result[0], "exp_gained signal should report level up")


# ---------------------------------------------------------------------------
# Test: battle_ended signal carries the correct result string
# ---------------------------------------------------------------------------
func test_battle_ended_signal_carries_result():
	var player_creature := TestHelpers.make_creature({
		"creature_id": "flame_squire", "nickname": "Hero",
		"level": 10, "types": ["fire"],
		"speed": 100, "max_hp": 200, "current_hp": 200,
		"attack": 80, "defense": 50, "sp_attack": 80, "sp_defense": 50,
		"moves": [
			{"id": "sword_strike", "current_pp": 35, "max_pp": 35},
		],
	})

	var enemy_creature := TestHelpers.make_creature({
		"creature_id": "goblin", "nickname": "Goblin",
		"level": 2, "types": ["poison"],
		"speed": 1, "max_hp": 1, "current_hp": 1,
		"attack": 5, "defense": 5, "sp_attack": 5, "sp_defense": 5,
		"moves": [
			{"id": "dagger_jab", "current_pp": 35, "max_pp": 35},
		],
	})

	watch_signals(_bsm)
	_bsm.start_battle([player_creature], [enemy_creature], true)

	var reached := await _wait_for_state(BattleStateMachine.BattleState.PLAYER_SELECT)
	if not reached:
		fail_test("Timed out waiting for PLAYER_SELECT")
		return

	_bsm.select_fight(0, 0)

	await wait_for_signal(_bsm.battle_ended, 20.0)
	assert_signal_emitted_with_parameters(_bsm, "battle_ended", ["win"])


# ---------------------------------------------------------------------------
# Test: end_battle("lose") triggers party heal via _handle_party_wipe
# ---------------------------------------------------------------------------
func test_end_battle_lose_heals_party():
	# Set up a wounded party in GameManager
	var wounded := TestHelpers.make_creature({
		"creature_id": "flame_squire", "nickname": "Wounded",
		"max_hp": 100, "current_hp": 0,
	})
	GameManager.player_party.append(wounded)
	GameManager.set_state(GameManager.GameState.BATTLE)

	# end_battle("lose") calls _handle_party_wipe which calls heal_all_party
	BattleManager.end_battle("lose")

	# heal_all_party should have restored HP
	assert_eq(wounded.current_hp, 100,
		"Party should be healed after a loss (tavern revival)")
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)
