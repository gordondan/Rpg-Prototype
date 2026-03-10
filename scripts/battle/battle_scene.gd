extends CanvasLayer
## Main battle scene controller for 3v3 combat.
## Wires the UI to the BattleStateMachine and handles target selection.

@onready var battle_sm: BattleStateMachine = $BattleStateMachine
@onready var message_label: Label = $UI/BottomArea/MessageLabel
@onready var action_panel: Control = $UI/BottomArea/ActionPanel
@onready var fight_button: Button = $UI/BottomArea/ActionPanel/FightButton
@onready var run_button: Button = $UI/BottomArea/ActionPanel/RunButton
@onready var move_panel: Control = $UI/BottomArea/MovePanel
@onready var back_button: Button = $UI/BottomArea/MovePanel/BackButton
@onready var target_panel: Control = $UI/BottomArea/TargetPanel
@onready var target_back_button: Button = $UI/BottomArea/TargetPanel/TargetBackButton
@onready var swap_button: Button = $UI/BottomArea/ActionPanel/SwapButton
@onready var swap_panel: Control = $UI/BottomArea/SwapPanel
@onready var swap_back_button: Button = $UI/BottomArea/SwapPanel/SwapBackButton

# Sprite and stat panel arrays (indices 0-2 for each side)
var enemy_sprites: Array[TextureRect] = []
var enemy_panels: Array[Control] = []
var enemy_name_labels: Array[Label] = []
var enemy_hp_bars: Array[ProgressBar] = []
var enemy_level_labels: Array[Label] = []

var player_sprites: Array[TextureRect] = []
var player_panels: Array[Control] = []
var player_name_labels: Array[Label] = []
var player_hp_bars: Array[ProgressBar] = []
var player_hp_labels: Array[Label] = []
var player_level_labels: Array[Label] = []

# Target selection buttons
var target_buttons: Array[Button] = []

# Battle sprite loading
const SPRITE_PATH_TEMPLATE := "res://assets/sprites/creatures/%s_battle.png"
# Overrides map creature_id -> sprite path for any creature whose sprite filename
# doesn't exactly match the creature ID (or to force a specific sprite).
const SPRITE_OVERRIDES := {
	"emberclaw_seductress": "res://assets/sprites/creatures/emberclaw_seductress_battle.png",
	"voidblade_succubus": "res://assets/sprites/creatures/voidblade_succubus_battle.png",
}

var move_buttons: Array[Button] = []
var swap_buttons: Array[Button] = []
var player_team: Array = []
var enemy_team: Array = []

# Currently active ally (whose turn it is)
var _active_ally_index: int = 0
var _selected_move_index: int = 0


func _ready() -> void:
	# Collect enemy UI elements (3 slots)
	for i in range(3):
		var idx := i + 1
		var sprite_path := "UI/BattleField/EnemyArea/EnemySlot%d/EnemySprite%d" % [idx, idx]
		var panel_path := "UI/BattleField/EnemyArea/EnemySlot%d/EnemyPanel%d" % [idx, idx]

		if has_node(sprite_path):
			enemy_sprites.append(get_node(sprite_path))
		if has_node(panel_path):
			enemy_panels.append(get_node(panel_path))
			enemy_name_labels.append(get_node(panel_path + "/VBox/NameLabel"))
			enemy_level_labels.append(get_node(panel_path + "/VBox/LevelLabel"))
			enemy_hp_bars.append(get_node(panel_path + "/VBox/HPBar"))

	# Collect player UI elements (3 slots)
	for i in range(3):
		var idx := i + 1
		var sprite_path := "UI/BattleField/PlayerArea/PlayerSlot%d/PlayerSprite%d" % [idx, idx]
		var panel_path := "UI/BattleField/PlayerArea/PlayerSlot%d/PlayerPanel%d" % [idx, idx]

		if has_node(sprite_path):
			player_sprites.append(get_node(sprite_path))
		if has_node(panel_path):
			player_panels.append(get_node(panel_path))
			player_name_labels.append(get_node(panel_path + "/VBox/NameLabel"))
			player_level_labels.append(get_node(panel_path + "/VBox/LevelLabel"))
			player_hp_bars.append(get_node(panel_path + "/VBox/HPBar"))
			player_hp_labels.append(get_node(panel_path + "/VBox/HPLabel"))

	# Collect move buttons
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

	# Collect target buttons
	for i in range(3):
		var path := "UI/BottomArea/TargetPanel/TargetButton%d" % (i + 1)
		if has_node(path):
			var btn: Button = get_node(path)
			target_buttons.append(btn)
			btn.pressed.connect(_on_target_selected.bind(i))

	# Collect swap buttons
	for i in range(3):
		var path := "UI/BottomArea/SwapPanel/SwapButton%d" % (i + 1)
		if has_node(path):
			var btn: Button = get_node(path)
			swap_buttons.append(btn)
			btn.pressed.connect(_on_swap_selected.bind(i))

	# Connect action buttons
	if fight_button:
		fight_button.pressed.connect(_on_fight_pressed)
	if swap_button:
		swap_button.pressed.connect(_on_swap_pressed)
	if run_button:
		run_button.pressed.connect(_on_run_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if target_back_button:
		target_back_button.pressed.connect(_on_target_back_pressed)
	if swap_back_button:
		swap_back_button.pressed.connect(_on_swap_back_pressed)

	# Connect battle signals
	battle_sm.battle_message.connect(_on_battle_message)
	battle_sm.state_changed.connect(_on_state_changed)
	battle_sm.battle_ended.connect(_on_battle_ended)
	battle_sm.creature_hp_changed.connect(_on_hp_changed)
	battle_sm.creature_fainted.connect(_on_creature_fainted)
	battle_sm.request_player_action.connect(_on_player_action_requested)

	# Ensure message label never blocks button clicks (safety net for PanelContainer overlap)
	if message_label:
		message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Show message only initially
	_show_message_only()


func setup_battle(p_team, e_team, is_wild, reserves = []) -> void:
	player_team = p_team
	enemy_team = e_team
	var reserve_arr = reserves

	# Set up UI for each team member
	for i in range(3):
		if i < enemy_team.size():
			_setup_enemy_slot(i, enemy_team[i])
		else:
			_hide_enemy_slot(i)

		if i < player_team.size():
			_setup_player_slot(i, player_team[i])
		else:
			_hide_player_slot(i)

	battle_sm.start_battle(player_team, enemy_team, bool(is_wild), reserve_arr)


# --- Slot setup ---

func _setup_enemy_slot(index: int, creature) -> void:
	if index < enemy_sprites.size():
		enemy_sprites[index].visible = true
		enemy_sprites[index].modulate = Color.WHITE
		_load_creature_sprite(enemy_sprites[index], creature.creature_id)
	if index < enemy_panels.size():
		enemy_panels[index].visible = true
		enemy_name_labels[index].text = creature.nickname
		enemy_level_labels[index].text = "Lv.%d" % creature.level
		enemy_hp_bars[index].max_value = creature.max_hp
		enemy_hp_bars[index].value = creature.current_hp


func _setup_player_slot(index: int, creature) -> void:
	if index < player_sprites.size():
		player_sprites[index].visible = true
		player_sprites[index].modulate = Color.WHITE
		_load_creature_sprite(player_sprites[index], creature.creature_id)
	if index < player_panels.size():
		player_panels[index].visible = true
		player_name_labels[index].text = creature.nickname
		player_level_labels[index].text = "Lv.%d" % creature.level
		player_hp_bars[index].max_value = creature.max_hp
		player_hp_bars[index].value = creature.current_hp
		player_hp_labels[index].text = "%d / %d" % [creature.current_hp, creature.max_hp]


func _hide_enemy_slot(index: int) -> void:
	if index < enemy_sprites.size():
		enemy_sprites[index].visible = false
	if index < enemy_panels.size():
		enemy_panels[index].visible = false


func _hide_player_slot(index: int) -> void:
	if index < player_sprites.size():
		player_sprites[index].visible = false
	if index < player_panels.size():
		player_panels[index].visible = false


# --- Sprite loading ---

func _load_creature_sprite(target: TextureRect, creature_id: String) -> void:
	if not target:
		return

	var path: String
	if creature_id in SPRITE_OVERRIDES:
		path = SPRITE_OVERRIDES[creature_id]
	else:
		path = SPRITE_PATH_TEMPLATE % creature_id

	# Try Godot's resource loader first (works for editor-imported textures)
	if ResourceLoader.exists(path):
		var tex = ResourceLoader.load(path)
		if tex and tex is Texture2D:
			target.texture = tex
			return

	# Fall back to direct Image loading (works for raw PNG files not yet imported)
	var global_path := ProjectSettings.globalize_path(path)
	var image := Image.new()
	var err := image.load(global_path)
	if err != OK:
		err = image.load(path)
	if err != OK:
		target.texture = null
		return

	target.texture = ImageTexture.create_from_image(image)


# --- Action handling ---

func _on_fight_pressed() -> void:
	_update_move_buttons()
	_show_panel(move_panel)


func _on_run_pressed() -> void:
	_show_message_only()
	battle_sm.select_run()


func _on_back_pressed() -> void:
	_show_panel(action_panel)


func _on_move_selected(index: int) -> void:
	_selected_move_index = index
	_show_target_selection()


func _show_target_selection() -> void:
	var living := battle_sm.get_living_enemy_indices()

	# If only one target, auto-select it
	if living.size() == 1:
		_show_message_only()
		battle_sm.select_fight(_selected_move_index, living[0])
		return

	# Set up target buttons before showing the panel
	for i in range(target_buttons.size()):
		if i < living.size():
			var enemy_idx: int = living[i]
			target_buttons[i].visible = true
			target_buttons[i].text = enemy_team[enemy_idx].nickname
			target_buttons[i].set_meta("enemy_index", enemy_idx)
		else:
			target_buttons[i].visible = false

	_show_panel(target_panel)


func _on_target_selected(button_index: int) -> void:
	if button_index >= target_buttons.size():
		return
	var enemy_idx: int = target_buttons[button_index].get_meta("enemy_index", 0)
	_show_message_only()
	battle_sm.select_fight(_selected_move_index, enemy_idx)


func _on_target_back_pressed() -> void:
	_show_panel(move_panel)


func _on_swap_pressed() -> void:
	_update_swap_buttons()
	_show_panel(swap_panel)


func _on_swap_back_pressed() -> void:
	_show_panel(action_panel)


func _on_swap_selected(button_index: int) -> void:
	if button_index >= swap_buttons.size():
		return
	var reserve_idx: int = swap_buttons[button_index].get_meta("reserve_index", -1)
	if reserve_idx < 0:
		return
	_show_message_only()
	battle_sm.select_swap(reserve_idx)


func _update_swap_buttons() -> void:
	## Populate swap buttons with available reserve creatures.
	var reserves: Array = battle_sm.player_reserves
	var has_any := false

	for i in range(swap_buttons.size()):
		if i < reserves.size() and not reserves[i].is_fainted():
			swap_buttons[i].visible = true
			swap_buttons[i].text = "%s  Lv.%d  HP:%d/%d" % [
				reserves[i].nickname, reserves[i].level,
				reserves[i].current_hp, reserves[i].max_hp
			]
			swap_buttons[i].set_meta("reserve_index", i)
			has_any = true
		else:
			swap_buttons[i].visible = false

	if not has_any:
		# No reserves available — show message instead
		_show_message_only()
		message_label.text = "No reserves available to swap in!"


func _update_move_buttons() -> void:
	if _active_ally_index >= player_team.size():
		return
	var creature = player_team[_active_ally_index]
	for i in range(move_buttons.size()):
		if i < creature.moves.size():
			var move_data := DataLoader.get_move_data(creature.moves[i]["id"])
			move_buttons[i].text = "%s\n%s  PP:%d/%d" % [
				move_data.get("name", "???"),
				move_data.get("type", "???").to_upper(),
				creature.moves[i]["current_pp"],
				creature.moves[i]["max_pp"]
			]
			move_buttons[i].visible = true
			move_buttons[i].disabled = creature.moves[i]["current_pp"] <= 0
		else:
			move_buttons[i].visible = false


# --- Signal handlers ---

func _on_player_action_requested(creature, ally_index) -> void:
	_active_ally_index = int(ally_index)
	# Show action panel immediately — no delay that could cause message/button overlap
	_show_panel(action_panel)


func _on_battle_message(text) -> void:
	if message_label:
		message_label.text = str(text)
	# Only show message_label if no interactive panel is currently visible
	var panel_showing := false
	if action_panel and action_panel.visible:
		panel_showing = true
	if move_panel and move_panel.visible:
		panel_showing = true
	if target_panel and target_panel.visible:
		panel_showing = true
	if swap_panel and swap_panel.visible:
		panel_showing = true
	if not panel_showing and message_label:
		message_label.visible = true


func _on_state_changed(_new_state) -> void:
	# Panels are managed explicitly by action handlers and _on_player_action_requested.
	# Do NOT call _show_message_only() here — it causes the message label to
	# reappear on top of the action panel during rapid state transitions.
	pass


func _on_hp_changed(is_player, index, current_hp, max_hp) -> void:
	var idx := int(index)
	var hp := int(current_hp)
	var hp_max := int(max_hp)
	if is_player:
		if idx < player_hp_bars.size():
			var tween := create_tween()
			tween.tween_property(player_hp_bars[idx], "value", hp, 0.4)
		if idx < player_hp_labels.size():
			player_hp_labels[idx].text = "%d / %d" % [hp, hp_max]
		# Update display in case of reserve swap
		if idx < player_team.size() and idx < player_name_labels.size():
			player_name_labels[idx].text = player_team[idx].nickname
			player_level_labels[idx].text = "Lv.%d" % player_team[idx].level
			player_hp_bars[idx].max_value = player_team[idx].max_hp
			if idx < player_sprites.size():
				_load_creature_sprite(player_sprites[idx], player_team[idx].creature_id)
				player_sprites[idx].visible = true
				player_sprites[idx].modulate = Color.WHITE
			if idx < player_panels.size():
				player_panels[idx].visible = true
	else:
		if idx < enemy_hp_bars.size():
			var tween := create_tween()
			tween.tween_property(enemy_hp_bars[idx], "value", hp, 0.4)


func _on_creature_fainted(is_player, index) -> void:
	var idx := int(index)
	if is_player:
		if idx < player_sprites.size():
			player_sprites[idx].modulate = Color(0.3, 0.3, 0.3, 0.5)
	else:
		if idx < enemy_sprites.size():
			enemy_sprites[idx].modulate = Color(0.3, 0.3, 0.3, 0.5)


func _on_battle_ended(result) -> void:
	_show_message_only()
	await get_tree().create_timer(1.0).timeout
	BattleManager.end_battle(str(result))
	queue_free()


# --- UI helpers ---

func _show_message_only() -> void:
	## Hide all interactive panels and show just the message label.
	if action_panel:
		action_panel.visible = false
	if move_panel:
		move_panel.visible = false
	if target_panel:
		target_panel.visible = false
	if swap_panel:
		swap_panel.visible = false
	if message_label:
		message_label.visible = true


func _show_panel(panel: Control) -> void:
	## Hide message label and all panels, then show the specified panel.
	if message_label:
		message_label.visible = false
	if action_panel:
		action_panel.visible = false
	if move_panel:
		move_panel.visible = false
	if target_panel:
		target_panel.visible = false
	if swap_panel:
		swap_panel.visible = false
	if panel:
		panel.visible = true
