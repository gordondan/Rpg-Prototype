# Creature Sprites & Quest System Design

## Feature 1: Creature Sprite Metadata

### Problem
Creature JSON data has no sprite fields. The frontend tries to load from a nonexistent path convention, so no sprites display. Actual sprite files use inconsistent naming.

### Solution
Add `sprite_overworld` and `sprite_battle` optional string fields to creature data, storing relative paths from repo root. Provide auto-matching to bulk-populate.

### Data Changes
- Add to `starters.json` and `wild.json`:
  ```json
  "sprite_overworld": "assets/sprites/creatures/Flame_Squire.png",
  "sprite_battle": "assets/sprites/creatures/flame_squire_battle.png"
  ```
- Both fields nullable (null if sprite doesn't exist yet)

### Backend
- Add `sprite_overworld` and `sprite_battle` to Pydantic `Creature` model
- `GET /api/creatures/auto-match-sprites` — scans `assets/sprites/creatures/`, fuzzy-matches filenames to creature IDs, returns suggested `{creature_id: {overworld: path, battle: path}}`
- `POST /api/creatures/apply-sprite-matches` — bulk-updates creature JSONs with matched paths

### Frontend
- `CreatureList.tsx` — show sprite thumbnail via actual path
- `CreatureForm.tsx` — show both sprites with file picker to change each
- Auto-match button to populate sprites for all creatures at once

---

## Feature 2: Quest System (Full CRUD)

### Data Structure
Quests live in `data/quests/*.json`, one file per quest.

```json
{
  "name": "Clear the King's Road",
  "description": "The Village Guard needs help dealing with goblin attacks.",
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
      "dialogue_id": "quest_clear_road_start"
    },
    {
      "id": "kill_goblins",
      "type": "defeat_creatures",
      "description": "Defeat 3 Goblins",
      "creature_id": "goblin",
      "count": 3,
      "map_id": "route_1"
    },
    {
      "id": "collect_loot",
      "type": "collect_items",
      "description": "Collect 2 Goblin Tokens",
      "item_id": "goblin_token",
      "count": 2
    },
    {
      "id": "reach_clearing",
      "type": "reach_location",
      "description": "Reach the forest clearing",
      "map_id": "route_2"
    },
    {
      "id": "boss_fight",
      "type": "boss_encounter",
      "description": "Defeat the Goblin Chief",
      "creature_id": "goblin_firebomber",
      "level": 8
    },
    {
      "id": "return_guard",
      "type": "talk_to_npc",
      "description": "Report back to the Village Guard",
      "npc_id": "village_guard",
      "dialogue_id": "quest_clear_road_complete"
    }
  ]
}
```

### Stage Types

| Type | Required Fields |
|------|----------------|
| `talk_to_npc` | `npc_id`, `dialogue_id` |
| `defeat_creatures` | `creature_id`, `count`, optional `map_id` |
| `collect_items` | `item_id`, `count` |
| `reach_location` | `map_id` |
| `boss_encounter` | `creature_id`, `level` |

All stages share: `id`, `type`, `description`.

Quest chaining via `prerequisite_quest_id` (null = available from start).

### Backend
- Pydantic models: `QuestReward`, `QuestStage`, `Quest`
- DataService: `get_all_quests()`, `get_quest()`, `create_quest()`, `update_quest()`, `delete_quest()`
- Router: `GET /api/quests/`, `GET /api/quests/{id}`, `POST /api/quests/`, `PUT /api/quests/{id}`, `DELETE /api/quests/{id}`

### Frontend
- Sidebar: add "Quests" under Data Editor
- `QuestsList.tsx` — list with search, name, map badge, stage count, "New Quest" button
- `QuestForm.tsx` — name, description, map_id dropdown, prerequisite dropdown, reward editor, ordered stage list with type-conditional fields
- Route: `/editor/quests`
- API client: `src/api/quests.ts`
- Map editor: read-only "Associated Quests" section

---

## Feature 3: Full CRUD for Maps

### Problem
Maps only support read and update. No way to create or delete maps.

### Backend
- DataService: `create_map()`, `delete_map()`
- Router: `POST /api/maps/` (create), `DELETE /api/maps/{id}` (delete)

### Frontend
- "New Map" button in MapsList
- Delete button in MapForm (with confirmation)
