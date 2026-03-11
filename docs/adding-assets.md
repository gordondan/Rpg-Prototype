# Adding New Assets

## Creature Sprites

Sprites are resolved by creature ID using a naming convention. No metadata configuration is needed.

### Directory

All creature sprites live in `assets/sprites/creatures/`.

### Naming Convention

| Type | Filename | Example |
|------|----------|---------|
| Overworld | `{creature_id}.png` | `flame_squire.png` |
| Battle | `{creature_id}_battle.png` | `flame_squire_battle.png` |
| Variant (optional) | `{creature_id}_{variant}.png` | `spark_thief_male.png` |
| Variant battle (optional) | `{creature_id}_{variant}_battle.png` | `spark_thief_female_battle.png` |

### Adding a New Creature with Sprites

1. Create the creature data in `data/creatures/starters.json` or `data/creatures/wild.json` with a unique ID (e.g., `shadow_wolf`)
2. Add sprite files following the naming convention:
   - `assets/sprites/creatures/shadow_wolf.png` (overworld)
   - `assets/sprites/creatures/shadow_wolf_battle.png` (battle)
3. The web editor will automatically display the sprites — no configuration needed

### Adding Sprites for an Existing Creature

1. Find the creature's ID in `data/creatures/starters.json` or `wild.json`
2. Add the sprite files using that ID as the filename
3. Refresh the web editor

### Godot .import Files

Godot automatically generates `.import` files alongside sprites. These are tracked in git. After renaming or adding sprites, open the project in Godot to regenerate them.

## Maps

Map data lives in `data/maps/`, one JSON file per map (e.g., `data/maps/route_1.json`).

### Adding a New Map

**Via the web editor:**
1. Go to Data Editor > Maps
2. Click "New Map"
3. Enter a map ID (lowercase, underscores, e.g., `forest_clearing`)
4. Fill in name, description, and encounters

**Manually:**
1. Create `data/maps/{map_id}.json`:
```json
{
  "name": "Forest Clearing",
  "description": "A peaceful clearing deep in the forest.",
  "encounters": [
    {
      "creature_id": "grove_druid",
      "level_min": 3,
      "level_max": 7,
      "weight": 10
    }
  ]
}
```

## Quests

Quest data lives in `data/quests/`, one JSON file per quest.

### Adding a New Quest

**Via the web editor:**
1. Go to Data Editor > Quests
2. Click "New Quest"
3. Enter quest ID, name, and map
4. Add stages with the stage editor

**Manually:**
1. Create `data/quests/{quest_id}.json`:
```json
{
  "name": "Clear the Road",
  "description": "Help the guard clear goblins from the road.",
  "map_id": "route_1",
  "prerequisite_quest_id": null,
  "reward": {
    "gold": 500,
    "items": ["healing_potion"],
    "exp": 200
  },
  "stages": [
    {
      "id": "talk_guard",
      "type": "talk_to_npc",
      "description": "Speak with the Village Guard",
      "npc_id": "village_guard",
      "dialogue_id": "quest_start"
    },
    {
      "id": "defeat_goblins",
      "type": "defeat_creatures",
      "description": "Defeat 3 Goblins",
      "creature_id": "goblin",
      "count": 3,
      "map_id": "route_1"
    }
  ]
}
```

### Quest Stage Types

| Type | Required Fields |
|------|----------------|
| `talk_to_npc` | `npc_id`, `dialogue_id` |
| `defeat_creatures` | `creature_id`, `count`, optional `map_id` |
| `collect_items` | `item_id`, `count` |
| `reach_location` | `map_id` |
| `boss_encounter` | `creature_id`, `level` |

All stages require: `id`, `type`, `description`.

## Items

Item data lives in `data/items/items.json` as a single JSON object keyed by item ID.

### Adding a New Item

**Via the web editor:**
1. Go to Data Editor > Items
2. Edit the item you want to modify

**Manually:**
Add an entry to `data/items/items.json`:
```json
{
  "healing_potion": {
    "name": "Healing Potion",
    "description": "Restores 50 HP.",
    "type": "consumable",
    "effect": "heal",
    "value": 50,
    "buy_price": 100,
    "sell_price": 50
  }
}
```

## Moves

Move data lives in `data/moves/moves.json` as a single JSON object keyed by move ID.

### Adding a New Move

Add an entry to `data/moves/moves.json` with the move's stats, type, power, accuracy, and effects.
