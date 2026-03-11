extends CanvasLayer
## Quest Log screen — shows active and completed quests with current step tracking.


func _ready() -> void:
	layer = 10
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Dim backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	# Centered panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 320)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Quest Log"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Scrollable quest list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var quest_list := VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_list.add_theme_constant_override("separation", 6)
	scroll.add_child(quest_list)

	_populate_quests(quest_list)

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Back"
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)


func _populate_quests(container: VBoxContainer) -> void:
	var active_entries: Array = []
	var completed_entries: Array = []

	for quest_id in GameManager.quests:
		var quest_data: Dictionary = DataLoader.get_quest_data(quest_id)
		if quest_data.is_empty():
			continue
		var status: String = GameManager.get_quest_status(quest_id)
		if status == "active":
			active_entries.append({"id": quest_id, "data": quest_data})
		elif status == "completed":
			completed_entries.append({"id": quest_id, "data": quest_data})

	if active_entries.is_empty() and completed_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No quests yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		container.add_child(empty_label)
		return

	# Active quests first
	for entry in active_entries:
		_add_quest_entry(container, entry["id"], entry["data"], false)

	# Separator between sections if both exist
	if not active_entries.is_empty() and not completed_entries.is_empty():
		var sep_label := Label.new()
		sep_label.text = "── Completed ──"
		sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sep_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		sep_label.add_theme_font_size_override("font_size", 10)
		container.add_child(sep_label)

	# Completed quests
	for entry in completed_entries:
		_add_quest_entry(container, entry["id"], entry["data"], true)


func _add_quest_entry(container: VBoxContainer, quest_id: String,
		quest_data: Dictionary, completed: bool) -> void:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)
	container.add_child(entry)

	# Quest name with status icon
	var name_label := Label.new()
	var quest_name: String = quest_data.get("name", quest_id)
	if completed:
		name_label.text = "✓  " + quest_name
		name_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	else:
		name_label.text = "◆  " + quest_name
		name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	name_label.add_theme_font_size_override("font_size", 13)
	entry.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = "    " + quest_data.get("description", "")
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	entry.add_child(desc_label)

	# Current step (active quests only)
	if not completed:
		var steps: Array = quest_data.get("steps", [])
		var current_step: int = GameManager.get_quest_step(quest_id)
		if current_step < steps.size():
			var step_label := Label.new()
			step_label.text = "    → " + steps[current_step].get("description", "")
			step_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			step_label.add_theme_font_size_override("font_size", 11)
			entry.add_child(step_label)
		else:
			var ready_label := Label.new()
			ready_label.text = "    → Return to quest giver"
			ready_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			ready_label.add_theme_font_size_override("font_size", 11)
			entry.add_child(ready_label)

	container.add_child(HSeparator.new())


func _close() -> void:
	# Return to hub menu
	var hub_script := load("res://scripts/ui/hub_menu.gd")
	if hub_script:
		var hub_node := CanvasLayer.new()
		hub_node.set_script(hub_script)
		get_tree().current_scene.add_child(hub_node)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action("inventory"):
			_close()
			get_viewport().set_input_as_handled()
