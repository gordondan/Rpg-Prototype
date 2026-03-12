# Overworld System

The overworld is the main exploration space where the player moves on a grid, interacts with NPCs, and triggers encounters.

## Key Files

| File | Role |
|---|---|
| `scripts/overworld/player.gd` | Grid-based movement, animation, NPC interaction |
| `scripts/overworld/npc.gd` | Dialogue triggers, rival battles, line-of-sight |
| `scripts/overworld/grass_area.gd` | Random encounter zones |
| `scripts/overworld/map_builder.gd` | Procedural map generation |
| `scenes/overworld/overworld.tscn` | Main overworld scene |

## Player Movement

- **Grid-based**: 16px tile size, discrete positions
- **Smooth tweening**: Tween interpolation between tiles for visual smoothness
- **4-directional**: Sprite animation frames for up/down/left/right
- **Collision**: RayCast2D checks the target tile before moving
- **Input blocking**: Movement disabled when `GameManager.is_player_free()` returns false (during battles, dialogue, menus)
- **Sprite loading**: Character sprites loaded at runtime with framesheet animation

The player emits a `player_moved` signal after each step, which encounter zones listen to for random battle rolls.

## NPC System

NPCs come in two varieties:

### Simple NPCs
- Export `dialogue_id` (references JSON dialogue data) or `simple_lines` (inline array)
- Player presses interact while facing the NPC → `DialogueManager.start_dialogue(dialogue_id)`

### Rival NPCs
- Export `is_rival = true`, plus `rival_creature_id`, `rival_creature_level`, `defeated_flag`
- `line_of_sight_range` (default 4 tiles) — RayCast2D detects player approach
- On detection: NPC walks toward player → plays dialogue → `BattleManager.start_rival_battle()`
- Non-escapable battles
- On win: `GameManager.set_flag(defeated_flag)` prevents repeat challenges

## Random Encounters (GrassArea)

`GrassArea` is an `Area2D` that triggers random battles when the player steps on it.

### Configuration (exported properties)
- `encounter_rate`: float 0-1 (chance per step)
- `encounter_table_id`: string matching a JSON encounter table

### Flow
1. Player enters the Area2D → script connects to `player.player_moved`
2. Each step: `randf() < encounter_rate` → trigger if true
3. Roll enemy count: 60% chance of 1, 30% chance of 2, 10% chance of 3
4. `BattleManager.start_wild_battle(encounter_table_id, count)`
5. `BattleManager` rolls creatures from the weighted encounter table

### Encounter Table Format (JSON)
```json
{
  "name": "Route 1",
  "encounters": [
    {"creature_id": "goblin", "level_min": 2, "level_max": 5, "weight": 35},
    {"creature_id": "spark_thief", "level_min": 3, "level_max": 5, "weight": 20}
  ]
}
```

Weights are relative — a creature with weight 35 is 35/total_weight likely to appear.

## Map Builder

`MapBuilder` generates the overworld map procedurally at runtime:

- **Runtime texture loading**: Loads tileset PNGs directly from disk, bypassing Godot's import system
- **TileMapLayer creation**: Builds ground and road layers programmatically
- **Procedural placement**: Buildings, trees, props, NPCs, and encounter areas
- **Fallback support**: Generates colored placeholder rectangles when sprites are missing

This approach allows fast iteration — add or change art without re-importing in the Godot editor.
