extends CharacterBody2D
## Grid-based player controller with animated character sprite.
## Uses the Fan-tasy Tileset character sprite sheets loaded at runtime.

const TILE_SIZE := 16
const MOVE_SPEED := 4.0  # Tiles per second

# Character sprite sheet paths
const IDLE_SHEET := "res://assets/sprites/tilesets/The Fan-tasy Tileset (Free)/Art/Characters/Main Character/Character_Idle.png"
const WALK_SHEET := "res://assets/sprites/tilesets/The Fan-tasy Tileset (Free)/Art/Characters/Main Character/Character_Walk.png"

# Sprite sheets: 4 columns x 4 rows = 40x48 per frame
# Row 0 = down, Row 1 = left, Row 2 = right, Row 3 = up
const FRAME_COLS := 4
const FRAME_ROWS := 4
const ANIM_FPS := 8.0  # Frames per second for walk animation

@onready var ray: RayCast2D = $RayCast2D

var is_moving := false
var facing_direction := Vector2.DOWN

# Sprite references
var _char_sprite: Sprite2D
var _idle_texture: ImageTexture
var _walk_texture: ImageTexture
var _anim_timer := 0.0
var _current_frame := 0
var _is_walking := false

# Signals
signal player_moved(new_position: Vector2)
signal player_interacted(facing_tile: Vector2)


func _ready() -> void:
	add_to_group("player")
	z_index = 5  # Render above map objects (trees, buildings, props are z_index 0)
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	_load_character_sprites()
	_update_sprite_frame()


func _load_character_sprites() -> void:
	_idle_texture = _load_texture(IDLE_SHEET)
	_walk_texture = _load_texture(WALK_SHEET)

	# Create the character Sprite2D
	_char_sprite = Sprite2D.new()
	_char_sprite.name = "CharacterSprite"
	_char_sprite.hframes = FRAME_COLS
	_char_sprite.vframes = FRAME_ROWS
	_char_sprite.texture = _idle_texture
	# Offset so feet align with tile position
	_char_sprite.offset = Vector2(0, -8)
	add_child(_char_sprite)

	# Fallback: if textures failed to load, show a colored placeholder
	if _idle_texture == null:
		push_warning("Player: Sprite textures failed to load — showing placeholder")
		var placeholder := ColorRect.new()
		placeholder.name = "Placeholder"
		placeholder.color = Color(0.2, 0.5, 1.0, 0.9)  # Blue square
		placeholder.size = Vector2(12, 14)
		placeholder.position = Vector2(-6, -14)
		add_child(placeholder)


func _load_texture(res_path: String) -> ImageTexture:
	var global_path := ProjectSettings.globalize_path(res_path)
	var image := Image.load_from_file(global_path)
	if image == null:
		image = Image.load_from_file(res_path)
	if image == null:
		push_warning("Player: Failed to load sprite: %s" % res_path)
		return null
	return ImageTexture.create_from_image(image)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_player_free():
		return

	if event.is_action_pressed("inventory"):
		_open_party_editor()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") and not is_moving:
		var target_pos := position + facing_direction * TILE_SIZE
		if not _try_interact_with_npc(target_pos):
			player_interacted.emit(target_pos)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# Handle walk animation frame cycling
	if _is_walking:
		_anim_timer += delta
		if _anim_timer >= 1.0 / ANIM_FPS:
			_anim_timer -= 1.0 / ANIM_FPS
			_current_frame = (_current_frame + 1) % FRAME_COLS
			_update_sprite_frame()

	if is_moving:
		return

	# Don't process input when player isn't free (menu, battle, dialogue, etc.)
	if not GameManager.is_player_free():
		return

	var input_direction := _get_input_direction()

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction
		_set_walking(true)
		_update_raycast()

		ray.force_raycast_update()

		if not ray.is_colliding():
			_move_to(position + input_direction * TILE_SIZE)
		else:
			_set_walking(false)
	else:
		_set_walking(false)


func _try_interact_with_npc(target_pos: Vector2) -> bool:
	## Check if there's an NPC at the target position and interact with them.
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.position.distance_to(target_pos) < TILE_SIZE:
			if npc.has_method("interact"):
				npc.interact()
				return true
	return false


func _get_input_direction() -> Vector2:
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
	is_moving = true
	var tween := create_tween()
	tween.tween_property(self, "position", target, 1.0 / MOVE_SPEED)
	tween.tween_callback(_on_move_finished)


func _on_move_finished() -> void:
	is_moving = false
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	player_moved.emit(position)


func _set_walking(walking: bool) -> void:
	if walking == _is_walking:
		return
	_is_walking = walking
	if walking:
		_char_sprite.texture = _walk_texture
		_current_frame = 0
		_anim_timer = 0.0
	else:
		_char_sprite.texture = _idle_texture
		_current_frame = 0
	_update_sprite_frame()


func _update_sprite_frame() -> void:
	if not _char_sprite:
		return
	var row := _direction_to_row(facing_direction)
	_char_sprite.frame = row * FRAME_COLS + _current_frame


func _direction_to_row(dir: Vector2) -> int:
	# Sprite sheet rows: 0=Left, 1=Right, 2=Up, 3=Down
	if dir == Vector2.DOWN:
		return 3
	elif dir == Vector2.UP:
		return 2
	elif dir == Vector2.LEFT:
		return 0
	elif dir == Vector2.RIGHT:
		return 1
	return 3  # Default to down


func _open_party_editor() -> void:
	var editor_scene := load("res://scenes/ui/party_editor.tscn")
	if editor_scene:
		GameManager.set_state(GameManager.GameState.MENU)
		var instance: Node = editor_scene.instantiate()
		get_tree().current_scene.add_child(instance)


func _update_raycast() -> void:
	ray.target_position = facing_direction * TILE_SIZE
