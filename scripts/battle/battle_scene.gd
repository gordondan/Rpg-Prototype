extends CanvasLayer
## Main battle scene controller — wires the UI to the BattleStateMachine.
## Attach this to your battle scene root node.

@onready var battle_sm: BattleStateMachine = $BattleStateMachine

# UI references (connect these in the editor)
@onready var message_label: Label = $UI/MessageBox/MessageLabel
@onready var player_name_label: Label = $UI/PlayerPanel/NameLabel
@onready var player_hp_bar: ProgressBar = $UI/PlayerPanel/HPBar
@onready var player_hp_label: Label = $UI/PlayerPanel/HPLabel
@onready var player_level_label: Label = $UI/PlayerPanel/LevelLabel
@onready var enemy_name_label: Label = $UI/EnemyPanel/NameLabel
@onready var enemy_hp_bar: ProgressBar = $UI/EnemyPanel/HPBar
@onready var enemy_level_label: Label = $UI/EnemyPanel/LevelLabel
@onready var move_buttons: Array[Button] = []
@onready var action_panel: Control = $UI/ActionPanel
@onready var fight_button: Button = $UI/ActionPanel/FightButton
@onready var run_button: Button = $UI/ActionPanel/RunButton
@onready var move_panel: Control = $UI/MovePanel

var player_creature: CreatureInstance
var enemy_creature: CreatureInstance


func _ready() -> void:
	# Collect move buttons
	for i in range(4):
		var btn_path := "UI/MovePanel/MoveButton%d" % (i + 1)
		if has_node(btn_path):
			var btn: Button = get_node(btn_path)
			move_buttons.append(btn)
			btn.pressed.connect(_on_move_selected.bind(i))

	# Connect action buttons
	if fight_button:
		fight_button.pressed.connect(_on_fight_pressed)
	if run_button:
		run_button.pressed.connect(_on_run_pressed)

	# Connect battle signals
	battle_sm.battle_message.connect(_on_battle_message)
	battle_sm.state_changed.connect(_on_state_changed)
	battle_sm.battle_ended.connect(_on_battle_ended)
	battle_sm.creature_hp_changed.connect(_on_hp_changed)

	# Hide panels initially
	if move_panel:
		move_panel.visible = false


func setup_battle(player: CreatureInstance, enemy: CreatureInstance, is_wild: bool) -> void:
	player_creature = player
	enemy_creature = enemy

	_update_player_panel()
	_update_enemy_panel()
	_update_move_buttons()

	battle_sm.start_battle(player, enemy, is_wild)


func _update_player_panel() -> void:
	if player_name_label:
		player_name_label.text = player_creature.nickname
	if player_level_label:
		player_level_label.text = "Lv.%d" % player_creature.level
	if player_hp_bar:
		player_hp_bar.max_value = player_creature.max_hp
		player_hp_bar.value = player_creature.current_hp
	if player_hp_label:
		player_hp_label.text = "%d / %d" % [player_creature.current_hp, player_creature.max_hp]


func _update_enemy_panel() -> void:
	if enemy_name_label:
		enemy_name_label.text = enemy_creature.nickname
	if enemy_level_label:
		enemy_level_label.text = "Lv.%d" % enemy_creature.level
	if enemy_hp_bar:
		enemy_hp_bar.max_value = enemy_creature.max_hp
		enemy_hp_bar.value = enemy_creature.current_hp


func _update_move_buttons() -> void:
	for i in range(move_buttons.size()):
		if i < player_creature.moves.size():
			var move_data := DataLoader.get_move_data(player_creature.moves[i]["id"])
			move_buttons[i].text = "%s\n%s  PP:%d/%d" % [
				move_data.get("name", "???"),
				move_data.get("type", "???").to_upper(),
				player_creature.moves[i]["current_pp"],
				player_creature.moves[i]["max_pp"]
			]
			move_buttons[i].visible = true
			move_buttons[i].disabled = player_creature.moves[i]["current_pp"] <= 0
		else:
			move_buttons[i].visible = false


func _on_fight_pressed() -> void:
	if action_panel:
		action_panel.visible = false
	if move_panel:
		move_panel.visible = true
	_update_move_buttons()


func _on_run_pressed() -> void:
	if action_panel:
		action_panel.visible = false
	battle_sm.select_run()


func _on_move_selected(index: int) -> void:
	if move_panel:
		move_panel.visible = false
	battle_sm.select_fight(index)


func _on_battle_message(text: String) -> void:
	if message_label:
		message_label.text = text


func _on_state_changed(new_state: BattleStateMachine.BattleState) -> void:
	match new_state:
		BattleStateMachine.BattleState.PLAYER_TURN:
			if action_panel:
				action_panel.visible = true
			if move_panel:
				move_panel.visible = false
		_:
			if action_panel:
				action_panel.visible = false


func _on_hp_changed(is_player: bool, current_hp: int, max_hp: int) -> void:
	if is_player:
		if player_hp_bar:
			# Animate HP bar
			var tween := create_tween()
			tween.tween_property(player_hp_bar, "value", current_hp, 0.4)
		if player_hp_label:
			player_hp_label.text = "%d / %d" % [current_hp, max_hp]
	else:
		if enemy_hp_bar:
			var tween := create_tween()
			tween.tween_property(enemy_hp_bar, "value", current_hp, 0.4)


func _on_battle_ended(result: String) -> void:
	await get_tree().create_timer(1.0).timeout
	BattleManager.end_battle(result)
	queue_free()
