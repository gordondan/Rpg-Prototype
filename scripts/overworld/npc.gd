extends CharacterBody2D
## NPC with dialogue (simple or branching) and optional rival battle.

const CreatureInstance = preload("res://scripts/battle/creature_instance.gd")

@export var npc_name: String = "Villager"
@export var dialogue_id: String = ""  # References data/dialogue/*.json
@export var simple_lines: Array[String] = []  # Fallback if no dialogue_id

@export var is_rival: bool = false
@export var rival_creature_id: String = ""
@export var rival_creature_level: int = 5
@export var defeated_flag: String = ""
@export var line_of_sight_range: int = 4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sight_ray: RayCast2D = $SightRay

var facing_direction := Vector2.DOWN


func _ready() -> void:
	add_to_group("npc")
	if is_rival and sight_ray:
		_update_sight_ray()


func _physics_process(_delta: float) -> void:
	if is_rival and sight_ray and not _is_defeated():
		sight_ray.force_raycast_update()
		if sight_ray.is_colliding():
			var collider := sight_ray.get_collider()
			if collider.is_in_group("player"):
				_initiate_rival_duel()


func interact() -> void:
	## Called when the player presses interact facing this NPC.
	if DialogueManager.is_active():
		return

	if is_rival and not _is_defeated():
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


func _is_defeated() -> bool:
	return defeated_flag != "" and GameManager.get_flag(defeated_flag)


func _update_sight_ray() -> void:
	if sight_ray:
		sight_ray.target_position = facing_direction * 16 * line_of_sight_range
