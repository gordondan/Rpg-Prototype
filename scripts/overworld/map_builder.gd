extends Node2D
## Builds the village map programmatically using the Fan-tasy Tileset.
## Creates TileMapLayers for ground and roads, places buildings/trees/props as sprites.

const TILE := 16
const MAP_W := 40
const MAP_H := 30

# --- Tileset image paths ---
const GROUND_IMG := "res://assets/sprites/tilesets/The Fan-tasy Tileset (Free)/Art/Ground Tileset/Tileset_Ground.png"
const ROAD_IMG := "res://assets/sprites/tilesets/The Fan-tasy Tileset (Free)/Art/Ground Tileset/Tileset_Road.png"

# --- Sprite paths ---
const SPRITE_DIR := "res://assets/sprites/tilesets/The Fan-tasy Tileset (Free)/Art/"
const SPRITE_PATHS := {
	"house1": "Buildings/House_Hay_1.png",
	"house2": "Buildings/House_Hay_2.png",
	"house3": "Buildings/House_Hay_3.png",
	"house4": "Buildings/House_Hay_4_Purple.png",
	"well": "Buildings/Well_Hay_1.png",
	"gate": "Buildings/CityWall_Gate_1.png",
	"tree1": "Trees and Bushes/Tree_Emerald_1.png",
	"tree2": "Trees and Bushes/Tree_Emerald_2.png",
	"tree3": "Trees and Bushes/Tree_Emerald_3.png",
	"tree4": "Trees and Bushes/Tree_Emerald_4.png",
	"bush1": "Trees and Bushes/Bush_Emerald_1.png",
	"bush2": "Trees and Bushes/Bush_Emerald_2.png",
	"bush3": "Trees and Bushes/Bush_Emerald_3.png",
	"sign1": "Props/Sign_1.png",
	"sign2": "Props/Sign_2.png",
	"barrel": "Props/Barrel_Small_Empty.png",
	"bench1": "Props/Bench_1.png",
	"bench3": "Props/Bench_3.png",
	"bulletin": "Props/BulletinBoard_1.png",
	"crate": "Props/Crate_Medium_Closed.png",
	"haystack": "Props/HayStack_2.png",
	"lamppost": "Props/LampPost_3.png",
	"sack": "Props/Sack_3.png",
	"banner": "Props/Banner_Stick_1_Purple.png",
	"table": "Props/Table_Medium_1.png",
	"plant": "Props/Plant_2.png",
	"chopped_tree": "Props/Chopped_Tree_1.png",
}

# Grass atlas coords (solid grass tile variations in the ground tileset, rows 8-9)
const GRASS_TILES := [
	Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8),
	Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8),
	Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9),
	Vector2i(3, 9), Vector2i(4, 9), Vector2i(5, 9),
]

# Road tile atlas coords for the 3x3 road block pattern:
#   TL  TOP  TR        (1,0) (2,0) (3,0)
#   L   CTR  R    =>   (1,1) (2,1) (3,1)
#   BL  BOT  BR        (1,2) (2,2) (3,2)
const ROAD_TL := Vector2i(1, 0)
const ROAD_TOP := Vector2i(2, 0)
const ROAD_TR := Vector2i(3, 0)
const ROAD_L := Vector2i(1, 1)
const ROAD_CTR := Vector2i(2, 1)
const ROAD_R := Vector2i(3, 1)
const ROAD_BL := Vector2i(1, 2)
const ROAD_BOT := Vector2i(2, 2)
const ROAD_BR := Vector2i(3, 2)

# Loaded textures cache
var _tex_cache: Dictionary = {}

# Road cell positions
var _road_cells: Dictionary = {}

# TileSet sources
var _ground_source_id: int = -1
var _road_source_id: int = -1


func _ready() -> void:
	_define_road_layout()
	_build_tilemap()
	_place_buildings()
	_place_trees()
	_place_props()
	_place_encounter_areas()
	_place_npcs()
	_place_map_borders()


# --- Texture loading (bypasses Godot import system) ---
func _load_texture(res_path: String) -> ImageTexture:
	var global_path := ProjectSettings.globalize_path(res_path)
	var image := Image.new()
	var err := image.load(global_path)
	if err != OK:
		err = image.load(res_path)
	if err != OK:
		push_warning("MapBuilder: Failed to load texture: %s" % res_path)
		return null
	return ImageTexture.create_from_image(image)


func _get_sprite_tex(key: String) -> ImageTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path: String = SPRITE_DIR + SPRITE_PATHS[key]
	var tex := _load_texture(path)
	if tex:
		_tex_cache[key] = tex
	return tex


# --- Road layout definition ---
func _define_road_layout() -> void:
	# Main vertical road (2 tiles wide): columns 19-20, rows 4-27
	for y in range(4, 28):
		_road_cells[Vector2i(19, y)] = true
		_road_cells[Vector2i(20, y)] = true

	# Horizontal road (2 tiles tall): columns 10-28, rows 12-13
	for x in range(10, 29):
		_road_cells[Vector2i(x, 12)] = true
		_road_cells[Vector2i(x, 13)] = true

	# Small village plaza: columns 18-21, rows 11-14
	for x in range(18, 22):
		for y in range(11, 15):
			_road_cells[Vector2i(x, y)] = true

	# Path to western houses: columns 12-19, rows 7-8
	for x in range(12, 20):
		_road_cells[Vector2i(x, 7)] = true
		_road_cells[Vector2i(x, 8)] = true

	# Path to eastern houses: columns 20-27, rows 7-8
	for x in range(20, 28):
		_road_cells[Vector2i(x, 7)] = true
		_road_cells[Vector2i(x, 8)] = true


# --- TileMap construction ---
func _build_tilemap() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)

	# Load ground tileset
	var ground_tex := _load_texture(GROUND_IMG)
	if ground_tex:
		var ground_source := TileSetAtlasSource.new()
		ground_source.texture = ground_tex
		ground_source.texture_region_size = Vector2i(TILE, TILE)
		# Create tiles for 12 columns x 11 rows
		for y in range(11):
			for x in range(12):
				ground_source.create_tile(Vector2i(x, y))
		_ground_source_id = tileset.add_source(ground_source)

	# Load road tileset
	var road_tex := _load_texture(ROAD_IMG)
	if road_tex:
		var road_source := TileSetAtlasSource.new()
		road_source.texture = road_tex
		road_source.texture_region_size = Vector2i(TILE, TILE)
		# Create tiles for 6 columns x 14 rows
		for y in range(14):
			for x in range(6):
				road_source.create_tile(Vector2i(x, y))
		_road_source_id = tileset.add_source(road_source)

	# --- Ground layer ---
	var ground_layer := TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.tile_set = tileset
	ground_layer.z_index = -10
	add_child(ground_layer)

	# Fill with random grass tiles
	for y in range(MAP_H):
		for x in range(MAP_W):
			var grass_tile: Vector2i = GRASS_TILES[randi() % GRASS_TILES.size()]
			ground_layer.set_cell(Vector2i(x, y), _ground_source_id, grass_tile)

	# --- Road layer ---
	if _road_source_id >= 0:
		var road_layer := TileMapLayer.new()
		road_layer.name = "RoadLayer"
		road_layer.tile_set = tileset
		road_layer.z_index = -9
		add_child(road_layer)

		for cell_pos in _road_cells:
			var atlas := _resolve_road_tile(cell_pos)
			road_layer.set_cell(cell_pos, _road_source_id, atlas)


func _resolve_road_tile(pos: Vector2i) -> Vector2i:
	## Pick the correct road tile based on neighboring road cells.
	var has_top := _road_cells.has(pos + Vector2i(0, -1))
	var has_bot := _road_cells.has(pos + Vector2i(0, 1))
	var has_left := _road_cells.has(pos + Vector2i(-1, 0))
	var has_right := _road_cells.has(pos + Vector2i(1, 0))

	# Check diagonals for corner detection
	var has_tl := _road_cells.has(pos + Vector2i(-1, -1))
	var has_tr := _road_cells.has(pos + Vector2i(1, -1))
	var has_bl := _road_cells.has(pos + Vector2i(-1, 1))
	var has_br := _road_cells.has(pos + Vector2i(1, 1))

	# All four sides = center (or inner corner)
	if has_top and has_bot and has_left and has_right:
		# Check for inner corners
		if not has_tl:
			return Vector2i(4, 0)  # Inner corner: missing top-left diagonal
		if not has_tr:
			return Vector2i(5, 0)  # Inner corner: missing top-right diagonal
		if not has_bl:
			return Vector2i(4, 1)  # Inner corner: missing bottom-left diagonal
		if not has_br:
			return Vector2i(5, 1)  # Inner corner: missing bottom-right diagonal
		return ROAD_CTR

	# Three sides (T-junctions) - use edge tiles
	if has_top and has_bot and has_right and not has_left:
		return ROAD_L  # Left edge (open on left)
	if has_top and has_bot and has_left and not has_right:
		return ROAD_R  # Right edge (open on right)
	if has_left and has_right and has_bot and not has_top:
		return ROAD_TOP  # Top edge (open on top)
	if has_left and has_right and has_top and not has_bot:
		return ROAD_BOT  # Bottom edge (open on bottom)

	# Two sides (corners and straight)
	if has_top and has_bot:
		# Vertical road with no left/right - approximate with center
		return ROAD_CTR
	if has_left and has_right:
		# Horizontal road with no top/bottom
		return ROAD_CTR
	if has_bot and has_right:
		return ROAD_TL
	if has_bot and has_left:
		return ROAD_TR
	if has_top and has_right:
		return ROAD_BL
	if has_top and has_left:
		return ROAD_BR

	# Single side or isolated
	return ROAD_CTR


# --- Sprite placement helpers ---
func _place_sprite(key: String, pixel_pos: Vector2, collision_size := Vector2.ZERO, z := 0) -> Sprite2D:
	var tex := _get_sprite_tex(key)
	if not tex:
		return null

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = pixel_pos
	sprite.z_index = z
	# Anchor at bottom center for natural layering
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	add_child(sprite)

	if collision_size != Vector2.ZERO:
		var body := StaticBody2D.new()
		body.position = pixel_pos
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = collision_size
		shape.shape = rect
		# Offset collision to bottom portion of sprite
		shape.position = Vector2(0, -collision_size.y / 2.0)
		body.add_child(shape)
		add_child(body)

	return sprite


func _place_sprite_at_tile(key: String, tile_x: int, tile_y: int, collision_size := Vector2.ZERO) -> Sprite2D:
	var px := tile_x * TILE + TILE / 2.0
	var py := tile_y * TILE + TILE
	return _place_sprite(key, Vector2(px, py), collision_size, 0)


# --- Building placement ---
func _place_buildings() -> void:
	# Houses around the village
	_place_sprite_at_tile("house1", 8, 6, Vector2(80, 40))    # Northwest house
	_place_sprite_at_tile("house3", 28, 6, Vector2(80, 40))   # Northeast house
	_place_sprite_at_tile("house2", 8, 16, Vector2(140, 50))  # Southwest tavern
	_place_sprite_at_tile("house4", 29, 16, Vector2(80, 40))  # Southeast house

	# Well in village plaza
	_place_sprite_at_tile("well", 20, 10, Vector2(30, 20))


# --- Tree placement ---
func _place_trees() -> void:
	# Top border trees
	var tree_keys := ["tree1", "tree2", "tree3", "tree4"]
	for x in range(0, MAP_W, 2):
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, x, 1, Vector2(24, 16))
		if x < 8 or x > 32:
			_place_sprite_at_tile(key, x, 3, Vector2(24, 16))

	# Bottom border trees
	for x in range(0, MAP_W, 2):
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, x, MAP_H - 1, Vector2(24, 16))

	# Left border trees
	for y in range(2, MAP_H - 1, 2):
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, 1, y, Vector2(24, 16))
		_place_sprite_at_tile(key, 3, y, Vector2(24, 16))

	# Right border trees
	for y in range(2, MAP_H - 1, 2):
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, MAP_W - 2, y, Vector2(24, 16))
		_place_sprite_at_tile(key, MAP_W - 4, y, Vector2(24, 16))

	# Scattered interior trees
	var interior_trees := [
		Vector2i(6, 10), Vector2i(14, 5), Vector2i(25, 5),
		Vector2i(33, 10), Vector2i(6, 20), Vector2i(33, 20),
		Vector2i(14, 18), Vector2i(25, 18),
		Vector2i(10, 22), Vector2i(30, 22),
	]
	for pos in interior_trees:
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, pos.x, pos.y, Vector2(24, 16))

	# Bushes scattered around
	var bush_keys := ["bush1", "bush2", "bush3"]
	var bush_positions := [
		Vector2i(10, 5), Vector2i(12, 10), Vector2i(27, 10),
		Vector2i(15, 15), Vector2i(24, 15), Vector2i(11, 20),
		Vector2i(28, 20), Vector2i(16, 24), Vector2i(23, 24),
	]
	for pos in bush_positions:
		var key: String = bush_keys[randi() % bush_keys.size()]
		_place_sprite_at_tile(key, pos.x, pos.y, Vector2(16, 12))


# --- Prop placement ---
func _place_props() -> void:
	# Sign near village entrance
	_place_sprite_at_tile("sign1", 18, 4, Vector2(16, 14))

	# Bulletin board near plaza
	_place_sprite_at_tile("bulletin", 22, 10, Vector2(20, 16))

	# Barrels near tavern
	_place_sprite_at_tile("barrel", 5, 16, Vector2(14, 14))
	_place_sprite_at_tile("barrel", 6, 17, Vector2(14, 14))

	# Crates near houses
	_place_sprite_at_tile("crate", 12, 6, Vector2(16, 14))
	_place_sprite_at_tile("crate", 32, 6, Vector2(16, 14))

	# Bench near plaza
	_place_sprite_at_tile("bench1", 17, 11, Vector2(12, 12))

	# Lamppost
	_place_sprite_at_tile("lamppost", 21, 7, Vector2(10, 10))
	_place_sprite_at_tile("lamppost", 18, 14, Vector2(10, 10))

	# Haystack near barn
	_place_sprite_at_tile("haystack", 13, 16, Vector2(20, 14))


# --- Encounter areas (tall grass for random battles) ---
func _place_encounter_areas() -> void:
	# West grass patch
	_create_encounter_area("west_grass", 5, 21, 8, 5)
	# East grass patch
	_create_encounter_area("east_grass", 27, 21, 8, 5)


func _create_encounter_area(area_name: String, tile_x: int, tile_y: int, width: int, height: int) -> void:
	var area := Area2D.new()
	area.name = area_name
	var script := load("res://scripts/overworld/grass_area.gd")
	if script:
		area.set_script(script)
		area.set("encounter_rate", 0.15)
		area.set("encounter_table_id", "route_1")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width * TILE, height * TILE)
	shape.shape = rect
	shape.position = Vector2.ZERO
	area.add_child(shape)

	# Position at center of the area
	area.position = Vector2(
		tile_x * TILE + (width * TILE) / 2.0,
		tile_y * TILE + (height * TILE) / 2.0
	)

	add_child(area)

	# Visual indicator: slightly different colored grass
	var indicator := ColorRect.new()
	indicator.color = Color(0.15, 0.45, 0.12, 0.3)
	indicator.size = Vector2(width * TILE, height * TILE)
	indicator.position = Vector2(
		tile_x * TILE,
		tile_y * TILE
	)
	indicator.z_index = -8
	add_child(indicator)


# --- NPC placement ---
func _place_npcs() -> void:
	_create_npc("Village Guard", "village_guard", Vector2i(19, 5))
	_create_npc("Old Scholar", "old_scholar", Vector2i(23, 10))
	_create_npc("Tavern Keeper", "tavern_keeper", Vector2i(10, 15))
	_create_npc("Mysterious Stranger", "mysterious_stranger", Vector2i(30, 22))


func _create_npc(npc_name: String, dialogue_id: String, tile_pos: Vector2i) -> void:
	var npc := CharacterBody2D.new()
	npc.name = npc_name.replace(" ", "")
	npc.position = Vector2(tile_pos.x * TILE + TILE / 2.0, tile_pos.y * TILE + TILE / 2.0)

	var script := load("res://scripts/overworld/npc.gd")
	if script:
		npc.set_script(script)
		npc.set("npc_name", npc_name)
		npc.set("dialogue_id", dialogue_id)

	# Collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	col.shape = rect
	npc.add_child(col)

	# AnimatedSprite2D (required by npc.gd)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	npc.add_child(sprite)

	# SightRay (required by npc.gd)
	var sight_ray := RayCast2D.new()
	sight_ray.name = "SightRay"
	sight_ray.target_position = Vector2(0, 64)
	npc.add_child(sight_ray)

	# Visual placeholder for NPC (colored circle)
	var placeholder := ColorRect.new()
	placeholder.name = "Placeholder"
	placeholder.size = Vector2(12, 12)
	placeholder.position = Vector2(-6, -6)
	placeholder.color = _get_npc_color(npc_name)
	npc.add_child(placeholder)

	# NPC name label
	var label := Label.new()
	label.name = "NameLabel"
	label.text = npc_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -20)
	label.size = Vector2(80, 14)
	label.add_theme_font_size_override("font_size", 8)
	npc.add_child(label)

	add_child(npc)
	npc.add_to_group("npc")


func _get_npc_color(npc_name: String) -> Color:
	match npc_name:
		"Village Guard":
			return Color(0.8, 0.2, 0.2)  # Red
		"Old Scholar":
			return Color(0.6, 0.4, 0.8)  # Purple
		"Tavern Keeper":
			return Color(0.8, 0.6, 0.2)  # Orange
		"Mysterious Stranger":
			return Color(0.2, 0.2, 0.4)  # Dark blue
		_:
			return Color(0.5, 0.5, 0.5)  # Gray


# --- Map border collision ---
func _place_map_borders() -> void:
	var border_thickness := 32.0

	# Top wall
	_add_wall(Vector2(MAP_W * TILE / 2.0, -border_thickness / 2.0),
			  Vector2(MAP_W * TILE + border_thickness * 2, border_thickness))
	# Bottom wall
	_add_wall(Vector2(MAP_W * TILE / 2.0, MAP_H * TILE + border_thickness / 2.0),
			  Vector2(MAP_W * TILE + border_thickness * 2, border_thickness))
	# Left wall
	_add_wall(Vector2(-border_thickness / 2.0, MAP_H * TILE / 2.0),
			  Vector2(border_thickness, MAP_H * TILE + border_thickness * 2))
	# Right wall
	_add_wall(Vector2(MAP_W * TILE + border_thickness / 2.0, MAP_H * TILE / 2.0),
			  Vector2(border_thickness, MAP_H * TILE + border_thickness * 2))


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	add_child(body)
