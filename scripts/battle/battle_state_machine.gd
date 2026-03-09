extends Node
class_name BattleStateMachine
## Controls the flow of a battle through states.
## States: INTRO → PLAYER_TURN → ENEMY_TURN → RESOLVE → CHECK_END → (WIN/LOSE/RUN)

enum BattleState {
	INTRO,
	PLAYER_TURN,     # Waiting for player to pick action
	PLAYER_ACTION,   # Executing player's chosen action
	ENEMY_TURN,      # AI picks and executes action
	RESOLVE,         # Apply end-of-turn effects (poison, burn, etc.)
	CHECK_END,       # Check if battle is over
	WIN,
	LOSE,
	RUN,
	RECRUIT_ATTEMPT,
}

signal state_changed(new_state: BattleState)
signal battle_message(text: String)
signal battle_ended(result: String)  # "win", "lose", "run"
signal creature_hp_changed(is_player: bool, current_hp: int, max_hp: int)
signal exp_gained(creature: CreatureInstance, amount: int, leveled_up: bool)

var current_state: BattleState = BattleState.INTRO
var player_creature: CreatureInstance
var enemy_creature: CreatureInstance
var is_wild_battle: bool = true

# Player's chosen action for this turn
var _player_action: String = ""  # "fight", "item", "switch", "run"
var _player_move_index: int = 0


func start_battle(player: CreatureInstance, enemy: CreatureInstance, wild: bool = true) -> void:
	player_creature = player
	enemy_creature = enemy
	is_wild_battle = wild
	_set_state(BattleState.INTRO)

	battle_message.emit("A hostile %s blocks your path!" % enemy_creature.nickname if wild
		else "The enemy commander sends forth %s!" % enemy_creature.nickname)

	# Small delay then move to player turn
	await get_tree().create_timer(1.5).timeout
	_set_state(BattleState.PLAYER_TURN)


func select_fight(move_index: int) -> void:
	## Called by UI when the player selects a move.
	if current_state != BattleState.PLAYER_TURN:
		return
	_player_action = "fight"
	_player_move_index = move_index
	_execute_turn()


func select_run() -> void:
	## Called by UI when the player tries to run.
	if current_state != BattleState.PLAYER_TURN:
		return
	_player_action = "run"
	_execute_turn()


func _execute_turn() -> void:
	## Determine turn order and execute both sides' actions.

	# Running always goes first
	if _player_action == "run":
		if is_wild_battle:
			var escape_chance := _calculate_escape_chance()
			if randf() < escape_chance:
				battle_message.emit("You retreated safely!")
				await get_tree().create_timer(1.0).timeout
				_set_state(BattleState.RUN)
				battle_ended.emit("run")
				return
			else:
				battle_message.emit("The enemy cuts off your retreat!")
				await get_tree().create_timer(1.0).timeout
				# Enemy still gets to attack
				await _do_enemy_turn()
				await _resolve_turn()
				return
		else:
			battle_message.emit("There's no retreating from this duel!")
			await get_tree().create_timer(1.0).timeout
			_set_state(BattleState.PLAYER_TURN)
			return

	# Speed determines who goes first
	var player_goes_first := player_creature.speed >= enemy_creature.speed

	if player_goes_first:
		await _do_player_turn()
		if not await _check_battle_end():
			await _do_enemy_turn()
	else:
		await _do_enemy_turn()
		if not await _check_battle_end():
			await _do_player_turn()

	if not await _check_battle_end():
		await _resolve_turn()


func _do_player_turn() -> void:
	_set_state(BattleState.PLAYER_ACTION)

	if player_creature.is_fainted():
		return

	var move_data := _get_move_data(player_creature, _player_move_index)
	if move_data.is_empty():
		battle_message.emit("%s has no moves left!" % player_creature.nickname)
		await get_tree().create_timer(1.0).timeout
		return

	# Deduct PP
	player_creature.moves[_player_move_index]["current_pp"] -= 1

	battle_message.emit("%s casts %s!" % [player_creature.nickname, move_data.get("name", "???")])
	await get_tree().create_timer(0.8).timeout

	var result := BattleCalculator.calculate_damage(player_creature, enemy_creature, move_data)

	if result["missed"]:
		battle_message.emit("The attack missed!")
	else:
		enemy_creature.take_damage(result["damage"])
		creature_hp_changed.emit(false, enemy_creature.current_hp, enemy_creature.max_hp)

		if result["critical"]:
			battle_message.emit("A critical hit!")
			await get_tree().create_timer(0.6).timeout

		if result["effectiveness_text"] != "":
			battle_message.emit(result["effectiveness_text"])
			await get_tree().create_timer(0.6).timeout

	await get_tree().create_timer(0.5).timeout


func _do_enemy_turn() -> void:
	_set_state(BattleState.ENEMY_TURN)

	if enemy_creature.is_fainted():
		return

	# Simple AI: pick a random move (can be improved later)
	var available_moves: Array = []
	for i in range(enemy_creature.moves.size()):
		if enemy_creature.moves[i]["current_pp"] > 0:
			available_moves.append(i)

	if available_moves.is_empty():
		battle_message.emit("%s has no moves left!" % enemy_creature.nickname)
		await get_tree().create_timer(1.0).timeout
		return

	var chosen_index: int = available_moves[randi() % available_moves.size()]
	var move_data := _get_move_data(enemy_creature, chosen_index)

	enemy_creature.moves[chosen_index]["current_pp"] -= 1

	battle_message.emit("Enemy %s unleashes %s!" % [enemy_creature.nickname, move_data.get("name", "???")])
	await get_tree().create_timer(0.8).timeout

	var result := BattleCalculator.calculate_damage(enemy_creature, player_creature, move_data)

	if result["missed"]:
		battle_message.emit("The attack missed!")
	else:
		player_creature.take_damage(result["damage"])
		creature_hp_changed.emit(true, player_creature.current_hp, player_creature.max_hp)

		if result["critical"]:
			battle_message.emit("A critical hit!")
			await get_tree().create_timer(0.6).timeout

		if result["effectiveness_text"] != "":
			battle_message.emit(result["effectiveness_text"])
			await get_tree().create_timer(0.6).timeout

	await get_tree().create_timer(0.5).timeout


func _resolve_turn() -> void:
	## Apply end-of-turn effects like poison, burn, etc.
	_set_state(BattleState.RESOLVE)

	for creature in [player_creature, enemy_creature]:
		if creature.is_fainted():
			continue

		var is_player: bool = (creature == player_creature)

		match creature.status_effect:
			"poison":
				var poison_damage: int = max(1, creature.max_hp / 8)
				creature.take_damage(poison_damage)
				creature_hp_changed.emit(is_player, creature.current_hp, creature.max_hp)
				battle_message.emit("%s is hurt by poison!" % creature.nickname)
				await get_tree().create_timer(0.8).timeout
			"burn":
				var burn_damage: int = max(1, creature.max_hp / 16)
				creature.take_damage(burn_damage)
				creature_hp_changed.emit(is_player, creature.current_hp, creature.max_hp)
				battle_message.emit("%s is hurt by its burn!" % creature.nickname)
				await get_tree().create_timer(0.8).timeout

	if not await _check_battle_end():
		_set_state(BattleState.PLAYER_TURN)


func _check_battle_end() -> bool:
	_set_state(BattleState.CHECK_END)

	if enemy_creature.is_fainted():
		battle_message.emit("Enemy %s has been defeated!" % enemy_creature.nickname)
		await get_tree().create_timer(1.0).timeout

		var exp_amount := BattleCalculator.calculate_exp_yield(enemy_creature, is_wild_battle)
		var leveled_up := player_creature.gain_experience(exp_amount)
		battle_message.emit("%s gained %d EXP!" % [player_creature.nickname, exp_amount])
		exp_gained.emit(player_creature, exp_amount, leveled_up)

		if leveled_up:
			await get_tree().create_timer(0.8).timeout
			battle_message.emit("%s has reached level %d!" % [player_creature.nickname, player_creature.level])

		await get_tree().create_timer(1.5).timeout
		_set_state(BattleState.WIN)
		battle_ended.emit("win")
		return true

	if player_creature.is_fainted():
		battle_message.emit("%s has fallen in battle!" % player_creature.nickname)
		await get_tree().create_timer(1.5).timeout
		_set_state(BattleState.LOSE)
		battle_ended.emit("lose")
		return true

	return false


func _get_move_data(creature: CreatureInstance, index: int) -> Dictionary:
	if index < 0 or index >= creature.moves.size():
		return {}
	return DataLoader.get_move_data(creature.moves[index]["id"])


func _calculate_escape_chance() -> float:
	## Simplified escape formula based on speed comparison.
	var speed_ratio: float = float(player_creature.speed) / max(1.0, float(enemy_creature.speed))
	return clamp(speed_ratio * 0.5 + 0.25, 0.2, 1.0)


func _set_state(new_state: BattleState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
