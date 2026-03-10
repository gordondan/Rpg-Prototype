extends CanvasLayer
## Hub menu — shown when the player presses I in the overworld.
## Lets the player choose between Party Manager and Inventory.


func _ready() -> void:
	layer = 10
	GameManager.set_state(GameManager.GameState.MENU)
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
	panel.custom_minimum_size = Vector2(220, 0)
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
	title.text = "Menu"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var party_btn := Button.new()
	party_btn.text = "Party Manager"
	party_btn.pressed.connect(_open_party)
	vbox.add_child(party_btn)

	var inv_btn := Button.new()
	inv_btn.text = "Inventory"
	inv_btn.pressed.connect(_open_inventory)
	vbox.add_child(inv_btn)

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)


func _open_party() -> void:
	queue_free()  # Hub closes; party editor manages state from here
	var editor_scene := load("res://scenes/ui/party_editor.tscn")
	if editor_scene:
		var instance: Node = editor_scene.instantiate()
		get_tree().current_scene.add_child(instance)


func _open_inventory() -> void:
	queue_free()
	var inv_script := load("res://scripts/ui/inventory.gd")
	if inv_script:
		var inv_node := CanvasLayer.new()
		inv_node.set_script(inv_script)
		get_tree().current_scene.add_child(inv_node)


func _close() -> void:
	GameManager.set_state(GameManager.GameState.OVERWORLD)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action("inventory"):
			_close()
			get_viewport().set_input_as_handled()
