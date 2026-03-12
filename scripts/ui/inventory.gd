extends CanvasLayer
## Inventory screen — browse items and use them on party members.

var _main_panel: Control       # The item list panel (hidden during creature select)
var _selector_layer: Control   # Creature selector overlay (shown on Use)
var _feedback_label: Label
var _selected_item_id: String = ""


func _ready() -> void:
	layer = 10
	GameManager.set_state(GameManager.GameState.MENU)
	_build_main_panel()


# ─── Main Panel ───────────────────────────────────────────────────

func _build_main_panel() -> void:
	# Clear any old UI
	for child in get_children():
		child.queue_free()
	_main_panel = null
	_selector_layer = null

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_main_panel = root

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Item list
	if GameManager.inventory.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Your bag is empty."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(empty_label)
	else:
		for item_id in GameManager.inventory.keys():
			_build_item_row(vbox, item_id)

	vbox.add_child(HSeparator.new())

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_feedback_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)


func _build_item_row(parent: Control, item_id: String) -> void:
	var item_data: Dictionary = DataLoader.get_item_data(item_id)
	if item_data.is_empty():
		return

	var qty: int = GameManager.inventory.get(item_id, 0)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var top := HBoxContainer.new()
	row.add_child(top)

	var name_label := Label.new()
	name_label.text = "%s  x%d" % [item_data.get("name", item_id), qty]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var use_btn := Button.new()
	use_btn.text = "Use"
	use_btn.custom_minimum_size = Vector2(60, 0)
	use_btn.pressed.connect(_on_use_pressed.bind(item_id))
	top.add_child(use_btn)

	var desc := Label.new()
	desc.text = item_data.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(desc)


# ─── Creature Selector ────────────────────────────────────────────

func _on_use_pressed(item_id: String) -> void:
	_selected_item_id = item_id
	_show_creature_selector()


func _show_creature_selector() -> void:
	# Remove any existing selector
	if _selector_layer and is_instance_valid(_selector_layer):
		_selector_layer.queue_free()

	var item_data: Dictionary = DataLoader.get_item_data(_selected_item_id)
	var effect_type: String = item_data.get("effect", {}).get("type", "")
	var item_name: String = item_data.get("name", _selected_item_id)

	# Overlay on top of the main panel
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_panel.add_child(overlay)
	_selector_layer = overlay

	# Semi-transparent tint over the existing backdrop
	var tint := ColorRect.new()
	tint.color = Color(0, 0, 0, 0.4)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Use %s on..." % item_name
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Party member buttons
	var any_valid := false
	for i in range(GameManager.player_party.size()):
		var creature = GameManager.player_party[i]
		var valid := false
		match effect_type:
			"heal_hp", "full_heal":
				valid = not creature.is_fainted() and creature.current_hp < creature.max_hp
			"revive":
				valid = creature.is_fainted()
			_:
				valid = not creature.is_fainted()

		var row := HBoxContainer.new()
		vbox.add_child(row)

		var name_label := Label.new()
		name_label.text = creature.nickname
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var hp_label := Label.new()
		if creature.is_fainted():
			hp_label.text = "Fainted"
			hp_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		else:
			hp_label.text = "%d / %d HP" % [creature.current_hp, creature.max_hp]
		hp_label.custom_minimum_size = Vector2(100, 0)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(hp_label)

		var select_btn := Button.new()
		select_btn.text = "Select"
		select_btn.custom_minimum_size = Vector2(70, 0)
		select_btn.disabled = not valid
		select_btn.pressed.connect(_on_creature_selected.bind(i))
		row.add_child(select_btn)

		if valid:
			any_valid = true

	if not any_valid:
		var no_target := Label.new()
		no_target.text = "No valid targets."
		no_target.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(no_target)

	vbox.add_child(HSeparator.new())

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_dismiss_selector)
	vbox.add_child(cancel_btn)


func _on_creature_selected(creature_index: int) -> void:
	var creature = GameManager.player_party[creature_index]
	var item_data: Dictionary = DataLoader.get_item_data(_selected_item_id)
	var item_name: String = item_data.get("name", _selected_item_id)

	var success := GameManager.use_item(_selected_item_id, creature)

	_dismiss_selector()
	_build_main_panel()  # Rebuild to update quantities

	if success:
		_feedback_label.text = "Used %s on %s!" % [item_name, creature.nickname]
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
	else:
		_feedback_label.text = "Couldn't use %s on %s." % [item_name, creature.nickname]
		_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))


func _dismiss_selector() -> void:
	if _selector_layer and is_instance_valid(_selector_layer):
		_selector_layer.queue_free()
		_selector_layer = null
	_selected_item_id = ""


# ─── Lifecycle ────────────────────────────────────────────────────

func _close() -> void:
	GameManager.set_state(GameManager.GameState.OVERWORLD)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _selector_layer and is_instance_valid(_selector_layer):
				_dismiss_selector()
			else:
				_close()
			get_viewport().set_input_as_handled()
		elif event.is_action("inventory"):
			_close()
			get_viewport().set_input_as_handled()
