extends CanvasLayer
## Main battle scene controller for 3v3 combat.
## Wires the UI to the BattleStateMachine and handles target selection.

@onready var battle_sm = $BattleStateMachine
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

# Direct @onready references to battle slot UI nodes (avoids has_node() loop failures)
@onready var _es1: TextureRect = $UI/BattleField/EnemyArea/EnemySlot1/EnemySprite1
@onready var _es2: TextureRect = $UI/BattleField/EnemyArea/EnemySlot2/EnemySprite2
@onready var _es3: TextureRect = $UI/BattleField/EnemyArea/EnemySlot3/EnemySprite3
@onready var _ep1: Control = $UI/BattleField/EnemyArea/EnemySlot1/EnemyPanel1
@onready var _ep2: Control = $UI/BattleField/EnemyArea/EnemySlot2/EnemyPanel2
@onready var _ep3: Control = $UI/BattleField/EnemyArea/EnemySlot3/EnemyPanel3
@onready var _en1: Label = $UI/BattleField/EnemyArea/EnemySlot1/EnemyPanel1/VBox/NameLabel
@onready var _en2: Label = $UI/BattleField/EnemyArea/EnemySlot2/EnemyPanel2/VBox/NameLabel
@onready var _en3: Label = $UI/BattleField/EnemyArea/EnemySlot3/EnemyPanel3/VBox/NameLabel
@onready var _el1: Label = $UI/BattleField/EnemyArea/EnemySlot1/EnemyPanel1/VBox/LevelLabel
@onready var _el2: Label = $UI/BattleField/EnemyArea/EnemySlot2/EnemyPanel2/VBox/LevelLabel
@onready var _el3: Label = $UI/BattleField/EnemyArea/EnemySlot3/EnemyPanel3/VBox/LevelLabel
@onready var _eh1: ProgressBar = $UI/BattleField/EnemyArea/EnemySlot1/EnemyPanel1/VBox/HPBar
@onready var _eh2: ProgressBar = $UI/BattleField/EnemyArea/EnemySlot2/EnemyPanel2/VBox/HPBar
@onready var _eh3: ProgressBar = $UI/BattleField/EnemyArea/EnemySlot3/EnemyPanel3/VBox/HPBar

@onready var _ps1: TextureRect = $UI/BattleField/PlayerArea/PlayerSlot1/PlayerSprite1
@onready var _ps2: TextureRect = $UI/BattleField/PlayerArea/PlayerSlot2/PlayerSprite2
@onready var _ps3: TextureRect = $UI/BattleField/PlayerArea/PlayerSlot3/PlayerSprite3
@onready var _pp1: Control = $UI/BattleField/PlayerArea/PlayerSlot1/PlayerPanel1
@onready var _pp2: Control = $UI/BattleField/PlayerArea/PlayerSlot2/PlayerPanel2
@onready var _pp3: Control = $UI/BattleField/PlayerArea/PlayerSlot3/PlayerPanel3
@onready var _pn1: Label = $UI/BattleField/PlayerArea/PlayerSlot1/PlayerPanel1/VBox/NameLabel
@onready var _pn2: Label = $UI/BattleField/PlayerArea/PlayerSlot2/PlayerPanel2/VBox/NameLabel
@onready var _pn3: Label = $UI/BattleField/PlayerArea/PlayerSlot3/PlayerPanel3/VBox/NameLabel
@onready var _pl1: Label = $UI/BattleField/PlayerArea/PlayerSlot1/PlayerPanel1/VBox/LevelLabel
@onready var _pl2: Label = $UI/BattleField/PlayerArea/PlayerSlot2/PlayerPanel2/VBox/LevelLabel
@onready var _pl3: Label = $UI/BattleField/PlayerArea/PlayerSlot3/PlayerPanel3/VBox/LevelLabel
@onready var _ph1: ProgressBar = $UI/BattleField/PlayerArea/PlayerSlot1/PlayerPanel1/VBox/HPBar
@onready var _ph2: ProgressBar = $UI/BattleField/PlayerArea/PlayerSlot2/PlayerPanel2/VBox/HPBar
@onready var _ph3: ProgressBar = $UI/BattleField/PlayerArea/PlayerSlot3/PlayerPanel3/VBox/HPBar
@onready var _php1: Label = $UI/BattleField/PlayerArea/PlayerSlot1/PlayerPanel1/VBox/HPLabel
@onready var _php2: Label = $UI/BattleField/PlayerArea/PlayerSlot2/PlayerPanel2/VBox/HPLabel
@onready var _php3: Label = $UI/BattleField/PlayerArea/PlayerSlot3/PlayerPanel3/VBox/HPLabel

# Sprite and stat panel arrays (indices 0-2 for each side)
# Note: untyped to avoid Godot 4 typed-array issues
var enemy_sprites: Array = []
var enemy_panels: Array = []
var enemy_name_labels: Array = []
var enemy_hp_bars: Array = []
var enemy_level_labels: Array = []

var player_sprites: Array = []
var player_panels: Array = []
var player_name_labels: Array = []
var player_hp_bars: Array = []
var player_hp_labels: Array = []
var player_level_labels: Array = []

# Target selection buttons
var target_buttons: Array = []

# Battle sprite loading
const SPRITE_PATH_TEMPLATE := "res://assets/sprites/creatures/%s_battle.png"
# Overrides map creature_id -> sprite path for any creature whose sprite filename
# doesn't exactly match the creature ID (or to force a specific sprite).
const SPRITE_OVERRIDES := {
	"emberclaw_seductress": "res://assets/sprites/creatures/emberclaw_seductress_battle.png",
	"voidblade_succubus": "res://assets/sprites/creatures/voidblade_succubus_battle.png",
	"alexia": "res://assets/sprites/creatures/wind_scout_battle.png",
}

var move_buttons: Array = []
var swap_buttons: Array = []
var player_team: Array = []
var enemy_team: Array = []

# Currently active ally (whose turn it is)
var _active_ally_index: int = 0
var _selected_move_index: int = 0


func _ready() -> void:
	# Populate slot arrays directly from @onready vars (avoids string-path has_node() issues)
	enemy_sprites   = [_es1, _es2, _es3]
	enemy_panels    = [_ep1, _ep2, _ep3]
	enemy_name_labels  = [_en1, _en2, _en3]
	enemy_level_labels = [_el1, _el2, _el3]
	enemy_hp_bars   = [_eh1, _eh2, _eh3]

	player_sprites   = [_ps1, _ps2, _ps3]
	player_panels    = [_pp1, _pp2, _pp3]
	player_name_labels  = [_pn1, _pn2, _pn3]
	player_level_labels = [_pl1, _pl2, _pl3]
	player_hp_bars   = [_ph1, _ph2, _ph3]
	player_hp_labels = [_php1, _php2, _php3]

	# Collect move buttons
	var move_btn_nodes := [
		$UI/BottomArea/MovePanel/TopRow/MoveButton1,
		$UI/BottomArea/MovePanel/TopRow/MoveButton2,
		$UI/BottomArea/MovePanel/BottomRow/MoveButton3,
		$UI/BottomArea/MovePanel/BottomRow/MoveButton4,
	]
	for i in range(move_btn_nodes.size()):
		var btn: Button = move_btn_nodes[i]
		move_buttons.append(btn)
		btn.pressed.connect(_on_move_selected.bind(i))

	# Collect target buttons
	target_buttons = [
		$UI/BottomArea/TargetPanel/TargetButton1,
		$UI/BottomArea/TargetPanel/TargetButton2,
		$UI/BottomArea/TargetPanel/TargetButton3,
	]
	for i in range(target_buttons.size()):
		target_buttons[i].pressed.connect(_on_target_selected.bind(i))

	# Collect swap buttons
	swap_buttons = [
		$UI/BottomArea/SwapPanel/SwapButton1,
		$UI/BottomArea/SwapPanel/SwapButton2,
		$UI/BottomArea/SwapPanel/SwapButton3,
	]
	for i in range(swap_buttons.size()):
		swap_buttons[i].pressed.connect(_on_swap_selected.bind(i))

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

	# Always load directly from the raw PNG — skips the import system entirely,
	# which avoids crashes from stale .import files left over from older Godot versions.
	var global_path := ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(global_path)
	if image == null:
		image = Image.load_from_file(path)
	if image == null:
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
	var living: Array = battle_sm.get_living_enemy_indices()

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
