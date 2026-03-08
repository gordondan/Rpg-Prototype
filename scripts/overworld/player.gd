extends CharacterBody2D
## Grid-based player controller for a Pokémon-style overworld.
## The player moves tile-by-tile using a tween for smooth animation.

const TILE_SIZE := 16
const MOVE_SPEED := 4.0  # Tiles per second

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray: RayCast2D = $RayCast2D

var is_moving := false
var facing_direction := Vector2.DOWN

# Signals
signal player_moved(new_position: Vector2)
signal player_interacted(facing_tile: Vector2)


func _ready() -> void:
	# Snap to grid on start
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE))


func _physics_process(_delta: float) -> void:
	if is_moving:
		return

	var input_direction := _get_input_direction()

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction
		_update_animation("walk")
		_update_raycast()

		# Force raycast update to check collision immediately
		ray.force_raycast_update()

		if not ray.is_colliding():
			_move_to(position + input_direction * TILE_SIZE)
		else:
			_update_animation("idle")
	else:
		_update_animation("idle")

	if Input.is_action_just_pressed("interact"):
		player_interacted.emit(position + facing_direction * TILE_SIZE)


func _get_input_direction() -> Vector2:
	## Returns a single direction vector based on input priority.
	if Input.is_action_pressed("move_up"):
		return Vector2.UP
	elif Input.is_action_pressed("move_down"):
		return Vector2.DOWN
	elif Input.is_action_pressed("move_left"):
		return Vector2.LEFT
	elif Input.is_action_pressed("move_right"):
		return Vector2.RIGHT
	return Vector2.ZERO


func _move_to(target: Vector2) -> void:
	## Smoothly move to the target position using a tween.
	is_moving = true

	var tween := create_tween()
	tween.tween_property(self, "position", target, 1.0 / MOVE_SPEED)
	tween.tween_callback(_on_move_finished)


func _on_move_finished() -> void:
	is_moving = false
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	player_moved.emit(position)


func _update_animation(state: String) -> void:
	## Update sprite animation based on state and facing direction.
	var dir_name := _direction_to_string(facing_direction)
	var anim_name := "%s_%s" % [state, dir_name]

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation(state):
		sprite.play(state)


func _update_raycast() -> void:
	## Point the raycast in the direction the player is facing.
	ray.target_position = facing_direction * TILE_SIZE


func _direction_to_string(dir: Vector2) -> String:
	if dir == Vector2.UP:
		return "up"
	elif dir == Vector2.DOWN:
		return "down"
	elif dir == Vector2.LEFT:
		return "left"
	elif dir == Vector2.RIGHT:
		return "right"
	return "down"
