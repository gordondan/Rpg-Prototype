extends CanvasLayer
## Party management screen — swap creatures between party and barracks,
## reorder party members (first 3 are active in battle, rest are reserves).

@onready var party_list: VBoxContainer = $UI/PartyList
@onready var barracks_list: VBoxContainer = $UI/BarracksList
@onready var info_label: Label = $UI/InfoPanel/InfoLabel
@onready var close_button: Button = $UI/CloseButton

# Currently selected creature for actions
var _selected_source: String = ""  # "party" or "barracks"
var _selected_index: int = -1


func _ready() -> void:
	close_button.pressed.connect(_close)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	GameManager.set_state(GameManager.GameState.OVERWORLD)
	queue_free()


func _refresh() -> void:
	## Rebuild both lists from current GameManager data.
	_clear_list(party_list)
	_clear_list(barracks_list)
	_selected_source = ""
	_selected_index = -1

	# Build party entries
	for i in range(GameManager.player_party.size()):
		var creature = GameManager.player_party[i]
		var row := _create_creature_row(creature, i, "party")

		# Label first 3 as "Active", rest as "Reserve"
		var role := "Active" if i < 3 else "Reserve"
		row.get_node("RoleLabel").text = role

		party_list.add_child(row)

	# Build barracks entries
	for i in range(GameManager.barracks.size()):
		var creature = GameManager.barracks[i]
		var row := _create_creature_row(creature, i, "barracks")
		barracks_list.add_child(row)

	info_label.text = "Select a creature to manage."


func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _create_creature_row(creature, index: int, source: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Role label (only for party)
	var role_label := Label.new()
	role_label.name = "RoleLabel"
	role_label.add_theme_font_size_override("font_size", 7)
	role_label.custom_minimum_size = Vector2(32, 0)
	if source == "barracks":
		role_label.text = ""
	row.add_child(role_label)

	# Creature info button (clickable)
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 8)

	var hp_text := "%d/%d" % [creature.current_hp, creature.max_hp]
	var type_text := "/".join(creature.types)
	var exp_needed := creature._exp_for_next_level()
	btn.text = "%s  Lv.%d  %s  HP:%s  XP:%d/%d" % [creature.nickname, creature.level, type_text, hp_text, creature.experience, exp_needed]

	btn.pressed.connect(_on_creature_selected.bind(source, index))
	row.add_child(btn)

	return row


func _on_creature_selected(source: String, index: int) -> void:
	_selected_source = source
	_selected_index = index

	var creature
	if source == "party":
		creature = GameManager.player_party[index]
	else:
		creature = GameManager.barracks[index]

	# Show creature info and available actions
	var hp_text := "%d/%d HP" % [creature.current_hp, creature.max_hp]
	var type_text := "/".join(creature.types)
	var moves_text := ""
	for m in creature.moves:
		var move_data: Dictionary = DataLoader.get_move_data(m["id"])
		if not move_data.is_empty():
			moves_text += move_data.get("name", m["id"]) + "  "

	var exp_needed := creature._exp_for_next_level()
	var exp_text := "EXP: %d / %d  (need %d more)" % [creature.experience, exp_needed, exp_needed - creature.experience]

	info_label.text = "%s (Lv.%d) — %s — %s\n%s\nMoves: %s" % [
		creature.nickname, creature.level, type_text, hp_text, exp_text, moves_text
	]

	# Clear old action buttons and rebuild
	_clear_action_buttons()
	_build_action_buttons(source, index)


func _clear_action_buttons() -> void:
	# Remove any previous action buttons from the info panel area
	for child in get_node("UI").get_children():
		if child.is_in_group("action_buttons"):
			child.queue_free()


func _build_action_buttons(source: String, index: int) -> void:
	var btn_container := HBoxContainer.new()
	btn_container.add_to_group("action_buttons")
	btn_container.layout_mode = 1
	btn_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn_container.offset_left = 388.0
	btn_container.offset_top = 286.0
	btn_container.offset_right = 476.0
	btn_container.offset_bottom = 316.0

	if source == "party":
		# Move up (higher priority / more active)
		if index > 0:
			var up_btn := Button.new()
			up_btn.text = "Up"
			up_btn.add_theme_font_size_override("font_size", 8)
			up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			up_btn.pressed.connect(_move_party_up.bind(index))
			btn_container.add_child(up_btn)

		# Move down
		if index < GameManager.player_party.size() - 1:
			var down_btn := Button.new()
			down_btn.text = "Dn"
			down_btn.add_theme_font_size_override("font_size", 8)
			down_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			down_btn.pressed.connect(_move_party_down.bind(index))
			btn_container.add_child(down_btn)

		# Send to barracks (only if party has more than 1)
		if GameManager.player_party.size() > 1:
			var remove_btn := Button.new()
			remove_btn.text = "Store"
			remove_btn.add_theme_font_size_override("font_size", 8)
			remove_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			remove_btn.pressed.connect(_send_to_barracks.bind(index))
			btn_container.add_child(remove_btn)

	elif source == "barracks":
		# Add to party (only if party has room)
		if GameManager.player_party.size() < 6:
			var add_btn := Button.new()
			add_btn.text = "Add"
			add_btn.add_theme_font_size_override("font_size", 8)
			add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_btn.pressed.connect(_add_to_party.bind(index))
			btn_container.add_child(add_btn)

	get_node("UI").add_child(btn_container)


func _move_party_up(index: int) -> void:
	GameManager.swap_party_positions(index, index - 1)
	_refresh()


func _move_party_down(index: int) -> void:
	GameManager.swap_party_positions(index, index + 1)
	_refresh()


func _send_to_barracks(index: int) -> void:
	if GameManager.move_to_barracks(index):
		_refresh()
	else:
		info_label.text = "Can't remove — party needs at least one creature!"


func _add_to_party(index: int) -> void:
	if GameManager.move_to_party(index):
		_refresh()
	else:
		info_label.text = "Party is full (max 6)! Remove someone first."
