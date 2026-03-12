# Data Models & JSON Schema

All game content is defined in JSON files under `data/` and loaded by `DataLoader` at startup.

## CreatureInstance (`scripts/battle/creature_instance.gd`)

The runtime representation of a creature. Created via the static factory method `CreatureInstance.create(creature_id, level)`.

### Properties

```gdscript
# Identity
creature_id: String        # e.g., "flame_squire"
nickname: String           # Display name, e.g., "Flame Squire"
level: int

# Base stats (from JSON)
base_hp: int
base_attack: int
base_defense: int
base_sp_attack: int
base_sp_defense: int
base_speed: int

# Calculated stats (scaled by level)
max_hp: int                # base_hp * level / 50 + 10 + level
attack: int                # base_stat * level / 50 + 5
defense: int
sp_attack: int
sp_defense: int
speed: int

# Runtime state
current_hp: int
status_effect: String      # "poison", "burn", "sleep", "paralysis", "freeze", or ""
status_turns: int

# Types and moves
types: Array[String]       # e.g., ["fire"]
moves: Array[Dictionary]   # [{id: "fire_bolt", current_pp: 25, max_pp: 25}, ...]

# Progression
experience: int
```

### Key Methods

- `create(id, level)` — Static factory. Loads base data from `DataLoader`, calculates stats, learns moves up to level.
- `take_damage(amount)` — Reduces `current_hp`, clamped to 0.
- `heal(amount)` / `full_heal()` — Restores HP. `full_heal` also clears status.
- `is_fainted()` — Returns `current_hp <= 0`.
- `gain_experience(amount)` — Adds XP, handles level-up and stat recalculation. Returns `true` if leveled up.

## Creature JSON Schema (`data/creatures/`)

```json
{
  "flame_squire": {
    "name": "Flame Squire",
    "description": "A young warrior wreathed in flame.",
    "types": ["fire"],
    "base_hp": 44,
    "base_attack": 52,
    "base_defense": 43,
    "base_sp_attack": 60,
    "base_sp_defense": 50,
    "base_speed": 65,
    "base_exp": 62,
    "class": "warrior",
    "evolution": {
      "creature_id": "inferno_knight",
      "level": 16,
      "description": "Evolves into Inferno Knight at level 16"
    },
    "learnset": [
      {"level": 1, "move_id": "sword_strike"},
      {"level": 1, "move_id": "ember_guard"},
      {"level": 6, "move_id": "fire_bolt"},
      {"level": 10, "move_id": "war_cry"}
    ]
  }
}
```

### Current Creatures

**Starters (3):**
- Flame Squire (fire) — warrior class
- Grove Druid (grass) — healer class
- Tide Cleric (water) — cleric class

**Wild (10+):**
- Goblin, Spark Thief, Goblin Firebomber, Hex Weaver, Stone Sentinel, Mischievous Fairy, and more

## Move JSON Schema (`data/moves/moves.json`)

```json
{
  "fire_bolt": {
    "name": "Fire Bolt",
    "type": "fire",
    "category": "special",
    "power": 40,
    "accuracy": 100,
    "pp": 25,
    "description": "Hurls a bolt of fire at the target.",
    "effect": {"status": "burn"},
    "effect_chance": 10
  },
  "war_cry": {
    "name": "War Cry",
    "type": "normal",
    "category": "status",
    "power": 0,
    "accuracy": 100,
    "pp": 30,
    "description": "An intimidating shout that lowers the foe's attack.",
    "effect": {"stat": "attack", "stages": -1, "target": "enemy"}
  },
  "iron_guard": {
    "name": "Iron Guard",
    "type": "steel",
    "category": "status",
    "power": 0,
    "accuracy": 100,
    "pp": 20,
    "description": "Raises the user's defense.",
    "effect": {"stat": "defense", "stages": 1, "target": "self"}
  }
}
```

### Move Categories

| Category | Behavior |
|---|---|
| `physical` | Uses `attack` vs `defense` |
| `special` | Uses `sp_attack` vs `sp_defense` |
| `status` | No damage; applies stat changes or status conditions |

### Effect Fields

- `effect.stat` + `effect.stages` + `effect.target` — Stat modification ("self" or "enemy")
- `effect.status` — Status condition to inflict ("poison", "burn", etc.)
- `effect_chance` — Percentage chance for a damaging move's side-effect to trigger

## Encounter Table JSON (`data/maps/`)

```json
{
  "name": "Route 1",
  "encounters": [
    {"creature_id": "goblin", "level_min": 2, "level_max": 5, "weight": 35},
    {"creature_id": "spark_thief", "level_min": 3, "level_max": 5, "weight": 20},
    {"creature_id": "goblin_firebomber", "level_min": 3, "level_max": 4, "weight": 15}
  ]
}
```

- `weight`: Relative probability. Higher weight = more common.
- `level_min` / `level_max`: Random level range for the encounter.

## Save Data Format (`user://save_0.json`)

```json
{
  "player_name": "Captain",
  "gold": 500,
  "guild_ranks": [],
  "story_flags": {"fairy_recruited": true},
  "party": [
    {
      "creature_id": "flame_squire",
      "nickname": "Flame Squire",
      "level": 7,
      "current_hp": 32,
      "experience": 245
    }
  ],
  "barracks": [],
  "inventory": {},
  "position": {"x": 208, "y": 208},
  "map": ""
}
```

Note: Only creature identity and progression are saved. Stats are recalculated from base data on load.
