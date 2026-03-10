extends Node
class_name BattleStateMachine
## Controls the flow of a 3v3 battle with speed-based turn order.
## Each round, all living combatants are sorted by speed and act one at a time.

# Preload user-defined classes to avoid class_name resolution order issues
# (Godot 4 parses scripts alphabetically; 'b' files are parsed before 'c' and 't')
const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")
const BattleCalculator = preload("res://scripts/battle/battle_calculator.gd")

enum BattleState {
	INTRO,
	TURN_START,       # Beginning of a new round — build turn order
	PLAYER_SELECT,    # Waiting for player to pick action for current ally
	EXECUTE_ACTION,   # Executing one combatant's action
	RESOLVE,          # End-of-turn effects (poison, burn, etc.)
	CHECK_END,        # Check if battle is over
	WIN,
	LOSE,
	RUN,
}

signal state_changed(new_state)
signal battle_message(text)
signal battle_ended(result)  # "win", "lose", "run"
signal creature_hp_changed(is_player, index, current_hp, max_hp)
signal creature_fainted(is_player, index)
signal exp_gained(creature, amount, leveled_up)
signal request_player_action(creature, ally_index)

var current_state: BattleState = BattleState.INTRO

# Teams — up to 3 per side (untyped arrays to avoid Godot 4 typed-array issues)
var player_team: Array = []
var enemy_team: Array = []
var is_wild_battle: bool = true

# Reserve party members that can swap in when an ally falls
var player_reserves: Array = []

# Turn order for current round
var _turn_order: Array = []  # Array of {creature, is_player, index}
var _current_turn_idx: int = 0

# Current actor's chosen action
var _pending_action: String = ""
var _pending_move_index: int = 0
var _pending_target_index: int = 0
var _waiting_for_player := false


func start_battle(players: Array, enemies: Array,
		wild: bool, reserves: Array = []) -> void:
	player_team = players
	enemy_team = enemies
	is_wild_battle = wild
	player_reserves = reserves
	_set_state(BattleState.INTRO)

	# Intro messages
	if wild:
		var names := []
		for e in enemy_team:
			names.append(e.nickname)
		if names.size() == 1:
			battle_message.emit("A hostile %s blocks your path!" % names[0])
		else:
			battle_message.emit("A group of enemies blocks your path!")
	else:
		battle_message.emit("The enemy commanders send forth their warriors!")

	await get_tree().create_timer(2.0).timeout
	_start_new_round()


# --- Player input ---

func select_fight(move_index: int, target_index: int) -> void:
	## Called by UI when the player selects a move and target.
	if not _waiting_for_player:
		return
	_pending_action = "fight"
	_pending_move_index = move_index
	_pending_target_index = target_index
	_waiting_for_player = false
	_execute_current_turn()


func select_run() -> void:
	## Called by UI when the player tries to run.
	if not _waiting_for_player:
		return
	_pending_action = "run"
	_waiting_for_player = false
	_execute_current_turn()


func select_swap(reserve_index: int) -> void:
	## Called by UI when the player swaps the active creature for a reserve.
	## This uses the current creature's turn.
	if not _waiting_for_player:
		return
	_pending_action = "swap"
	_pending_target_index = reserve_index
	_waiting_for_player = false
	_execute_current_turn()


# --- Round management ---

func _start_new_round() -> void:
	_set_state(BattleState.TURN_START)
	_build_turn_order()
	_current_turn_idx = 0
	_process_next_turn()


func _build_turn_order() -> void:
	## Sort all living combatants by speed (highest first).
	_turn_order.clear()

	for i in range(player_team.size()):
		if not player_team[i].is_fainted():
			_turn_order.append({
				"creature": player_team[i],
				"is_player": true,
				"index": i,
			})

	for i in range(enemy_team.size()):
		if not enemy_team[i].is_fainted():
			_turn_order.append({
				"creature": enemy_team[i],
				"is_player": false,
				"index": i,
			})

	# Sort by speed descending (with a small random tiebreaker)
	_turn_order.sort_custom(func(a, b):
		var speed_a: int = a["creature"].speed
		var speed_b: int = b["creature"].speed
		if speed_a == speed_b:
			return randf() > 0.5
		return speed_a > speed_b
	)


func _process_next_turn() -> void:
	## Move to the next living combatant in turn order.
	while _current_turn_idx < _turn_order.size():
		var turn_data: Dictionary = _turn_order[_current_turn_idx]
		var creature = turn_data["creature"]

		# Skip fainted creatures (may have died during this round)
		if creature.is_fainted():
			_current_turn_idx += 1
			continue

		if turn_data["is_player"]:
			# Player's turn — ask for input
			_set_state(BattleState.PLAYER_SELECT)
			_waiting_for_player = true
			var idx: int = int(turn_data["index"])
			request_player_action.emit(creature, idx)
		else:
			# Enemy's turn — AI picks action
			_do_enemy_action(turn_data)

		return  # Wait for action to complete

	# All turns done — resolve end-of-round effects
	await _resolve_round()


func _execute_current_turn() -> void:
	## Execute the current player's chosen action.
	var turn_data: Dictionary = _turn_order[_current_turn_idx]

	if _pending_action == "run":
		await _attempt_escape()
		return

	if _pending_action == "swap":
		await _do_swap(turn_data, _pending_target_index)
		# Move to next turn (swap consumes the turn)
		_current_turn_idx += 1
		_process_next_turn()
		return

	if _pending_action == "fight":
		await _do_attack(turn_data, _pending_move_index, _pending_target_index, true)

	# Check if battle ended
	if await _check_battle_end():
		return

	# Move to next turn
	_current_turn_idx += 1
	_process_next_turn()


func _do_enemy_action(turn_data: Dictionary) -> void:
	_set_state(BattleState.EXECUTE_ACTION)
	var creature = turn_data["creature"]

	# Simple AI: pick a random move and a random living player target
	var available_moves: Array = []
	for i in range(creature.moves.size()):
		if creature.moves[i]["current_pp"] > 0:
			available_moves.append(i)

	if available_moves.is_empty():
		battle_message.emit("%s has no moves left!" % creature.nickname)
		await get_tree().create_timer(1.2).timeout
		_current_turn_idx += 1
		_process_next_turn()
		return

	var chosen_move: int = available_moves[randi() % available_moves.size()]

	# Pick a random living player target
	var valid_targets: Array = get_living_player_indices()
	if valid_targets.is_empty():
		_current_turn_idx += 1
		_process_next_turn()
		return

	var target_idx: int = valid_targets[randi() % valid_targets.size()]

	await _do_attack(turn_data, chosen_move, target_idx, false)

	if await _check_battle_end():
		return

	_current_turn_idx += 1
	_process_next_turn()


func _do_attack(turn_data: Dictionary, move_index: int, target_index: int,
		targeting_enemy: bool) -> void:
	_set_state(BattleState.EXECUTE_ACTION)

	var attacker = turn_data["creature"]
	var is_player_attacking: bool = turn_data["is_player"]

	if attacker.is_fainted():
		return

	# Resolve defender
	var defender
	var defending_team: Array = enemy_team if is_player_attacking else player_team

	if target_index >= 0 and target_index < defending_team.size():
		defender = defending_team[target_index]
	else:
		return

	# If target already fainted, retarget to first living member of that team
	if defender.is_fainted():
		var found := false
		for i in range(defending_team.size()):
			if not defending_team[i].is_fainted():
				defender = defending_team[i]
				target_index = i
				found = true
				break
		if not found:
			return

	var move_data := _get_move_data(attacker, move_index)
	if move_data.is_empty():
		return

	# Deduct PP
	attacker.moves[move_index]["current_pp"] -= 1

	var attacker_label: String = attacker.nickname
	if not is_player_attacking:
		attacker_label = "Enemy " + attacker.nickname

	var move_category: String = move_data.get("category", "physical")
	var move_name: String = move_data.get("name", "???")

	# Status moves target differently — some target self
	var effect: Dictionary = move_data.get("effect", {})
	var targets_self: bool = effect.get("target", "enemy") == "self"

	if targets_self:
		battle_message.emit("%s uses %s!" % [attacker_label, move_name])
	else:
		battle_message.emit("%s casts %s on %s!" % [attacker_label, move_name, defender.nickname])
	await get_tree().create_timer(1.2).timeout

	# Handle status moves separately from damaging moves
	if move_category == "status":
		# Accuracy check for status moves
		var accuracy: int = move_data.get("accuracy", 100)
		if accuracy < 100 and randi() % 100 >= accuracy:
			battle_message.emit("But it missed!")
			await get_tree().create_timer(1.0).timeout
			return

		await _apply_status_effect(attacker, defender, move_data, is_player_attacking, target_index)
		return

	var result := BattleCalculator.calculate_damage(attacker, defender, move_data)

	if result["missed"]:
		battle_message.emit("The attack missed!")
	else:
		defender.take_damage(result["damage"])
		var defender_is_player := not is_player_attacking
		creature_hp_changed.emit(defender_is_player, target_index,
			defender.current_hp, defender.max_hp)

		if result["critical"]:
			battle_message.emit("A critical hit!")
			await get_tree().create_timer(0.8).timeout

		if result["effectiveness_text"] != "":
			battle_message.emit(result["effectiveness_text"])
			await get_tree().create_timer(0.8).timeout

		# Check for damaging moves that also have status side-effects (e.g. fire_bolt burn chance)
		var dmg_effect: Dictionary = move_data.get("effect", {})
		var effect_chance: int = move_data.get("effect_chance", 0)
		if not dmg_effect.is_empty() and effect_chance > 0:
			if randi() % 100 < effect_chance:
				await _apply_status_effect(attacker, defender, move_data, is_player_attacking, target_index)

	await get_tree().create_timer(0.6).timeout

	# Check if defender fainted
	if defender.is_fainted():
		battle_message.emit("%s has been defeated!" % defender.nickname)
		creature_fainted.emit(not is_player_attacking, target_index)
		await get_tree().create_timer(1.2).timeout

		# If a player creature defeated an enemy, gain EXP
		if is_player_attacking and not attacker.is_fainted():
			var exp_amount := BattleCalculator.calculate_exp_yield(defender, is_wild_battle)
			var leveled_up: bool = attacker.gain_experience(exp_amount)
			battle_message.emit("%s gained %d EXP!" % [attacker.nickname, exp_amount])
			exp_gained.emit(attacker, exp_amount, leveled_up)
			await get_tree().create_timer(1.0).timeout

			if leveled_up:
				battle_message.emit("%s reached level %d!" % [attacker.nickname, attacker.level])
				await get_tree().create_timer(1.2).timeout
			else:
				var remaining: int = attacker._exp_for_next_level() - attacker.experience
				battle_message.emit("%d more EXP to level %d" % [remaining, attacker.level + 1])
				await get_tree().create_timer(1.0).timeout

		# If player ally fainted, try to swap in a reserve
		if not is_player_attacking:
			await _try_swap_reserve(target_index)


func _attempt_escape() -> void:
	if not is_wild_battle:
		battle_message.emit("There's no retreating from this duel!")
		await get_tree().create_timer(1.5).timeout
		_waiting_for_player = true
		var turn_data: Dictionary = _turn_order[_current_turn_idx]
		request_player_action.emit(turn_data["creature"], int(turn_data["index"]))
		return

	# Use the fastest player creature vs fastest enemy for escape calc
	var player_speed := 0
	for p in player_team:
		if not p.is_fainted():
			player_speed = max(player_speed, p.speed)
	var enemy_speed := 1
	for e in enemy_team:
		if not e.is_fainted():
			enemy_speed = max(enemy_speed, e.speed)

	var escape_chance: float = clamp(float(player_speed) / float(enemy_speed) * 0.5 + 0.25, 0.2, 1.0)

	if randf() < escape_chance:
		battle_message.emit("Your party retreated safely!")
		await get_tree().create_timer(1.5).timeout
		_set_state(BattleState.RUN)
		battle_ended.emit("run")
	else:
		battle_message.emit("The enemies cut off your retreat!")
		await get_tree().create_timer(1.5).timeout
		_current_turn_idx += 1
		_process_next_turn()


func _try_swap_reserve(fallen_index: int) -> void:
	## Automatically swap in the next available reserve when an ally falls.
	if player_reserves.is_empty():
		return

	for i in range(player_reserves.size()):
		if not player_reserves[i].is_fainted():
			var replacement: CreatureInstance = player_reserves[i]
			player_reserves.remove_at(i)
			player_team[fallen_index] = replacement
			battle_message.emit("%s steps up to fight!" % replacement.nickname)
			creature_hp_changed.emit(true, fallen_index,
				replacement.current_hp, replacement.max_hp)
			await get_tree().create_timer(1.5).timeout
			return


func _do_swap(turn_data: Dictionary, reserve_index: int) -> void:
	## Player voluntarily swaps the active creature for a reserve. Uses the turn.
	_set_state(BattleState.EXECUTE_ACTION)

	var active_idx: int = int(turn_data["index"])
	var active_creature = turn_data["creature"]

	if reserve_index < 0 or reserve_index >= player_reserves.size():
		return
	if player_reserves[reserve_index].is_fainted():
		return

	var incoming = player_reserves[reserve_index]

	# Swap: move active to reserves, bring in the new creature
	player_reserves.remove_at(reserve_index)
	player_reserves.append(active_creature)
	player_team[active_idx] = incoming

	battle_message.emit("%s, fall back! %s, you're up!" % [
		active_creature.nickname, incoming.nickname
	])
	creature_hp_changed.emit(true, active_idx, incoming.current_hp, incoming.max_hp)
	await get_tree().create_timer(1.5).timeout


# --- End-of-round ---

func _resolve_round() -> void:
	_set_state(BattleState.RESOLVE)

	var all_combatants: Array = []
	for i in range(player_team.size()):
		all_combatants.append({"creature": player_team[i], "is_player": true, "index": i})
	for i in range(enemy_team.size()):
		all_combatants.append({"creature": enemy_team[i], "is_player": false, "index": i})

	for data in all_combatants:
		var creature = data["creature"]
		if creature.is_fainted():
			continue

		var status_dmg := 0
		var status_msg := ""
		match creature.status_effect:
			"poison":
				status_dmg = max(1, creature.max_hp / 8)
				status_msg = "%s is hurt by poison!" % creature.nickname
			"burn":
				status_dmg = max(1, creature.max_hp / 16)
				status_msg = "%s is hurt by its burn!" % creature.nickname

		if status_dmg > 0:
			creature.take_damage(status_dmg)
			creature_hp_changed.emit(data["is_player"], data["index"],
				creature.current_hp, creature.max_hp)
			battle_message.emit(status_msg)
			await get_tree().create_timer(1.0).timeout

			if creature.is_fainted():
				battle_message.emit("%s has been defeated!" % creature.nickname)
				creature_fainted.emit(data["is_player"], data["index"])
				await get_tree().create_timer(1.2).timeout
				if data["is_player"]:
					await _try_swap_reserve(data["index"])

	if not await _check_battle_end():
		_start_new_round()


# --- Win/lose checks ---

func _check_battle_end() -> bool:
	_set_state(BattleState.CHECK_END)

	# All enemies down?
	var all_enemies_down := true
	for e in enemy_team:
		if not e.is_fainted():
			all_enemies_down = false
			break

	if all_enemies_down:
		battle_message.emit("All enemies have been defeated!")
		await get_tree().create_timer(2.0).timeout
		_set_state(BattleState.WIN)
		battle_ended.emit("win")
		return true

	# All player creatures (active + reserves) down?
	var all_players_down := true
	for p in player_team:
		if not p.is_fainted():
			all_players_down = false
			break
	if all_players_down:
		for r in player_reserves:
			if not r.is_fainted():
				all_players_down = false
				break

	if all_players_down:
		battle_message.emit("Your entire party has fallen!")
		await get_tree().create_timer(2.0).timeout
		_set_state(BattleState.LOSE)
		battle_ended.emit("lose")
		return true

	return false


# --- Status effect handling ---

func _apply_status_effect(attacker, defender, move_data: Dictionary,
		is_player_attacking: bool, target_index: int) -> void:
	## Apply status move effects (stat changes, status conditions) and show messages.
	var effect: Dictionary = move_data.get("effect", {})
	if effect.is_empty():
		battle_message.emit("But nothing happened!")
		await get_tree().create_timer(1.0).timeout
		return

	var targets_self: bool = effect.get("target", "enemy") == "self"
	var target_creature = attacker if targets_self else defender
	var target_label: String = target_creature.nickname

	# Stat stage changes (e.g. war_cry lowers attack, iron_guard raises defense)
	if effect.has("stat"):
		var stat_name: String = effect["stat"]
		var stages: int = int(effect.get("stages", 0))

		# Apply the stat change to the creature's actual stats
		_apply_stat_stages(target_creature, stat_name, stages)

		# Build a descriptive message
		var stat_display := _get_stat_display_name(stat_name)
		var change_text: String
		if stages >= 2:
			change_text = "rose sharply!"
		elif stages == 1:
			change_text = "rose!"
		elif stages == -1:
			change_text = "fell!"
		elif stages <= -2:
			change_text = "fell sharply!"
		else:
			change_text = "changed!"

		battle_message.emit("%s's %s %s" % [target_label, stat_display, change_text])
		await get_tree().create_timer(1.2).timeout

	# Status conditions (e.g. poison, burn, sleep)
	if effect.has("status"):
		var status: String = effect["status"]
		if target_creature.status_effect != "":
			battle_message.emit("%s is already affected by %s!" % [target_label, target_creature.status_effect])
			await get_tree().create_timer(1.0).timeout
		else:
			target_creature.status_effect = status
			target_creature.status_turns = 0
			var status_msg := _get_status_inflict_message(target_label, status)
			battle_message.emit(status_msg)
			await get_tree().create_timer(1.2).timeout


func _apply_stat_stages(creature, stat_name: String, stages: int) -> void:
	## Apply stat stage multiplier to a creature's current stats.
	## Each stage is roughly a 50% change (multiply by 1.5 for +1, 0.67 for -1).
	var multiplier := 1.0
	if stages > 0:
		multiplier = 1.0 + (stages * 0.5)  # +1 = 1.5x, +2 = 2.0x
	elif stages < 0:
		multiplier = 1.0 / (1.0 + (abs(stages) * 0.5))  # -1 = 0.67x, -2 = 0.5x

	match stat_name:
		"attack":
			creature.attack = max(1, int(creature.attack * multiplier))
		"defense":
			creature.defense = max(1, int(creature.defense * multiplier))
		"sp_attack":
			creature.sp_attack = max(1, int(creature.sp_attack * multiplier))
		"sp_defense":
			creature.sp_defense = max(1, int(creature.sp_defense * multiplier))
		"speed":
			creature.speed = max(1, int(creature.speed * multiplier))


func _get_stat_display_name(stat_name: String) -> String:
	match stat_name:
		"attack": return "Attack"
		"defense": return "Defense"
		"sp_attack": return "Sp. Attack"
		"sp_defense": return "Sp. Defense"
		"speed": return "Speed"
		"accuracy": return "Accuracy"
		_: return stat_name.capitalize()


func _get_status_inflict_message(target_label: String, status: String) -> String:
	match status:
		"poison": return "%s was poisoned!" % target_label
		"burn": return "%s was burned!" % target_label
		"sleep": return "%s fell asleep!" % target_label
		"paralysis": return "%s was paralyzed!" % target_label
		"freeze": return "%s was frozen solid!" % target_label
		_: return "%s was inflicted with %s!" % [target_label, status]


# --- Helpers ---

func _get_move_data(creature, index: int) -> Dictionary:
	if index < 0 or index >= creature.moves.size():
		return {}
	return DataLoader.get_move_data(creature.moves[index]["id"])


func get_living_enemy_indices() -> Array:
	var result := []
	for i in range(enemy_team.size()):
		if not enemy_team[i].is_fainted():
			result.append(i)
	return result


func get_living_player_indices() -> Array:
	var result := []
	for i in range(player_team.size()):
		if not player_team[i].is_fainted():
			result.append(i)
	return result


func _set_state(new_state: BattleState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
