extends CharacterBody2D
## NPC with dialogue (simple or branching) and optional rival battle.

const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")

@export var npc_name: String = "Villager"
@export var dialogue_id: String = ""  # References data/dialogue/*.json
@export var simple_lines: Array[String] = []  # Fallback if no dialogue_id

@export var is_merchant: bool = false
@export var shop_id: String = ""

@export var is_rival: bool = false
@export var rival_creature_id: String = ""
@export var rival_creature_level: int = 5
@export var defeated_flag: String = ""
@export var post_defeat_dialogue_id: String = ""  # Dialogue shown after the player beats this rival
@export var recruited_flag: String = ""           # Set by DialogueManager when player recruits them
@export var line_of_sight_range: int = 4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sight_ray: RayCast2D = $SightRay

var facing_direction := Vector2.DOWN


func _ready() -> void:
	add_to_group("npc")
	if is_rival and sight_ray:
		_update_sight_ray()


func _physics_process(_delta: float) -> void:
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

	# Merchant: open the shop UI directly
	if is_merchant and shop_id != "":
		_open_shop()
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
	var rival := CreatureInstance.create(rival_creature_id, rival_creature_level)
	BattleManager.start_rival_battle([rival])
	BattleManager.battle_finished.connect(_on_rival_defeated, CONNECT_ONE_SHOT)


func _initiate_rival_duel() -> void:
	print("[%s] challenges the player to a duel!" % npc_name)
	_start_dialogue_then_battle()


func _on_rival_defeated(result: String) -> void:
	if result == "win" and defeated_flag != "":
		GameManager.set_flag(defeated_flag)
		# Show the post-defeat dialogue (e.g. recruit offer) after a short delay
		if post_defeat_dialogue_id != "":
			await get_tree().create_timer(0.4).timeout
			DialogueManager.start_dialogue(post_defeat_dialogue_id)


func _is_defeated() -> bool:
	return defeated_flag != "" and GameManager.get_flag(defeated_flag)


func _is_recruited() -> bool:
	return recruited_flag != "" and GameManager.get_flag(recruited_flag)


func _open_shop() -> void:
	var shop_script := load("res://scripts/ui/shop.gd")
	if not shop_script:
		push_error("[NPC] Could not load shop.gd")
		return
	var shop_node := CanvasLayer.new()
	shop_node.set_script(shop_script)
	shop_node.set("shop_id", shop_id)
	get_tree().current_scene.add_child(shop_node)


func _update_sight_ray() -> void:
	if sight_ray:
		sight_ray.target_position = facing_direction * 16 * line_of_sight_range
