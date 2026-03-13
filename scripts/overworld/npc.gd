extends CharacterBody2D
## NPC with dialogue (simple or branching) and optional rival battle.

const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")

@export var npc_name: String = "Villager"
@export var dialogue_id: String = ""  # References data/dialogue/*.json
@export var simple_lines: Array[String] = []  # Fallback if no dialogue_id

@export var is_merchant: bool = false
@export var shop_id: String = ""

@export var quest_id: String = ""
@export var quest_role: String = ""   # "giver" or "step"
@export var quest_step_index: int = 0 # which step index this NPC fulfils (for "step" NPCs)

@export var is_rival: bool = false
@export var rival_creature_id: String = ""
@export var rival_creature_level: int = 5
## Optional multi-creature party. Each entry: {"creature_id": String, "level": int}
## If set, overrides rival_creature_id/rival_creature_level for the battle.
@export var rival_party: Array = []
## Optional reserve creatures the enemy can swap in (up to 3). Same format as rival_party.
@export var rival_reserves: Array = []
## If true, this NPC disappears after being defeated instead of offering post-defeat dialogue.
@export var disappear_on_defeat: bool = false
@export var defeated_flag: String = ""
@export var post_defeat_dialogue_id: String = ""  # Dialogue shown after the player beats this rival
@export var defeat_quest_id: String = ""          # Quest to advance a step when this rival is defeated
@export var recruited_flag: String = ""           # Set by DialogueManager when player recruits them
## Creature ID/level for peaceful recruitable NPCs (no battle). Creates creature_instance on spawn.
@export var recruit_creature_id: String = ""
@export var recruit_creature_level: int = 1
@export var line_of_sight_range: int = 4
## Character key in characters.json — used for sound lookups.
## Defaults to dialogue_id if not set.
@export var character_id: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sight_ray: RayCast2D = $SightRay

var facing_direction := Vector2.DOWN
var _last_greet_time: float = -999.0
const GREET_DEBOUNCE := 15.0
## The persistent creature instance this NPC represents.
## Created once on spawn — used in battle as the lead enemy, and transferred directly
## to the player's party on recruitment rather than creating a fresh object.
var creature_instance: CreatureInstance = null


func _ready() -> void:
	add_to_group("npc")
	if character_id == "":
		character_id = dialogue_id
	_create_creature_instance()
	_setup_greet_area()
	if is_rival and sight_ray:
		_update_sight_ray()


func _create_creature_instance() -> void:
	## Build this NPC's creature instance once on spawn.
	## Priority: recruit_creature_id (peaceful) → rival_party[0] (battle-first) → rival_creature_id (single rival)
	if recruit_creature_id != "":
		creature_instance = CreatureInstance.create(recruit_creature_id, recruit_creature_level)
	elif rival_party.size() > 0:
		var lead: Dictionary = rival_party[0]
		creature_instance = CreatureInstance.create(
			lead.get("creature_id", ""), lead.get("level", 1)
		)
	elif rival_creature_id != "":
		creature_instance = CreatureInstance.create(rival_creature_id, rival_creature_level)


func _physics_process(_delta: float) -> void:
	# Y-sort: depth tracks Y position so NPCs behind the player render behind them.
	z_index = int(position.y)

	if is_rival and sight_ray and not _is_defeated() and not _is_recruited():
		sight_ray.force_raycast_update()
		if sight_ray.is_colliding():
			var collider := sight_ray.get_collider()
			if collider.is_in_group("player"):
				_initiate_rival_duel()


func interact() -> void:
	## Called when the player presses interact facing this NPC.
	if DialogueManager.is_active():
		return
	if GameManager.current_state == GameManager.GameState.MENU:
		return
	# Register ourselves so DialogueManager can access creature_instance during recruitment
	DialogueManager.set_active_npc(self)

	# Merchant: open the shop UI directly
	if is_merchant and shop_id != "":
		_open_shop()
		return

	# Quest-aware interaction — takes priority over standard dialogue
	if _handle_quest_interact():
		return

	if _is_recruited():
		# Already in the party — show the recruited variant if one exists
		var recruited_id := recruited_flag + "_dialogue"
		var d := DialogueManager.get_dialogue_data(recruited_id)
		if not d.is_empty():
			DialogueManager.start_dialogue(recruited_id)
		else:
			DialogueManager.show_line("I'm already with you.", npc_name)
	elif is_rival and _is_defeated() and post_defeat_dialogue_id != "":
		# Beaten but not yet recruited — show the post-defeat / recruit offer dialogue
		DialogueManager.start_dialogue(post_defeat_dialogue_id)
	elif is_rival and not _is_defeated():
		_start_dialogue_then_battle()
	else:
		_start_dialogue()


func _start_dialogue() -> void:
	## Start dialogue using the dialogue system.
	if dialogue_id != "":
		DialogueManager.start_dialogue(dialogue_id)
	elif simple_lines.size() > 0:
		# Convert simple strings into dialogue entries with speaker name
		var lines: Array = []
		for line in simple_lines:
			lines.append({"text": line, "speaker": npc_name})
		DialogueManager.show_lines(lines)
	else:
		DialogueManager.show_line("...", npc_name)


func _start_dialogue_then_battle() -> void:
	_start_dialogue()
	# Wait for dialogue to finish, then start the battle
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended_start_battle, CONNECT_ONE_SHOT)


func _on_dialogue_ended_start_battle() -> void:
	var enemies: Array = []
	if rival_party.size() > 0:
		# First creature = the NPC's persistent instance (carries battle damage through to recruit)
		if creature_instance != null:
			enemies.append(creature_instance)
		else:
			var lead: Dictionary = rival_party[0]
			enemies.append(CreatureInstance.create(lead.get("creature_id", ""), lead.get("level", 1)))
		# Remaining party members are created fresh each encounter
		for i in range(1, rival_party.size()):
			var entry: Dictionary = rival_party[i]
			enemies.append(CreatureInstance.create(
				entry.get("creature_id", rival_creature_id),
				entry.get("level", rival_creature_level)
			))
	else:
		# Single-creature — use persistent instance
		if creature_instance != null:
			enemies.append(creature_instance)
		else:
			enemies.append(CreatureInstance.create(rival_creature_id, rival_creature_level))

	# Build enemy reserve team if any are defined
	var e_reserves: Array = []
	for entry in rival_reserves:
		var cid: String = entry.get("creature_id", "")
		var clv: int    = entry.get("level", 1)
		if cid != "":
			e_reserves.append(CreatureInstance.create(cid, clv))

	BattleManager.start_rival_battle(enemies, e_reserves)
	BattleManager.battle_finished.connect(_on_rival_defeated, CONNECT_ONE_SHOT)


func _initiate_rival_duel() -> void:
	print("[%s] challenges the player to a duel!" % npc_name)
	DialogueManager.set_active_npc(self)
	_start_dialogue_then_battle()


func _on_rival_defeated(result: String) -> void:
	if result == "win":
		if defeated_flag != "":
			GameManager.set_flag(defeated_flag)
		# Advance (or bank) the quest step for defeating this rival.
		# advance_quest_step handles the case where the quest hasn't been
		# started yet — the step is banked and applied when the quest is given.
		if defeat_quest_id != "":
			GameManager.advance_quest_step(defeat_quest_id)
		# Disappear-on-defeat: show optional farewell dialogue, then remove from scene
		if disappear_on_defeat:
			if post_defeat_dialogue_id != "":
				await get_tree().create_timer(0.4).timeout
				if not is_instance_valid(self):
					return
				DialogueManager.set_active_npc(self)
				DialogueManager.start_dialogue(post_defeat_dialogue_id)
				DialogueManager.dialogue_ended.connect(func(): queue_free(), CONNECT_ONE_SHOT)
			else:
				queue_free()
			return
		# Show the post-defeat dialogue (e.g. recruit offer) after a short delay
		if post_defeat_dialogue_id != "":
			await get_tree().create_timer(0.4).timeout
			if not is_instance_valid(self):
				return
			DialogueManager.set_active_npc(self)
			DialogueManager.start_dialogue(post_defeat_dialogue_id)


func _is_defeated() -> bool:
	return defeated_flag != "" and GameManager.get_flag(defeated_flag)


func _is_recruited() -> bool:
	return recruited_flag != "" and GameManager.get_flag(recruited_flag)


func _handle_quest_interact() -> bool:
	## Handle quest-aware interaction. Returns true if this NPC handled the interaction.
	if quest_id == "" or quest_role == "":
		return false

	var status: String = GameManager.get_quest_status(quest_id)

	if quest_role == "giver":
		if status == "":
			# First time — start the quest and show the start dialogue
			GameManager.start_quest(quest_id)
			_show_quest_dialogue(dialogue_id)
			# Show a notification toast once the dialogue closes
			DialogueManager.dialogue_ended.connect(_show_quest_notification, CONNECT_ONE_SHOT)
		elif status == "active":
			if GameManager.is_quest_ready_to_complete(quest_id):
				# All steps done — complete quest and give reward
				GameManager.complete_quest(quest_id)
				_show_quest_dialogue(dialogue_id + "_complete")
			else:
				_show_quest_dialogue(dialogue_id + "_active")
		elif status == "completed":
			_show_quest_dialogue(dialogue_id + "_done")
		return true

	elif quest_role == "step":
		if status == "active" and GameManager.get_quest_step(quest_id) == quest_step_index:
			# Player has reached this step — advance and show step dialogue
			GameManager.advance_quest_step(quest_id)
			_show_quest_dialogue(dialogue_id + "_quest")
			return true
		# Not at this step yet, or already past it — fall through to normal dialogue
		return false

	return false


func _show_quest_dialogue(dlg_id: String) -> void:
	## Show dialogue by ID, falling back to a generic line if the ID doesn't exist.
	var d: Dictionary = DialogueManager.get_dialogue_data(dlg_id)
	if not d.is_empty():
		DialogueManager.start_dialogue(dlg_id)
	else:
		DialogueManager.show_line("...", npc_name)


func _show_quest_notification() -> void:
	## Spawn the "New Quest" toast notification.
	var notif_script := load("res://scripts/ui/quest_notification.gd")
	if notif_script:
		var current := get_tree().current_scene
		if not is_instance_valid(current):
			return
		var notif_node := CanvasLayer.new()
		notif_node.set_script(notif_script)
		current.add_child(notif_node)


func _open_shop() -> void:
	var shop_script := load("res://scripts/ui/shop.gd")
	if not shop_script:
		push_error("[NPC] Could not load shop.gd")
		return
	var current := get_tree().current_scene
	if not is_instance_valid(current):
		push_error("[NPC] current_scene is invalid — cannot open shop")
		return
	var shop_node := CanvasLayer.new()
	shop_node.set_script(shop_script)
	shop_node.set("shop_id", shop_id)
	current.add_child(shop_node)


func _update_sight_ray() -> void:
	if sight_ray:
		sight_ray.target_position = facing_direction * 16 * line_of_sight_range


# ─── Proximity Greeting ────────────────────────────────────────

func _setup_greet_area() -> void:
	## Create a proximity Area2D that fires a greet sound when the player walks near.
	var area := Area2D.new()
	area.name = "GreetArea"
	area.collision_layer = 0
	area.collision_mask = 1  # detect player (layer 1)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 32.0  # ~2 tile radius
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_greet_area_entered)


func _on_greet_area_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_greet_time < GREET_DEBOUNCE:
		return
	_last_greet_time = now
	AudioManager.play_character_sound(character_id, "greet")
