extends CanvasLayer
## Main battle scene controller — wires the UI to the BattleStateMachine.

@onready var battle_sm: BattleStateMachine = $BattleStateMachine

# UI references — updated to match new BottomArea / BattleField layout
@onready var message_label: Label = $UI/BottomArea/MessageLabel
@onready var player_name_label: Label = $"UI/BattleField/PlayerPanel/VBox/NameLabel"
@onready var player_hp_bar: ProgressBar = $"UI/BattleField/PlayerPanel/VBox/HPBar"
@onready var player_hp_label: Label = $"UI/BattleField/PlayerPanel/VBox/HPLabel"
@onready var player_level_label: Label = $"UI/BattleField/PlayerPanel/VBox/LevelLabel"
@onready var enemy_name_label: Label = $"UI/BattleField/EnemyPanel/VBox/NameLabel"
@onready var enemy_hp_bar: ProgressBar = $"UI/BattleField/EnemyPanel/VBox/HPBar"
@onready var enemy_level_label: Label = $"UI/BattleField/EnemyPanel/VBox/LevelLabel"

@onready var action_panel: Control = $UI/BottomArea/ActionPanel
@onready var fight_button: Button = $UI/BottomArea/ActionPanel/FightButton
@onready var run_button: Button = $UI/BottomArea/ActionPanel/RunButton
@onready var move_panel: Control = $UI/BottomArea/MovePanel
@onready var back_button: Button = $UI/BottomArea/MovePanel/BackButton

# Battle sprite displays
@onready var enemy_sprite: TextureRect = $"UI/BattleField/EnemySprite"
@onready var player_sprite: TextureRect = $"UI/BattleField/PlayerSprite"

# Maps creature IDs to their battle sprite paths
const SPRITE_PATH_TEMPLATE := "res://assets/sprites/creatures/%s_battle.png"
# Fallback mapping for IDs that don't match the filename pattern
const SPRITE_OVERRIDES := {
	"flame_squire": "res://assets/sprites/creatures/flame_squire_battle.png",
	"goblin": "res://assets/sprites/creatures/goblin_battle.png",
}

var move_buttons: Array[Button] = []
var player_creature: CreatureInstance
var enemy_creature: CreatureInstance


func _ready() -> void:
	# Collect move buttons from the 2x2 grid layout
	var button_paths := [
		"UI/BottomArea/MovePanel/TopRow/MoveButton1",
		"UI/BottomArea/MovePanel/TopRow/MoveButton2",
		"UI/BottomArea/MovePanel/BottomRow/MoveButton3",
		"UI/BottomArea/MovePanel/BottomRow/MoveButton4",
	]
	for i in range(button_paths.size()):
		if has_node(button_paths[i]):
			var btn: Button = get_node(button_paths[i])
			move_buttons.append(btn)
			btn.pressed.connect(_on_move_selected.bind(i))

	# Connect action buttons
	if fight_button:
		fight_button.pressed.connect(_on_fight_pressed)
	if run_button:
		run_button.pressed.connect(_on_run_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Connect battle signals
	battle_sm.battle_message.connect(_on_battle_message)
	battle_sm.state_changed.connect(_on_state_changed)
	battle_sm.battle_ended.connect(_on_battle_ended)
	battle_sm.creature_hp_changed.connect(_on_hp_changed)

	# Hide all interactive panels initially — intro message shows alone
	if action_panel:
		action_panel.visible = false
	if move_panel:
		move_panel.visible = false


func setup_battle(player: CreatureInstance, enemy: CreatureInstance, is_wild: bool) -> void:
	player_creature = player
	enemy_creature = enemy

	_update_player_panel()
	_update_enemy_panel()
	_update_move_buttons()

	# Load battle sprites
	_load_creature_sprite(player_sprite, player_creature.creature_id)
	_load_creature_sprite(enemy_sprite, enemy_creature.creature_id)

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


func _load_creature_sprite(target: TextureRect, creature_id: String) -> void:
	## Load a battle sprite from disk at runtime, bypassing Godot's import system.
	## This works even if the editor hasn't imported the file yet.
	if not target:
		return

	var path: String
	if creature_id in SPRITE_OVERRIDES:
		path = SPRITE_OVERRIDES[creature_id]
	else:
		path = SPRITE_PATH_TEMPLATE % creature_id

	# Convert res:// path to the actual global filesystem path
	var global_path := ProjectSettings.globalize_path(path)

	if not FileAccess.file_exists(global_path) and not FileAccess.file_exists(path):
		print("[BattleScene] No sprite for '%s'" % creature_id)
		target.texture = null
		return

	# Load the PNG directly into an Image, then create an ImageTexture
	var image := Image.new()
	var err: int

	# Try global path first, then res:// path
	if FileAccess.file_exists(global_path):
		err = image.load(global_path)
	else:
		err = image.load(path)

	if err != OK:
		print("[BattleScene] Failed to load image for '%s' (error %d)" % [creature_id, err])
		target.texture = null
		return

	var tex := ImageTexture.create_from_image(image)
	target.texture = tex
	print("[BattleScene] Loaded sprite for '%s': %dx%d" % [creature_id, image.get_width(), image.get_height()])


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


func _on_back_pressed() -> void:
	if move_panel:
		move_panel.visible = false
	if action_panel:
		action_panel.visible = true


func _on_move_selected(index: int) -> void:
	if move_panel:
		move_panel.visible = false
	battle_sm.select_fight(index)


func _on_battle_message(text: String) -> void:
	if message_label:
		message_label.text = text


func _on_state_changed(new_state: BattleStateMachine.BattleState) -> void:
	match new_state:
		BattleStateMachine.BattleState.INTRO:
			# Only the message text is visible during intro
			if message_label:
				message_label.visible = true
			if action_panel:
				action_panel.visible = false
			if move_panel:
				move_panel.visible = false
		BattleStateMachine.BattleState.PLAYER_TURN:
			# Show action buttons, hide message and move panel
			if message_label:
				message_label.visible = false
			if action_panel:
				action_panel.visible = true
			if move_panel:
				move_panel.visible = false
		_:
			# During attacks/resolution, show message text, hide buttons
			if message_label:
				message_label.visible = true
			if action_panel:
				action_panel.visible = false
			if move_panel:
				move_panel.visible = false


func _on_hp_changed(is_player: bool, current_hp: int, max_hp: int) -> void:
	if is_player:
		if player_hp_bar:
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
