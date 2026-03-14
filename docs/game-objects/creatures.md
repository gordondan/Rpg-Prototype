# Creatures

## Overview

Creatures are the central game objects in MonsterQuest. Every combatant -- player starters, wild encounters, and named NPCs -- is defined as a creature entry in `data/characters/characters.json`. Each entry stores base stats, typing, class, a level-indexed learnset, and category-specific fields for recruitment, evolution, dialogue, and sprites. At runtime, the Godot engine instantiates creatures as `CreatureInstance` resources that track level, calculated stats, current HP, status effects, and known moves.

## Data Schema

All creatures live in a single flat JSON object keyed by creature ID (snake_case string). The canonical file is `data/characters/characters.json`. A parallel copy at `data/creatures/creatures.json` contains the combat-capable subset only.

### Core Fields (all categories)

| Field | Type | Description |
|---|---|---|
| `name` | string | Display name. |
| `description` | string | Flavor text shown in UI. |
| `types` | string[] | One or two elemental types. Valid values: `fire`, `aqua`, `wind`, `nature`, `storm`, `shadow`, `construct`, `witch`, `warrior`, `poison`, `normal`. |
| `base_hp` | int | Base HP stat. Also used by `DataLoader` to distinguish combat creatures from dialogue-only NPCs. |
| `base_attack` | int | Base physical attack. |
| `base_defense` | int | Base physical defense. |
| `base_sp_attack` | int | Base special attack. |
| `base_sp_defense` | int | Base special defense. |
| `base_speed` | int | Base speed. |
| `base_exp` | int | Base experience yield when defeated. |
| `class` | string | Creature archetype (e.g. `warrior`, `cleric`, `rogue`, `monster`, `witch`, `demon`, `guardian`, `beast`, `ranger`, `druid`, `knight`). |
| `category` | string | One of `starter`, `wild`, or `npc`. Determines game behavior (see Runtime Behavior). |
| `learnset` | object[] | Moves learned by level. Each entry: `{ "level": int, "move_id": string }`. |

### Optional Fields

| Field | Type | Categories | Description |
|---|---|---|---|
| `evolution` | object | starter, wild | `{ "creature_id": string, "level": int, "flavor": string }`. The creature this evolves into and at what level. |
| `recruit_method` | string | wild | How the creature can be recruited (e.g. `"defeat"`). |
| `recruit_chance` | float | wild | Probability (0.0--1.0) of recruitment success. |
| `recruit_dialogue` | string | wild | Text spoken when the creature joins the party. |
| `recruitable` | bool | wild | Set to `false` to explicitly prevent recruitment. Mutually exclusive with `recruit_method`. |

### NPC-Specific Fields

| Field | Type | Description |
|---|---|---|
| `npc_sprite` | string | Godot resource path to the overworld sprite (e.g. `"res://assets/sprites/npcs/..."`). |
| `dialogues` | object | Map of dialogue ID to dialogue entry. Each entry contains a `lines` array of `{ "text", "speaker", "choices?" }`. |
| `sounds` | object[] | Audio cues. Each entry: `{ "type": string, "path": string }`. |
| `is_hostile` | bool | Whether this NPC initiates combat. Default `false`. |
| `lead_creature` | object | `{ "creature_id": string, "level": int }`. The NPC's primary battle creature. |
| `roster` | object[] | Active battle party. Each entry: `{ "creature_id": string, "level": int }`. |
| `reserves` | object[] | Bench creatures. Same format as `roster`. |

## Code Paths

### Godot (GDScript)

| File | Role |
|---|---|
| `scripts/autoload/data_loader.gd` | Loads `data/characters/characters.json` at startup. Filters to entries with `base_hp` to populate the creatures dictionary. Provides `get_creature_data(id)`, `get_all_creature_ids()`. |
| `scripts/battle/creature_instance.gd` | Runtime resource class. Factory method `CreatureInstance.create(id, level)` reads base stats from DataLoader, calculates level-scaled stats, and populates the move list from the learnset. Tracks `current_hp`, `status_effect`, `moves` (max 4), `experience`, `level`. |
| `scripts/autoload/game_manager.gd` | Manages `player_party` (max 6) and `barracks` (overflow). Handles add/remove/swap, save/load serialization, and party-wipe checks. |
| `scripts/battle/battle_scene.gd` | Battle rendering. Contains `SPRITE_OVERRIDES` and `SPRITE_RANDOM_POOLS` dictionaries for creatures whose battle sprites deviate from the standard naming convention. |

### Web App (FastAPI + React)

| File | Role |
|---|---|
| `web/backend/services/data_service.py` | Reads/writes `data/characters/characters.json`. CRUD operations plus view-order management (`view_order.json`). |
| `web/backend/routers/creatures.py` | REST API: `GET/POST/PUT/DELETE /api/creatures/`, `GET/PUT /api/creatures/view-order`. |
| `web/backend/models/schemas.py` | Pydantic `Creature` model defining the full schema with all optional NPC fields. |
| `web/frontend/src/api/creatures.ts` | TypeScript API client for creature endpoints. |

### Sprites and Animations

Sprites follow a convention-based path under `assets/sprites/creatures/`:

- Overworld: `{creature_id}.png`
- Battle: `{creature_id}_battle.png`

When a creature has animations, they are organized in a per-creature folder:

```
assets/sprites/creatures/{creature_id}/
├── overworld.png
├── battle.png
├── idle/
│   ├── spritesheet.png
│   ├── metadata.json
│   └── idle.tres          # Generated Godot SpriteFrames or Animation resource
└── walk/
    ├── spritesheet.png
    ├── metadata.json
    └── walk.tres
```

Legacy flat-file sprites (e.g. `flame_squire.png`) continue to work. The backend checks both locations. Animation `.tres` resources are generated by `SpriteSheetService` from the sprite sheet metadata (frame dimensions, grid layout, FPS, loop settings).

NPC overworld sprites use the `npc_sprite` field path instead (typically under `assets/sprites/npcs/`). Some creatures have hardcoded sprite overrides or random sprite pools defined in `battle_scene.gd`.

### Asset Services

| File | Role |
|---|---|
| `web/backend/services/asset_service.py` | Image upload processing: resize to 128x128 + background removal for character images, pass-through for animations and maps. |
| `web/backend/services/spritesheet_service.py` | Generates Godot `.tres` resource files (SpriteFrames for AnimatedSprite2D, Animation for AnimationPlayer) from sprite sheet metadata. |
| `web/backend/services/gemini_service.py` | Optional Gemini vision integration to auto-detect sprite sheet grid layout (frame size, columns, rows, frame count). Requires `GEMINI_API_KEY` env var. |
| `web/backend/routers/assets.py` | Asset endpoints including upload (with `image_type` routing), `/analyze-spritesheet/`, `/generate-animation-resource`, `/animations/{creature_id}`. |

## How to Add/Modify

### Via the Web Editor

1. Navigate to the Creatures section in the asset browser.
2. Click "Create" to add a new creature (auto-generates an ID like `new_creature_1`). Pass `?category=npc` to create an NPC.
3. Fill in or edit fields in the form. The web app writes directly to `data/characters/characters.json`.
4. Upload sprites using the "Sprites & Animations" card. Character images (overworld/battle) are resized and background-removed automatically. For animation sprite sheets, select "Animation (Sprite 2D)" or "Animation (Player)", provide frame metadata, and the system generates Godot `.tres` resources.

### Via JSON

1. Open `data/characters/characters.json`.
2. Add a new key (the creature ID) with the required core fields.
3. If the creature is wild and recruitable, add `recruit_method`, `recruit_chance`, and `recruit_dialogue`.
4. If the creature is an NPC, add `dialogues`, `npc_sprite`, and optionally `roster`/`lead_creature`.
5. Add the corresponding sprite files. If the battle sprite does not follow the `{id}_battle.png` convention, add an entry to `SPRITE_OVERRIDES` in `scripts/battle/battle_scene.gd`.
6. If the creature should appear in wild encounters, add it to the relevant map file in `data/maps/`.

## Runtime Behavior

### Stat Calculation

Stats are computed from base values using a Gen III-style formula (hardcoded IV of 31, no EVs):

- **HP**: `floor((2 * base_hp + 31) * level / 100) + level + 10`
- **Other stats**: `floor((2 * base_stat + 31) * level / 100) + 5`

### Experience and Leveling

- Experience curve: medium-fast (`level^3` XP needed per level).
- Max level: 100.
- On level-up, stats are recalculated and HP increases by the difference in max HP. Any move in the learnset matching the new level is learned automatically if the creature knows fewer than 4 moves.

### Category Behavior

- **starter**: Offered to the player at game start. May have evolution data.
- **wild**: Spawned from map encounter tables. Recruitable creatures have a post-battle recruitment roll based on `recruit_chance`. Setting `recruitable: false` skips the roll entirely.
- **npc**: Story characters with dialogue trees, custom sprites, and optionally their own battle rosters. The Godot `DataLoader` only loads NPC entries that have `base_hp` -- entries without it are treated as dialogue-only NPCs handled by `DialogueManager`.

### Party Management

- Active party holds up to 6 `CreatureInstance` objects. The first 3 are active in battle; the rest are reserves.
- Overflow creatures go to the barracks.
- Party and barracks are serialized to save files via `GameManager`.
