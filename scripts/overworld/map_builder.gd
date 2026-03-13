extends Node2D
## Builds the village map programmatically using the Fan-tasy Tileset.
## Creates TileMapLayers for ground and roads, places buildings/trees/props as sprites.

const TILE := 16
const MAP_W := 80  # West half (cols 0-39) + Route 3 east half (cols 40-79)
const MAP_H := 60  # Village (rows 0-29) + Route 2/3 (rows 30-59)
const VILLAGE_W := 40  # Columns belonging to the village / Route 2

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
var _tex_cache: Dictionary = {}  # String -> Texture2D

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
	_build_route_2()
	_build_route_3()
	_update_camera_limits()


# --- Texture loading ---
func _load_texture(res_path: String) -> Texture2D:
	var tex = load(res_path)
	if tex == null:
		push_warning("MapBuilder: Failed to load texture: %s" % res_path)
		return null
	return tex


func _get_sprite_tex(key: String) -> Texture2D:
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

	# Route 2 south path — continues the central road through the wilderness
	for y in range(28, 57):
		_road_cells[Vector2i(19, y)] = true
		_road_cells[Vector2i(20, y)] = true

	# Route 3 east path — horizontal branch from the south road into Route 3
	for x in range(21, 74):
		_road_cells[Vector2i(x, 43)] = true
		_road_cells[Vector2i(x, 44)] = true


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
	# Use the sprite's foot Y position as z_index so objects further down the screen
	# (higher Y) render in front of objects further up (lower Y) — Y-sort depth.
	return _place_sprite(key, Vector2(px, py), collision_size, int(py))


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

	# Bottom border trees (actual map edge)
	for x in range(0, MAP_W, 2):
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, x, MAP_H - 1, Vector2(24, 16))

	# Village south boundary at row 29 — tree wall with a gap for the south exit
	for x in range(0, VILLAGE_W, 2):
		if x >= 18 and x <= 20:
			continue  # Leave exit path open (aligns with central road cols 19-20)
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, x, 29, Vector2(24, 16))

	# Village east boundary at col 39-41 — tree wall stopping players from
	# walking east into Route 3 from inside the village (rows 0-29)
	for y in range(2, 29, 2):
		var key: String = tree_keys[randi() % tree_keys.size()]
		_place_sprite_at_tile(key, VILLAGE_W - 1, y, Vector2(24, 16))
		_place_sprite_at_tile(key, VILLAGE_W + 1, y, Vector2(24, 16))

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
		Vector2i(5, 12), Vector2i(14, 5), Vector2i(22, 3),
		Vector2i(35, 11), Vector2i(15, 20), Vector2i(33, 20),
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


func _create_encounter_area(area_name: String, tile_x: int, tile_y: int, width: int, height: int, table_id: String = "route_1") -> void:
	var area := Area2D.new()
	area.name = area_name
	var script := load("res://scripts/overworld/grass_area.gd")
	if script:
		area.set_script(script)
		area.set("encounter_rate", 0.15)
		area.set("encounter_table_id", table_id)

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
	_create_npc("Village Guard", "village_guard", Vector2i(19, 5), {
		"quest_id": "defeat_zacharias",
		"quest_role": "giver",
	})
	_create_npc("Old Scholar", "old_scholar", Vector2i(23, 10))
	_create_npc("Tavern Keeper", "tavern_keeper", Vector2i(10, 18))
	_create_npc("Mysterious Stranger", "mysterious_stranger", Vector2i(34, 18))
	_create_npc("Elara", "elara", Vector2i(13, 9), {"quest_id": "meet_elara", "quest_role": "step", "quest_step_index": 0})
	_create_npc("Sylwen", "sylwen", Vector2i(22, 17), {"quest_id": "meet_elara", "quest_role": "giver"})

	# Merchant — near the village plaza
	_create_npc("Village Merchant", "village_merchant", Vector2i(25, 11), {
		"is_merchant": true,
		"shop_id": "village_merchant",
	})

	# Recruitable NPCs — only show if not yet recruited
	if not GameManager.get_flag("fairy_recruited"):
		_create_npc("Mischievous Fairy", "mischievous_fairy", Vector2i(15, 14), {
			"recruited_flag": "fairy_recruited",
			"recruit_creature_id": "mischievous_fairy",
			"recruit_creature_level": 5,
		})

	# Aqua Monk — peaceful recruitable, meditating near the spring
	if not GameManager.get_flag("aqua_monk_recruited"):
		_create_npc("Aqua Monk", "aqua_monk", Vector2i(8, 12), {
			"recruited_flag": "aqua_monk_recruited",
			"recruit_creature_id": "aqua_monk",
			"recruit_creature_level": 7,
		})

	# Zacharias — aggressive gang leader with two Spark Thief wingmen
	if not GameManager.get_flag("zacharias_recruited"):
		_create_npc("Zacharias", "zacharias", Vector2i(20, 25), {
			"is_rival": true,
			"rival_party": [
				{"creature_id": "zacharias", "level": 5},
				{"creature_id": "spark_thief", "level": 3},
				{"creature_id": "spark_thief", "level": 3},
			],
			"defeated_flag": "zacharias_defeated",
			"post_defeat_dialogue_id": "zacharias_defeated",
			"recruited_flag": "zacharias_recruited",
			"defeat_quest_id": "defeat_zacharias",
			"line_of_sight_range": 5,
		})

	# Mog — goblin firebomber boss with a pack of goblins, disappears on defeat
	if not GameManager.get_flag("mog_defeated"):
		_create_npc("Mog", "mog", Vector2i(20, 20), {
			"is_rival": true,
			"rival_party": [
				{"creature_id": "goblin_firebomber", "level": 5},
				{"creature_id": "goblin", "level": 3},
				{"creature_id": "goblin", "level": 3},
			],
			"rival_reserves": [
				{"creature_id": "goblin", "level": 3},
			],
			"defeated_flag": "mog_defeated",
			"post_defeat_dialogue_id": "mog_defeated",
			"disappear_on_defeat": true,
			"line_of_sight_range": 4,
		})

	# Alexia — aggressive rival elf, can be battled then recruited
	if not GameManager.get_flag("alexia_recruited"):
		_create_npc("Alexia Ranger", "alexia_ranger", Vector2i(30, 8), {
			"is_rival": true,
			"rival_creature_id": "alexia",
			"rival_creature_level": 8,
			"defeated_flag": "alexia_defeated",
			"post_defeat_dialogue_id": "alexia_ranger_defeated",
			"recruited_flag": "alexia_recruited",
			"line_of_sight_range": 5,
			"character_id": "alexia",
		})

	# -------------------------------------------------------------------------
	# FUTURE ROUTE BOSSES — uncomment and set tile_pos when building each route
	# -------------------------------------------------------------------------

	# Grix — bat tamer, Route 2 boss
	if not GameManager.get_flag("grix_defeated"):
		_create_npc("Grix", "grix", Vector2i(19, 53), {
			"is_rival": true,
			"rival_party": [
				{"creature_id": "goblin", "level": 5},
				{"creature_id": "giant_bat", "level": 4},
				{"creature_id": "giant_bat", "level": 4},
			],
			"rival_reserves": [
				{"creature_id": "giant_bat", "level": 3},
				{"creature_id": "goblin", "level": 2},
				{"creature_id": "goblin", "level": 2},
			],
			"defeated_flag": "grix_defeated",
			"post_defeat_dialogue_id": "grix_defeated",
			"disappear_on_defeat": true,
			"line_of_sight_range": 5,
		})

	# Skrag — mixed raider, uses ork_grunt + ork_warrior alongside firebomber
	# if not GameManager.get_flag("skrag_defeated"):
	# 	_create_npc("Skrag", "skrag", Vector2i(0, 0), {
	# 		"is_rival": true,
	# 		"rival_party": [
	# 			{"creature_id": "goblin_firebomber", "level": 6},
	# 			{"creature_id": "ork_warrior", "level": 5},
	# 			{"creature_id": "ork_grunt", "level": 4},
	# 		],
	# 		"rival_reserves": [
	# 			{"creature_id": "ork_grunt", "level": 4},
	# 			{"creature_id": "goblin", "level": 3},
	# 			{"creature_id": "goblin", "level": 3},
	# 		],
	# 		"defeated_flag": "skrag_defeated",
	# 		"post_defeat_dialogue_id": "skrag_defeated",
	# 		"disappear_on_defeat": true,
	# 		"line_of_sight_range": 4,
	# 	})

	# Urk — all three orc tiers in one fight, goblin rabble in reserve
	# if not GameManager.get_flag("urk_defeated"):
	# 	_create_npc("Urk", "urk", Vector2i(0, 0), {
	# 		"is_rival": true,
	# 		"rival_party": [
	# 			{"creature_id": "orc_battleaxman", "level": 7},
	# 			{"creature_id": "ork_warrior", "level": 6},
	# 			{"creature_id": "ork_grunt", "level": 5},
	# 		],
	# 		"rival_reserves": [
	# 			{"creature_id": "ork_grunt", "level": 4},
	# 			{"creature_id": "goblin", "level": 4},
	# 			{"creature_id": "goblin", "level": 4},
	# 		],
	# 		"defeated_flag": "urk_defeated",
	# 		"post_defeat_dialogue_id": "urk_defeated",
	# 		"disappear_on_defeat": true,
	# 		"line_of_sight_range": 5,
	# 	})

	# Zog — warchief, hardest goblin boss (all three orc tiers + firebomber)
	# if not GameManager.get_flag("zog_defeated"):
	# 	_create_npc("Zog", "zog", Vector2i(0, 0), {
	# 		"is_rival": true,
	# 		"rival_party": [
	# 			{"creature_id": "goblin_firebomber", "level": 8},
	# 			{"creature_id": "orc_battleaxman", "level": 7},
	# 			{"creature_id": "ork_warrior", "level": 7},
	# 		],
	# 		"rival_reserves": [
	# 			{"creature_id": "ork_grunt", "level": 6},
	# 			{"creature_id": "goblin", "level": 5},
	# 			{"creature_id": "goblin", "level": 5},
	# 		],
	# 		"defeated_flag": "zog_defeated",
	# 		"post_defeat_dialogue_id": "zog_defeated",
	# 		"disappear_on_defeat": true,
	# 		"line_of_sight_range": 5,
	# 	})


func _create_npc(npc_name: String, dialogue_id: String, tile_pos: Vector2i, extras: Dictionary = {}) -> void:
	var npc := CharacterBody2D.new()
	npc.name = npc_name.replace(" ", "")
	npc.position = Vector2(tile_pos.x * TILE + TILE / 2.0, tile_pos.y * TILE + TILE / 2.0)

	var script := load("res://scripts/overworld/npc.gd")
	if script:
		npc.set_script(script)
		npc.set("npc_name", npc_name)
		npc.set("dialogue_id", dialogue_id)
		# Apply any extra properties (is_rival, rival_creature_id, etc.)
		for key in extras:
			npc.set(key, extras[key])

	# AnimatedSprite2D (required by npc.gd)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	npc.add_child(sprite)

	# SightRay (required by npc.gd)
	var sight_ray := RayCast2D.new()
	sight_ray.name = "SightRay"
	sight_ray.target_position = Vector2(0, 64)
	npc.add_child(sight_ray)

	# Load sprite from dialogue data if available — do this before collision so
	# we can size the hitbox to match the actual sprite width.
	var npc_data: Dictionary = DialogueManager.get_dialogue_data(dialogue_id)
	var sprite_path: String = npc_data.get("sprite", "")
	var sprite_loaded := false
	var loaded_tex: Texture2D = null
	if sprite_path != "":
		loaded_tex = _load_texture(sprite_path)
		if loaded_tex:
			var npc_sprite := Sprite2D.new()
			npc_sprite.name = "NPCSprite"
			npc_sprite.texture = loaded_tex
			npc_sprite.offset = Vector2(0, -loaded_tex.get_height() / 2.0)
			npc_sprite.z_index = 1
			npc.add_child(npc_sprite)
			sprite_loaded = true

	# Fallback: colored placeholder if no sprite loaded
	if not sprite_loaded:
		var placeholder := ColorRect.new()
		placeholder.name = "Placeholder"
		placeholder.size = Vector2(12, 12)
		placeholder.position = Vector2(-6, -6)
		placeholder.color = _get_npc_color(npc_name)
		npc.add_child(placeholder)

	# Collision — sized to match the sprite footprint.
	# Width mirrors the sprite width (clamped to a sensible range).
	# Height is a fixed 12 px representing the character's feet at ground level.
	# The shape is offset upward by half its height so it sits at the base of the sprite.
	var col_w := 14.0
	var col_h := 12.0
	if loaded_tex:
		col_w = clampf(float(loaded_tex.get_width()), 10.0, 32.0)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(col_w, col_h)
	col.position = Vector2(0, -col_h / 2.0)
	col.shape = rect
	npc.add_child(col)

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
		"Mischievous Fairy":
			return Color(0.9, 0.5, 0.9)  # Pink/magenta
		"Village Merchant":
			return Color(0.9, 0.8, 0.2)  # Gold/yellow
		"Alexia Ranger":
			return Color(0.2, 0.7, 0.3)  # Forest green
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

	# Internal east village wall — blocks access into the eastern wilderness
	# from inside the village (rows 0-29). Route 3 is only reachable via Route 2.
	var village_wall_height := float(30 * TILE)
	_add_wall(
		Vector2(VILLAGE_W * TILE, village_wall_height / 2.0),
		Vector2(border_thickness, village_wall_height)
	)


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	add_child(body)


# ─── Route 2 — The Deepwood ─────────────────────────────────────────────────

func _build_route_2() -> void:
	## Populate the wilderness south of the village (rows 30-58).
	## The central road is already extended by _define_road_layout().
	_place_route2_marker()
	_place_route2_encounter_areas()
	_place_route2_trees()
	_place_route2_props()


func _place_route2_marker() -> void:
	## Waymarker sign at the top of Route 2, just past the village exit.
	_place_sprite_at_tile("sign2", 21, 31, Vector2(16, 14))


func _place_route2_encounter_areas() -> void:
	## Three tall-grass encounter zones using the route_2 table.
	# West wilderness patch
	_create_encounter_area("route2_west",  4, 36, 10, 9, "route_2")
	# East wilderness patch
	_create_encounter_area("route2_east", 26, 36, 10, 9, "route_2")
	# South patch near Grix — more dangerous area
	_create_encounter_area("route2_south", 9, 50,  8, 6, "route_2")


func _place_route2_trees() -> void:
	## Sparse trees for the open-wilderness feel — fewer than the village.
	var tree_keys := ["tree1", "tree2", "tree3", "tree4"]
	var bush_keys := ["bush1", "bush2", "bush3"]

	# Northern scatter (just past the village boundary)
	var north_trees := [
		Vector2i(6, 32), Vector2i(13, 31), Vector2i(24, 32), Vector2i(34, 31),
	]
	for pos in north_trees:
		_place_sprite_at_tile(tree_keys[randi() % tree_keys.size()], pos.x, pos.y, Vector2(24, 16))

	# Mid scatter (flanking the encounter zones)
	var mid_trees := [
		Vector2i(4, 39), Vector2i(8, 42), Vector2i(30, 40), Vector2i(36, 38),
		Vector2i(5, 45), Vector2i(35, 44),
	]
	for pos in mid_trees:
		_place_sprite_at_tile(tree_keys[randi() % tree_keys.size()], pos.x, pos.y, Vector2(24, 16))

	# Southern scatter (approaches Grix)
	var south_trees := [
		Vector2i(6, 49), Vector2i(14, 51), Vector2i(25, 52), Vector2i(34, 50),
		Vector2i(10, 56), Vector2i(29, 57),
	]
	for pos in south_trees:
		_place_sprite_at_tile(tree_keys[randi() % tree_keys.size()], pos.x, pos.y, Vector2(24, 16))

	# Sparse bushes
	var bushes := [
		Vector2i(11, 35), Vector2i(28, 34),
		Vector2i(7, 44), Vector2i(33, 45),
		Vector2i(22, 49),
	]
	for pos in bushes:
		_place_sprite_at_tile(bush_keys[randi() % bush_keys.size()], pos.x, pos.y, Vector2(16, 12))


func _place_route2_props() -> void:
	## Wilderness props: old stumps, abandoned gear, and a rough camp feel.
	# Old chopped tree stumps — travelers have passed through
	_place_sprite_at_tile("chopped_tree", 12, 34, Vector2(20, 12))
	_place_sprite_at_tile("chopped_tree", 27, 35, Vector2(20, 12))
	_place_sprite_at_tile("chopped_tree",  7, 47, Vector2(20, 12))
	_place_sprite_at_tile("chopped_tree", 32, 46, Vector2(20, 12))

	# Abandoned gear along the road
	_place_sprite_at_tile("barrel",  16, 38, Vector2(14, 14))  # Old barrel by the path
	_place_sprite_at_tile("crate",   23, 42, Vector2(16, 14))  # Abandoned crate
	_place_sprite_at_tile("sack",    17, 47, Vector2(12, 12))  # Dropped sack

	# Rough camp near the south encounter area
	_place_sprite_at_tile("haystack", 11, 51, Vector2(20, 14))
	_place_sprite_at_tile("barrel",   13, 52, Vector2(14, 14))


# ─── Route 3 — Eastern Wilderness ───────────────────────────────────────────

func _build_route_3() -> void:
	## Populate the eastern wilderness (cols 40-79, rows 30-59).
	## Accessible via the horizontal path from Route 2 at rows 43-44.
	## Uses the route_1 encounter pool (village-tier creatures).
	_place_route3_encounter_areas()
	_place_route3_trees()
	_place_route3_props()


func _place_route3_encounter_areas() -> void:
	## Three encounter zones spread across the eastern wilderness.
	_create_encounter_area("route3_north", 44, 32, 10, 9, "route_1")
	_create_encounter_area("route3_south", 60, 47, 10, 8, "route_1")
	_create_encounter_area("route3_far",   44, 50,  8, 6, "route_1")


func _place_route3_trees() -> void:
	## Sparse trees mirroring the open-wilderness feel of Route 2.
	var tree_keys := ["tree1", "tree2", "tree3", "tree4"]
	var bush_keys := ["bush1", "bush2", "bush3"]

	var trees := [
		Vector2i(42, 31), Vector2i(52, 30), Vector2i(63, 32), Vector2i(73, 31),
		Vector2i(41, 40), Vector2i(56, 39), Vector2i(70, 41), Vector2i(77, 38),
		Vector2i(43, 50), Vector2i(58, 52), Vector2i(68, 49), Vector2i(76, 51),
		Vector2i(48, 57), Vector2i(66, 56),
	]
	for pos in trees:
		_place_sprite_at_tile(tree_keys[randi() % tree_keys.size()], pos.x, pos.y, Vector2(24, 16))

	var bushes := [
		Vector2i(55, 36), Vector2i(67, 35),
		Vector2i(46, 47), Vector2i(73, 46),
		Vector2i(59, 54),
	]
	for pos in bushes:
		_place_sprite_at_tile(bush_keys[randi() % bush_keys.size()], pos.x, pos.y, Vector2(16, 12))


func _place_route3_props() -> void:
	## Scattered props giving the eastern wilderness its own identity.
	# Chopped stumps
	_place_sprite_at_tile("chopped_tree", 50, 35, Vector2(20, 12))
	_place_sprite_at_tile("chopped_tree", 69, 37, Vector2(20, 12))
	_place_sprite_at_tile("chopped_tree", 53, 53, Vector2(20, 12))

	# Abandoned traveller gear
	_place_sprite_at_tile("barrel",    64, 42, Vector2(14, 14))
	_place_sprite_at_tile("crate",     54, 46, Vector2(16, 14))
	_place_sprite_at_tile("sack",      72, 50, Vector2(12, 12))

	# Small waymarker at the entrance from Route 2
	_place_sprite_at_tile("sign1", 42, 43, Vector2(16, 14))


# ─── Camera ─────────────────────────────────────────────────────────────────

func _update_camera_limits() -> void:
	## Sync the player's Camera2D limits to the full map dimensions.
	## Called after building so the camera covers the expanded map.
	var player := get_parent().get_node_or_null("Player")
	if not player:
		return
	var cam := player.get_node_or_null("Camera2D")
	if cam is Camera2D:
		cam.limit_right = MAP_W * TILE
		cam.limit_bottom = MAP_H * TILE
