# NPCs

## Overview

NPCs are characters stored in `data/characters/characters.json` with `"category": "npc"`. They share the same schema as creatures (same file, same API) but carry additional NPC-specific fields for dialogue, sprites, battle configuration, and sounds. At runtime, `map_builder.gd` instantiates them into the overworld using `npc.gd`, which handles interaction, battles, recruitment, quests, and merchant behavior.

## Data Schema

Each NPC is a keyed entry in `characters.json`. All standard creature fields apply (`name`, `description`, `types`, `base_hp`, etc.). Pure non-combat NPCs typically zero out base stats and set `"class": "npc"`. NPC-specific fields:

| Field | Type | Description |
|---|---|---|
| `category` | `string` | Always `"npc"` for NPCs. |
| `npc_sprite` | `string` | `res://` path to the overworld sprite image (e.g. `"res://assets/sprites/npcs/town_guard.png"`). Used by `DialogueManager` to load the sprite at map build time. |
| `dialogues` | `object` | Map of dialogue ID to dialogue entry. Each entry has a `lines` array. See Dialogue Structure below. |
| `is_hostile` | `bool` | Whether the NPC initiates combat. Used by the web editor's battle config section. Default `false`. |
| `lead_creature` | `{creature_id, level}` | The NPC's primary battle creature (web editor field). |
| `roster` | `[{creature_id, level}]` | Additional party members for battle (web editor field). |
| `reserves` | `[{creature_id, level}]` | Reserve creatures, max 3 (web editor field). |
| `sounds` | `[{type, path}]` | Audio clips. `type` is one of `"attack"`, `"defend"`, `"greet"`. `path` is a `res://` audio file path. The `"greet"` sound plays on proximity. |
| `has_overworld_sprite` | `bool` | Informal flag indicating whether an overworld sprite exists for this character. |
| `has_battle_sprite` | `bool` | Informal flag indicating whether a battle sprite exists for this character. |

### Dialogue Structure

Each dialogue entry in the `dialogues` map:

```json
{
  "dialogue_id": {
    "lines": [
      {
        "text": "Dialogue text here.",
        "speaker": "NPC Name",
        "choices": [
          {
            "text": "Choice label",
            "id": "choice_action_id",
            "next": [
              { "text": "Follow-up line.", "speaker": "NPC Name" }
            ]
          }
        ]
      }
    ]
  }
}
```

- `choices` is optional on any line. When present, the player picks from the listed options.
- `id` on a choice maps to a handler in `DialogueManager._on_choice_made()` (e.g. `"recruit_fairy"`, `"rest"`).
- `next` is the follow-up lines shown after the choice is selected.
- Quest givers use suffixed dialogue IDs by convention: `<id>`, `<id>_active`, `<id>_complete`, `<id>_done`.

## Code Paths

| File | Role |
|---|---|
| `data/characters/characters.json` | Source of truth for all NPC data (stats, dialogues, sprites, sounds). |
| `scripts/overworld/npc.gd` | Runtime NPC behavior: interaction dispatch, rival battles, quest handling, merchant opening, line-of-sight aggro, proximity greet. |
| `scripts/overworld/map_builder.gd` | Spawns NPCs into the map via `_create_npc()` in `_place_npcs()`. Loads sprite from dialogue data, creates collision shape, applies config extras. |
| `scripts/autoload/dialogue_manager.gd` | Autoload. Loads all dialogues from `characters.json` at startup. Drives the dialogue UI, handles choice actions (recruitment, rest), manages the active NPC reference. |
| `assets/sprites/npcs/` | Overworld sprite images referenced by `npc_sprite`. |
| `web/backend/models/schemas.py` | Pydantic `Creature` model (shared for creatures and NPCs). Includes `npc_sprite`, `dialogues`, `is_hostile`, `lead_creature`, `roster`, `reserves`, `sounds`. |
| `web/frontend/src/pages/DataEditor/CreatureForm.tsx` | Web editor form with NPC-specific sections for battle config and dialogues. |

## How to Add/Modify

### Via the Web Editor

1. Create or edit a creature and set its **Category** to `npc`.
2. Fill in the **NPC Sprite Path** (`res://assets/sprites/npcs/<filename>.png`).
3. Use the **Battle Configuration** section to toggle `is_hostile` and configure `lead_creature`, `roster`, and `reserves` if the NPC fights.
4. Use the **Dialogues** section to add dialogue entries with IDs, lines, and optional choices.
5. Save. The web API writes back to `characters.json`.

### Via JSON

Edit `data/characters/characters.json` directly. Add a new keyed entry with `"category": "npc"`, the relevant NPC fields, and at least one dialogue entry. Non-combat NPCs should zero out base stats and set `"class": "npc"`.

### Map Placement (map_builder.gd)

Add a call to `_create_npc()` inside `_place_npcs()`:

```gdscript
_create_npc("NPC Name", "dialogue_id", Vector2i(x, y), {
    # Optional config — any npc.gd @export property:
    "quest_id": "quest_name",
    "quest_role": "giver",          # or "step"
    "is_rival": true,
    "rival_party": [{"creature_id": "id", "level": 5}],
    "rival_reserves": [{"creature_id": "id", "level": 3}],
    "defeated_flag": "flag_name",
    "post_defeat_dialogue_id": "dialogue_after_defeat",
    "disappear_on_defeat": false,
    "defeat_quest_id": "quest_name",
    "recruited_flag": "flag_name",
    "recruit_creature_id": "id",    # peaceful recruitment (no battle)
    "recruit_creature_level": 5,
    "is_merchant": true,
    "shop_id": "shop_name",
    "line_of_sight_range": 4,       # tiles, for rival aggro
})
```

Wrap in `if not GameManager.get_flag("flag"):` to hide NPCs that have been defeated or recruited.

## Runtime Behavior

### Interaction Flow

When the player interacts with an NPC (`npc.gd.interact()`), the following priority chain runs:

1. **Merchant** -- if `is_merchant` and `shop_id` are set, opens the shop UI immediately.
2. **Quest role** -- if `quest_id` and `quest_role` are set:
   - **Giver**: starts the quest on first talk, shows `_active` dialogue while in progress, completes the quest and shows `_complete` dialogue when all steps are done, shows `_done` dialogue thereafter.
   - **Step**: advances the quest step if the player is on the matching `quest_step_index`, otherwise falls through to normal dialogue.
3. **Recruited** -- if the NPC's `recruited_flag` is already set, shows a recruited-variant dialogue or a generic fallback.
4. **Rival defeated** -- if `is_rival` and the `defeated_flag` is set, shows `post_defeat_dialogue_id` (typically a recruitment offer).
5. **Rival not defeated** -- if `is_rival` and not yet defeated, plays the NPC's dialogue then starts a battle.
6. **Normal dialogue** -- plays the dialogue by `dialogue_id`, or `simple_lines` as fallback, or `"..."` if neither exists.

### Battles

- Rival NPCs use `rival_party` (array of `{creature_id, level}`) or the single `rival_creature_id`/`rival_creature_level`.
- The lead creature is a persistent `CreatureInstance` created at spawn. Battle damage carries through to recruitment.
- Additional party members beyond the first are created fresh each encounter.
- `rival_reserves` provides swap-in creatures (up to 3).
- On victory: sets `defeated_flag`, advances `defeat_quest_id`, and either removes the NPC (`disappear_on_defeat`) or shows `post_defeat_dialogue_id`.

### Recruitment

Two paths:

- **Peaceful**: NPC has `recruit_creature_id`/`recruit_creature_level` and a dialogue with a recruit choice. Selecting the choice triggers `DialogueManager._handle_recruit()`, which sets the flag, adds the persistent `creature_instance` to the party (full-healed), and removes the NPC from the scene.
- **Post-battle**: After defeating a rival, `post_defeat_dialogue_id` presents a recruit choice. Same handler applies.

If the party is full, the recruited creature goes to the barracks.

### Line of Sight (Rivals)

Rival NPCs have a `SightRay` (RayCast2D) that checks each physics frame. If the player enters the ray's range (`line_of_sight_range` tiles, default 4), the NPC initiates a duel automatically.

### Proximity Greet

Every NPC spawns an `Area2D` with a 32px (~2 tile) radius. When the player enters, `AudioManager.play_character_sound(character_id, "greet")` fires. A 15-second debounce prevents repeated triggers.

### Dialogue Display

Dialogues are shown via `DialogueManager`, which instantiates a `dialogue_box.tscn` scene. Lines display with a typewriter effect. Multi-line sequences advance on input. Choice lines present buttons; the selected `id` dispatches to `_on_choice_made()` for special actions. The NPC's `npc_sprite` is used as a portrait sourced from the dialogue data.
