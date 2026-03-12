extends Node
## Global dialogue manager — loads dialogue data and controls the dialogue UI.
## Autoloaded as "DialogueManager".

const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")

signal dialogue_started()
signal dialogue_ended()
signal choice_selected(choice_id: String)

const DIALOGUE_BOX_SCENE := "res://scenes/ui/dialogue_box.tscn"

var _dialogue_data: Dictionary = {}
var _dialogue_box: Node = null
var _is_active := false
## The NPC currently in conversation — set before any dialogue starts.
## Gives the manager access to the NPC's persistent creature_instance.
var _active_npc = null


func _ready() -> void:
	_load_dialogue_data()


func _load_dialogue_data() -> void:
	var path := "res://data/characters/characters.json"
	if not FileAccess.file_exists(path):
		push_warning("Characters file not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("Failed to parse characters file: %s" % path)
		return

	# Extract dialogue entries from each character's dialogues map
	for character_id in json.data:
		var character: Dictionary = json.data[character_id]
		var dialogues: Dictionary = character.get("dialogues", {})
		for dialogue_id in dialogues:
			var dialogue_entry: Dictionary = dialogues[dialogue_id].duplicate(true)
			dialogue_entry["name"] = character.get("name", character_id)
			dialogue_entry["sprite"] = character.get("npc_sprite", "")
			_dialogue_data[dialogue_id] = dialogue_entry

	print("[DialogueManager] Loaded %d dialogue entries from characters.json" % _dialogue_data.size())


# ─── Public API ──────────────────────────────────────────────────

func start_dialogue(dialogue_id: String) -> void:
	## Start a dialogue sequence from the data files by ID.
	if _is_active:
		push_warning("Dialogue already active!")
		return

	var data: Dictionary = _dialogue_data.get(dialogue_id, {})
	if data.is_empty():
		push_warning("Dialogue not found: %s" % dialogue_id)
		return

	# Check if this dialogue requires a story flag
	var required_flag: String = data.get("requires_flag", "")
	if required_flag != "" and not GameManager.get_flag(required_flag):
		return

	var lines: Array = data.get("lines", [])
	if lines.is_empty():
		return

	_begin_dialogue(lines)


func show_lines(lines: Array) -> void:
	## Show a quick sequence of lines without needing a dialogue ID.
	## Accepts an array of Strings or Dictionaries.
	if _is_active:
		push_warning("Dialogue already active!")
		return

	if lines.is_empty():
		return

	_begin_dialogue(lines)


func show_line(text: String, speaker: String = "") -> void:
	## Show a single line of dialogue.
	var entry: Variant
	if speaker != "":
		entry = {"text": text, "speaker": speaker}
	else:
		entry = text
	show_lines([entry])


func is_active() -> bool:
	return _is_active


func set_active_npc(npc) -> void:
	## Register the NPC currently being talked to so recruitment can access
	## its persistent creature_instance rather than creating a fresh one.
	_active_npc = npc


# ─── Internal ────────────────────────────────────────────────────

func _begin_dialogue(lines: Array) -> void:
	_is_active = true
	GameManager.set_state(GameManager.GameState.DIALOGUE)
	dialogue_started.emit()

	# Create dialogue box if it doesn't exist
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		var scene := load(DIALOGUE_BOX_SCENE)
		if not scene:
			push_error("Could not load dialogue box scene!")
			_is_active = false
			return
		var current := get_tree().current_scene
		if not is_instance_valid(current):
			push_error("[DialogueManager] current_scene is invalid — cannot open dialogue box")
			_is_active = false
			return
		_dialogue_box = scene.instantiate()
		current.add_child(_dialogue_box)

	# Connect signals
	if not _dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	if not _dialogue_box.choice_made.is_connected(_on_choice_made):
		_dialogue_box.choice_made.connect(_on_choice_made)

	_dialogue_box.show_dialogue(lines)


func _on_dialogue_finished() -> void:
	_is_active = false
	_active_npc = null
	GameManager.set_state(GameManager.GameState.OVERWORLD)
	dialogue_ended.emit()

	# Clean up
	if _dialogue_box and is_instance_valid(_dialogue_box):
		_dialogue_box.queue_free()
		_dialogue_box = null


func _on_choice_made(choice_index: int, choice_id: String) -> void:
	choice_selected.emit(choice_id)

	# Handle special choice actions
	match choice_id:
		"rest":
			var cost := 25
			if GameManager.gold >= cost:
				GameManager.gold -= cost
				GameManager.heal_all_party()
				print("[DialogueManager] Party healed! -%d gold (remaining: %d)" % [cost, GameManager.gold])
			else:
				# Not enough gold — swap the follow-up lines to a rejection
				if _dialogue_box and is_instance_valid(_dialogue_box):
					_dialogue_box.replace_upcoming_lines([
						{"text": "You don't have enough gold for a room. Come back when you've got 25 gold.", "speaker": "Tavern Keeper"}
					])
		"recruit_fairy":
			_handle_recruit("fairy_recruited")
		"recruit_alexia":
			_handle_recruit("alexia_recruited")
		"recruit_aqua_monk":
			_handle_recruit("aqua_monk_recruited")
		"recruit_zacharias":
			_handle_recruit("zacharias_recruited")


func _handle_recruit(flag_name: String) -> void:
	## Recruit the active NPC's persistent creature_instance into the player's party.
	## Uses the same object that existed on the map (and fought in battle if applicable),
	## so level, moves, and any battle-state changes are preserved.
	if _active_npc == null or _active_npc.creature_instance == null:
		push_error("[DialogueManager] Cannot recruit: no active NPC or creature_instance set.")
		return

	var creature = _active_npc.creature_instance
	creature.full_heal()  # Restore HP/PP so they join at full strength

	var added_to_party := GameManager.add_creature_to_party(creature)
	GameManager.set_flag(flag_name)

	if added_to_party:
		print("[DialogueManager] Recruited %s (Lv.%d) — added to party!" % [creature.nickname, creature.level])
	else:
		print("[DialogueManager] Recruited %s (Lv.%d) — party full, sent to barracks." % [creature.nickname, creature.level])
		# Notify the player their party is full
		if _dialogue_box and is_instance_valid(_dialogue_box):
			_dialogue_box.replace_upcoming_lines([
				{"text": "%s joined your company!" % creature.nickname, "speaker": ""},
				{"text": "Your party is full. %s will wait in the barracks until you make room." % creature.nickname, "speaker": ""},
			])

	# Remove the NPC from the scene once the conversation closes
	var npc_ref = _active_npc
	dialogue_ended.connect(func(): if is_instance_valid(npc_ref): npc_ref.queue_free(), CONNECT_ONE_SHOT)


func get_dialogue_data(dialogue_id: String) -> Dictionary:
	return _dialogue_data.get(dialogue_id, {})
