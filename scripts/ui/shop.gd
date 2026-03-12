extends CanvasLayer
## Shop UI — built programmatically. Instantiated by merchant NPCs.
## Displays items for sale and handles gold transactions.

signal shop_closed()

var shop_id: String = ""

var _gold_label: Label
var _feedback_label: Label
var _item_rows: Array = []


func _ready() -> void:
	layer = 10  # Draw above overworld and dialogue
	GameManager.set_state(GameManager.GameState.MENU)
	_build_ui()


func open(p_shop_id: String) -> void:
	shop_id = p_shop_id
	_build_ui()


func _build_ui() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	_item_rows.clear()

	var shop_data: Dictionary = DataLoader.get_shop_data(shop_id)
	if shop_data.is_empty():
		push_warning("[Shop] No data found for shop_id: %s" % shop_id)
		_close()
		return

	var shop_name: String = shop_data.get("name", "Merchant")
	var greeting: String  = shop_data.get("greeting", "Welcome!")
	var item_ids: Array   = shop_data.get("items", [])

	# --- Full-screen root control (backdrop + centering anchor) ---
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	# CenterContainer handles centering after the panel's size is resolved
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	# --- Panel ---
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Padding margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	# Title row
	var title_row := HBoxContainer.new()
	inner.add_child(title_row)

	var title_label := Label.new()
	title_label.text = shop_name
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)

	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % GameManager.gold
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_gold_label)

	# Greeting
	var greet_label := Label.new()
	greet_label.text = greeting
	greet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(greet_label)

	# Separator
	inner.add_child(HSeparator.new())

	# Item rows
	for item_id in item_ids:
		var item_data: Dictionary = DataLoader.get_item_data(item_id)
		if item_data.is_empty():
			continue
		_build_item_row(inner, item_id, item_data)

	# Separator + feedback
	inner.add_child(HSeparator.new())

	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
	inner.add_child(_feedback_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close)
	inner.add_child(close_btn)


func _build_item_row(parent: Control, item_id: String, item_data: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var top_row := HBoxContainer.new()
	row.add_child(top_row)

	# Item name
	var name_label := Label.new()
	name_label.text = item_data.get("name", item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	# Price
	var price_label := Label.new()
	var price: int = item_data.get("price", 0)
	price_label.text = "%d g" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.custom_minimum_size = Vector2(60, 0)
	top_row.add_child(price_label)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(60, 0)
	buy_btn.pressed.connect(_on_buy_pressed.bind(item_id, item_data))
	top_row.add_child(buy_btn)

	# Description (smaller, greyed out)
	var desc_label := Label.new()
	desc_label.text = item_data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(desc_label)


func _on_buy_pressed(item_id: String, item_data: Dictionary) -> void:
	var price: int = item_data.get("price", 0)
	var item_name: String = item_data.get("name", item_id)

	if GameManager.gold < price:
		_show_feedback("Not enough gold!", Color(0.9, 0.3, 0.3))
		return

	GameManager.gold -= price
	GameManager.add_item(item_id)
	_gold_label.text = "Gold: %d" % GameManager.gold
	_show_feedback("Bought %s!" % item_name, Color(0.3, 0.85, 0.4))


func _show_feedback(message: String, color: Color = Color.WHITE) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", color)


func _close() -> void:
	GameManager.set_state(GameManager.GameState.OVERWORLD)
	shop_closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
