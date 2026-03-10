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


func _ready() -> void:
	_load_dialogue_data()


func _load_dialogue_data() -> void:
	var dir_path := "res://data/dialogue/"
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("Could not open dialogue directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path := dir_path + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
					_dialogue_data.merge(json.data)
					print("[DialogueManager] Loaded dialogue from: %s" % file_name)
		file_name = dir.get_next()

	print("[DialogueManager] Total dialogue entries: %d" % _dialogue_data.size())


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
		_dialogue_box = scene.instantiate()
		get_tree().current_scene.add_child(_dialogue_box)

	# Connect signals
	if not _dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	if not _dialogue_box.choice_made.is_connected(_on_choice_made):
		_dialogue_box.choice_made.connect(_on_choice_made)

	_dialogue_box.show_dialogue(lines)


func _on_dialogue_finished() -> void:
	_is_active = false
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
			_recruit_creature("mischievous_fairy", 5, "fairy_recruited", "MischievousFairy")


func _recruit_creature(creature_id: String, level: int, flag_name: String, npc_node_name: String = "") -> void:
	## Create a creature and add it to the player's party. Sets a story flag to track recruitment.
	## If npc_node_name is provided, removes that NPC from the map once dialogue ends.
	var creature := CreatureInstance.create(creature_id, level)
	var added_to_party := GameManager.add_creature_to_party(creature)

	GameManager.set_flag(flag_name)

	if added_to_party:
		print("[DialogueManager] Recruited %s (Lv.%d) — added to party!" % [creature.nickname, level])
	else:
		print("[DialogueManager] Recruited %s (Lv.%d) — party full, sent to barracks." % [creature.nickname, level])
		# Swap the follow-up to mention barracks
		if _dialogue_box and is_instance_valid(_dialogue_box):
			_dialogue_box.replace_upcoming_lines([
				{"text": "%s joined your company! Your party is full, so they headed to the barracks." % creature.nickname, "speaker": ""}
			])

	# Remove the NPC from the map after dialogue finishes
	if npc_node_name != "":
		dialogue_ended.connect(_remove_npc_node.bind(npc_node_name), CONNECT_ONE_SHOT)


func _remove_npc_node(npc_node_name: String) -> void:
	## Find and remove a recruited NPC from the scene tree.
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.name == npc_node_name:
			npc.queue_free()
			print("[DialogueManager] Removed NPC node: %s" % npc_node_name)
			return


func get_dialogue_data(dialogue_id: String) -> Dictionary:
	return _dialogue_data.get(dialogue_id, {})
