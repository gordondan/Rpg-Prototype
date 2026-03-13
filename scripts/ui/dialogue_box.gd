extends CanvasLayer
## Dialogue box UI — handles typewriter text, multi-page lines, portraits,
## and player choices with branching outcomes.
##
## Usage:
##   DialogueManager.start_dialogue("npc_id") — for JSON-driven conversations
##   DialogueManager.show_lines(["Hello!", "Goodbye!"]) — for quick one-off lines

signal dialogue_finished()
signal choice_made(choice_index: int, choice_id: String)

@onready var panel: PanelContainer = $Panel
@onready var text_label: RichTextLabel = $Panel/MarginContainer/VBox/HBox/TextLabel
@onready var name_label: Label = $Panel/MarginContainer/VBox/NamePanel/NameLabel
@onready var name_panel: PanelContainer = $Panel/MarginContainer/VBox/NamePanel
@onready var portrait: TextureRect = $Panel/MarginContainer/VBox/HBox/Portrait
@onready var continue_indicator: Label = $Panel/MarginContainer/VBox/ContinueIndicator
@onready var choice_container: VBoxContainer = $Panel/MarginContainer/VBox/ChoiceContainer

const CHAR_DELAY := 0.03  # Seconds between each character
const FAST_CHAR_DELAY := 0.01  # When holding confirm

var _lines: Array = []  # Array of dialogue entries
var _current_line_index: int = 0
var _is_typing := false
var _is_waiting_for_input := false
var _is_waiting_for_choice := false
var _full_text := ""
var _visible_chars := 0
var _char_timer := 0.0
var _fast_mode := false
# Set by replace_upcoming_lines() so _on_choice_pressed knows not to overwrite with next_lines
var _lines_replaced := false

# Choice buttons pool
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	panel.visible = false
	continue_indicator.visible = false
	choice_container.visible = false
	set_process(false)


func _process(delta: float) -> void:
	if _is_typing:
		_char_timer += delta
		var delay := FAST_CHAR_DELAY if _fast_mode else CHAR_DELAY

		while _char_timer >= delay and _is_typing:
			_char_timer -= delay
			_visible_chars += 1
			text_label.visible_characters = _visible_chars

			if _visible_chars >= _full_text.length():
				_finish_typing()


func _input(event: InputEvent) -> void:
	if not panel.visible:
		return

	if event.is_action_pressed("interact"):
		# Consume the event so nothing else (battle trigger, player, etc.) reacts
		get_viewport().set_input_as_handled()

		if _is_typing:
			# Skip to end of current line
			_visible_chars = _full_text.length()
			text_label.visible_characters = -1
			_finish_typing()
		elif _is_waiting_for_input:
			_advance_dialogue()
		# Choices are handled by button signals, not input


# ─── Public API ──────────────────────────────────────────────────

func show_dialogue(lines: Array) -> void:
	## Start showing a sequence of dialogue entries.
	## Each entry can be a String (simple line) or a Dictionary:
	##   { "text": "Hello!", "speaker": "Guard", "portrait": "guard",
	##     "choices": [{"text": "Yes", "id": "accept"}, {"text": "No", "id": "decline"}] }
	_lines = lines
	_current_line_index = 0
	panel.visible = true
	set_process(true)
	_show_current_line()


func close() -> void:
	panel.visible = false
	set_process(false)
	_is_typing = false
	_is_waiting_for_input = false
	_is_waiting_for_choice = false
	_clear_choices()
	dialogue_finished.emit()


# ─── Internal ────────────────────────────────────────────────────

func _show_current_line() -> void:
	if _current_line_index >= _lines.size():
		close()
		return

	var entry = _lines[_current_line_index]
	_clear_choices()
	continue_indicator.visible = false
	choice_container.visible = false

	var text: String
	var speaker: String = ""
	var portrait_id: String = ""
	var choices: Array = []

	if entry is String:
		text = entry
	elif entry is Dictionary:
		text = entry.get("text", "")
		speaker = entry.get("speaker", "")
		portrait_id = entry.get("portrait", "")
		choices = entry.get("choices", [])
	else:
		text = str(entry)

	# Speaker name
	if speaker != "":
		name_panel.visible = true
		name_label.text = speaker
	else:
		name_panel.visible = false

	# Portrait
	if portrait_id != "":
		portrait.visible = true
		_load_portrait(portrait_id)
	else:
		portrait.visible = false

	# Store choices for after typing finishes
	_lines[_current_line_index] = entry  # Keep the dict reference

	# Start typewriter effect
	_full_text = text
	_visible_chars = 0
	_char_timer = 0.0
	_fast_mode = false
	_is_typing = true
	_is_waiting_for_input = false
	_is_waiting_for_choice = false

	text_label.text = _full_text
	text_label.visible_characters = 0


func _finish_typing() -> void:
	_is_typing = false
	text_label.visible_characters = -1  # Show all

	var entry = _lines[_current_line_index]
	var choices: Array = []

	if entry is Dictionary:
		choices = entry.get("choices", [])

	if choices.size() > 0:
		# Show choice buttons
		_show_choices(choices)
		_is_waiting_for_choice = true
	else:
		# Show "press to continue" indicator
		var is_last_line := _current_line_index >= _lines.size() - 1
		continue_indicator.text = "▼" if not is_last_line else "■"
		continue_indicator.visible = true
		_is_waiting_for_input = true


func _advance_dialogue() -> void:
	_is_waiting_for_input = false
	continue_indicator.visible = false
	_current_line_index += 1
	_show_current_line()


func replace_upcoming_lines(new_lines: Array) -> void:
	## Replace all lines after the current one with new_lines.
	## Called by DialogueManager to swap follow-up text (e.g. not enough gold, party full).
	_lines = _lines.slice(0, _current_line_index + 1)
	_lines.append_array(new_lines)
	_lines_replaced = true  # Signal to _on_choice_pressed not to re-append next_lines


func _show_choices(choices: Array) -> void:
	choice_container.visible = true

	for i in range(choices.size()):
		var choice = choices[i]
		var btn := Button.new()
		btn.text = choice.get("text", "...")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_choice_pressed.bind(i, choice.get("id", str(i))))
		choice_container.add_child(btn)
		_choice_buttons.append(btn)

	# Focus the first button so keyboard works
	if _choice_buttons.size() > 0:
		_choice_buttons[0].grab_focus()


func _clear_choices() -> void:
	for btn in _choice_buttons:
		btn.queue_free()
	_choice_buttons.clear()
	choice_container.visible = false


func _on_choice_pressed(index: int, choice_id: String) -> void:
	_is_waiting_for_choice = false
	_clear_choices()
	_lines_replaced = false  # Reset before emitting — replace_upcoming_lines may set it
	choice_made.emit(index, choice_id)

	# Only insert the choice's follow-up lines if nothing replaced them already
	# (e.g. party-full barracks redirect, or not-enough-gold rejection)
	if not _lines_replaced:
		var entry = _lines[_current_line_index]
		if entry is Dictionary:
			var choices: Array = entry.get("choices", [])
			if index < choices.size():
				var chosen = choices[index]
				var next_lines: Array = chosen.get("next", [])
				if next_lines.size() > 0:
					# Insert the follow-up lines after the current position
					var remaining := _lines.slice(_current_line_index + 1)
					_lines = _lines.slice(0, _current_line_index + 1)
					_lines.append_array(next_lines)
					_lines.append_array(remaining)

	_current_line_index += 1
	_show_current_line()


func _load_portrait(portrait_id: String) -> void:
	## Load a portrait image, same runtime approach as battle sprites.
	var path := "res://assets/sprites/portraits/%s.png" % portrait_id
	var global_path := ProjectSettings.globalize_path(path)

	if FileAccess.file_exists(global_path):
		var image := Image.new()
		if image.load(global_path) == OK:
			portrait.texture = ImageTexture.create_from_image(image)
			return
	elif FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			portrait.texture = ImageTexture.create_from_image(image)
			return

	portrait.texture = null
	portrait.visible = false
