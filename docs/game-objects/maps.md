# Maps

## Overview

Maps define encounter tables -- weighted pools of creatures that spawn when the player walks through grass zones. Each map file corresponds to an encounter table ID used by the overworld encounter system.

The game world is a single procedurally built map (80x60 tiles, 16px each) divided into three regions:

- **Village** -- cols 0-39, rows 0-29
- **Route 2 (The Deepwood)** -- cols 0-39, rows 30-59
- **Route 3 (Eastern Wilderness)** -- cols 40-79, rows 30-59

There are no separate map scenes; the entire world is one Node2D tree built at runtime by `map_builder.gd`.

## Data Schema

Each map is a standalone JSON file in `data/maps/`. The filename (minus `.json`) becomes the encounter table ID.

```
data/maps/route_1.json
data/maps/route_2.json
```

Schema:

```json
{
  "name": "Village",
  "description": "Flavor text shown in UI.",
  "encounters": [
    {
      "creature_id": "goblin",
      "level_min": 2,
      "level_max": 5,
      "weight": 45
    }
  ]
}
```

| Field | Type | Description |
|---|---|---|
| `name` | string | Display name for the area. |
| `description` | string | Flavor text. |
| `encounters` | array | Weighted list of spawnable creatures. |
| `encounters[].creature_id` | string | References a creature in `data/characters/characters.json`. |
| `encounters[].level_min` | int | Minimum spawn level (inclusive). |
| `encounters[].level_max` | int | Maximum spawn level (inclusive). |
| `encounters[].weight` | int | Relative spawn weight. Higher = more common. |

Current maps:
- `route_1` -- Village outskirts (7 creatures, levels 2-7)
- `route_2` -- Village Road south (10 creatures, levels 4-7)

## Code Paths

### Godot (game engine)

| File | Role |
|---|---|
| `scripts/overworld/map_builder.gd` | Builds the entire map procedurally on `_ready()`. Places tiles, buildings, trees, props, encounter areas, NPCs, and borders. |
| `scripts/overworld/grass_area.gd` | Area2D script attached to encounter zones. Listens for `player_moved` signal and rolls encounters at 15% per step. |
| `scripts/autoload/data_loader.gd` | Loads all `data/maps/*.json` files at startup. Extracts `encounters` arrays keyed by filename. |
| `scripts/autoload/battle_manager.gd` | `start_wild_battle()` fetches the encounter table via `DataLoader.get_encounter_table()`, calls `_roll_encounter()` to do weighted random selection, and launches the battle scene. |

### Web (asset browser)

| File | Role |
|---|---|
| `web/backend/routers/maps.py` | REST API: `GET /api/maps/`, `POST /api/maps/`, `PUT /api/maps/{map_id}`, `DELETE /api/maps/{map_id}`. |
| `web/backend/services/data_service.py` | File I/O: `get_all_maps`, `create_map`, `update_map`, `delete_map`. Each map is its own JSON file. |

## How to Add/Modify

### Adding a new encounter table

1. Create `data/maps/<table_id>.json` with the schema above. The filename is the table ID.
2. `DataLoader` automatically picks up any `.json` file in `data/maps/` on game start.
3. In `map_builder.gd`, create encounter areas that reference the new table ID:
   ```gdscript
   _create_encounter_area("my_grass", tile_x, tile_y, width, height, "my_table_id")
   ```

### Modifying encounter weights

Edit the `weight` values in the JSON file. Weights are relative -- the actual probability is `weight / sum(all_weights)`.

### Adding a new map region

1. The map canvas is 80x60 tiles. To expand, increase `MAP_W` or `MAP_H` in `map_builder.gd` and add a new `_build_route_N()` method.
2. Call the builder method from `_ready()`.
3. Add tree walls or collision borders to control access between regions.
4. Create encounter areas with `_create_encounter_area()` referencing an existing or new table ID.
5. Call `_update_camera_limits()` after building (already called in `_ready()`).

## Runtime Behavior

### Map construction (on scene load)

`map_builder.gd._ready()` executes in order:
1. `_define_road_layout()` -- populates `_road_cells` dictionary with tile positions for roads.
2. `_build_tilemap()` -- creates `GroundLayer` (random grass) and `RoadLayer` (auto-tiled roads) as TileMapLayers.
3. `_place_buildings()` -- houses, well, using "The Fan-tasy Tileset" sprites.
4. `_place_trees()` -- border trees, village boundary walls (with gaps for exits), scattered interior trees and bushes. All trees have StaticBody2D collision.
5. `_place_props()` -- signs, barrels, crates, benches, lampposts.
6. `_place_encounter_areas()` -- creates Area2D zones with `grass_area.gd` attached. Visual indicator: semi-transparent green ColorRect.
7. `_place_npcs()` -- quest givers, merchants, rivals, recruitable NPCs. Checks `GameManager.get_flag()` to hide already-recruited/defeated NPCs.
8. `_place_map_borders()` -- invisible StaticBody2D walls at map edges plus an internal wall blocking direct village-to-Route-3 access.
9. `_build_route_2()` / `_build_route_3()` -- additional encounter areas, trees, and props for wilderness regions.
10. `_update_camera_limits()` -- syncs the player's Camera2D limits to the full map dimensions.

### Encounter triggering

1. Player enters an encounter zone (Area2D). `grass_area.gd` connects to the player's `player_moved` signal.
2. On each movement step inside the zone, a random roll is made against `encounter_rate` (default 0.15 = 15%).
3. On success, `_trigger_encounter()` rolls enemy count: 50% chance of 1 creature, 35% chance of 2, 15% chance of 3.
4. `BattleManager.start_wild_battle(table_id, count)` is called.
5. `BattleManager._roll_encounter()` performs weighted random selection: accumulates weights, rolls a random float in `[0, total_weight]`, picks the first entry whose cumulative weight exceeds the roll.
6. For each selected creature, a level is chosen uniformly from `[level_min, level_max]`.
7. The battle scene is instantiated and `setup_battle()` is called with player and enemy teams.

### Depth sorting

Sprites use Y-sort: `z_index` is set to the pixel Y coordinate so objects further down the screen render in front. NPCs update their `z_index` every physics frame.

### Camera

The player's Camera2D limits are set to `(MAP_W * TILE, MAP_H * TILE)` so the camera follows the player but stops at map edges.
