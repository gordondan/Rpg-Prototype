extends CharacterBody2D
## Basic NPC with dialogue and optional trainer battle.

@export var npc_name: String = "NPC"
@export var dialogue_lines: Array[String] = ["Hello there!"]
@export var is_trainer: bool = false
@export var trainer_creature_id: String = ""
@export var trainer_creature_level: int = 5
@export var defeated_flag: String = ""  # Story flag set when this trainer is beaten
@export var line_of_sight_range: int = 4  # Tiles

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sight_ray: RayCast2D = $SightRay

var facing_direction := Vector2.DOWN
var _current_line := 0


func _ready() -> void:
	add_to_group("npc")
	if is_trainer and sight_ray:
		_update_sight_ray()


func _physics_process(_delta: float) -> void:
	if is_trainer and sight_ray and not _is_defeated():
		sight_ray.force_raycast_update()
		if sight_ray.is_colliding():
			var collider := sight_ray.get_collider()
			if collider.is_in_group("player"):
				_initiate_trainer_battle()


func interact() -> void:
	## Called when the player presses interact facing this NPC.
	if is_trainer and not _is_defeated():
		_show_dialogue_then_battle()
	else:
		_show_dialogue()


func _show_dialogue() -> void:
	if _current_line < dialogue_lines.size():
		# You'd connect this to a dialogue UI system
		print("[%s] %s" % [npc_name, dialogue_lines[_current_line]])
		_current_line += 1

		if _current_line >= dialogue_lines.size():
			_current_line = 0


func _show_dialogue_then_battle() -> void:
	_show_dialogue()
	# After dialogue finishes, start battle
	# In a full implementation, you'd wait for the dialogue to close
	BattleManager.start_trainer_battle(trainer_creature_id, trainer_creature_level)
	BattleManager.battle_finished.connect(_on_trainer_defeated, CONNECT_ONE_SHOT)


func _initiate_trainer_battle() -> void:
	# Exclamation mark animation, walk toward player, etc.
	print("[%s] spotted the player!" % npc_name)
	_show_dialogue_then_battle()


func _on_trainer_defeated(result: String) -> void:
	if result == "win" and defeated_flag != "":
		GameManager.set_flag(defeated_flag)


func _is_defeated() -> bool:
	return defeated_flag != "" and GameManager.get_flag(defeated_flag)


func _update_sight_ray() -> void:
	if sight_ray:
		sight_ray.target_position = facing_direction * 16 * line_of_sight_range
