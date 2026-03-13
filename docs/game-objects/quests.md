# Quests

## Overview

Quests are multi-step objectives tracked by `GameManager` and driven by NPC interactions. Each quest has a giver NPC who starts/completes it, optional step NPCs who advance it, and a reward of gold and items.

The system supports a "pending advance" mechanism: if the player completes a quest objective (e.g., defeating a boss) before picking up the quest, the step is banked and applied automatically when the quest is later started.

Current quests:
- `defeat_zacharias` -- "The Lightningsworn Gang" (defeat a boss, reward: 120g + 1 healing potion)
- `meet_elara` -- "A Message for Sylwen" (find and talk to an NPC, reward: 75g + 2 healing potions)

## Data Schema

All quests live in a single file: `data/quests/quests.json`. The top-level keys are quest IDs.

```json
{
  "defeat_zacharias": {
    "name": "The Lightningsworn Gang",
    "description": "Zacharias Lightningsworn and his gang...",
    "steps": [
      {
        "id": "defeat_gang",
        "description": "Defeat Zacharias Lightningsworn and his gang on the King's Road"
      }
    ],
    "reward": {
      "gold": 120,
      "items": [
        {"item_id": "healing_potion", "quantity": 1}
      ]
    }
  }
}
```

| Field | Type | Description |
|---|---|---|
| `name` | string | Display name shown in quest log and notifications. |
| `description` | string | Full quest description. |
| `steps` | array | Ordered list of objectives. |
| `steps[].id` | string | Unique step identifier (within the quest). |
| `steps[].description` | string | Text shown in the quest log for this step. |
| `reward` | object | Granted on completion. |
| `reward.gold` | int | Gold amount. |
| `reward.items` | array | Items: `{item_id, quantity}`. |

The web asset browser extends the step schema with a `type` field for future use:

| Step Type | Description |
|---|---|
| `talk_to_npc` | Speak with a specific NPC. |
| `defeat_creatures` | Defeat specific creatures or a boss. |
| `collect_items` | Gather a number of items. |
| `reach_location` | Arrive at a map location. |
| `boss_encounter` | Trigger and win a boss fight. |

These types are defined in `web/backend/models/schemas.py` (`QuestStage.type`) but are not yet consumed by the Godot runtime -- the game engine uses step index tracking only.

## Code Paths

### Godot (game engine)

| File | Role |
|---|---|
| `scripts/autoload/game_manager.gd` | Core quest state: `quests` dict, `_pending_quest_advances` dict. Methods: `start_quest`, `advance_quest_step`, `complete_quest`, `get_quest_status`, `get_quest_step`, `is_quest_active`, `is_quest_completed`, `is_quest_ready_to_complete`. |
| `scripts/autoload/data_loader.gd` | Loads `data/quests/quests.json` at startup into `_quests`. Provides `get_quest_data(quest_id)` and `get_all_quest_ids()`. |
| `scripts/overworld/npc.gd` | NPC quest interaction logic. Properties: `quest_id`, `quest_role` ("giver" or "step"), `quest_step_index`. Method `_handle_quest_interact()` drives the state machine. |
| `scripts/overworld/map_builder.gd` | Wires NPCs to quests via `_create_npc()` extras: `quest_id`, `quest_role`, `quest_step_index`. |
| `scripts/ui/quest_log.gd` | Quest log UI (CanvasLayer). Lists active quests with current step, then completed quests. |
| `scripts/ui/quest_notification.gd` | Toast notification ("New Quest Added!") shown for 2.5s then fades out. |

### Web (asset browser)

| File | Role |
|---|---|
| `web/backend/routers/quests.py` | REST API: `GET /api/quests/`, `GET /api/quests/{quest_id}`, `POST /api/quests/`, `PUT /api/quests/{quest_id}`, `DELETE /api/quests/{quest_id}`. |
| `web/backend/services/data_service.py` | File I/O: `get_all_quests`, `get_quest`, `create_quest`, `update_quest`, `delete_quest`. |
| `web/backend/models/schemas.py` | `QuestStage` model with typed step fields. |
| `web/frontend/src/pages/DataEditor/QuestForm.tsx` | React form for editing quests with step type selection. |

## How to Add/Modify

### Adding a new quest

1. Add a new entry to `data/quests/quests.json` with a unique key (the quest ID).
2. Define `name`, `description`, `steps`, and `reward`.
3. In `map_builder.gd`, assign a giver NPC:
   ```gdscript
   _create_npc("Guard Captain", "guard_captain", Vector2i(x, y), {
       "quest_id": "my_quest",
       "quest_role": "giver",
   })
   ```
4. For each step that requires talking to an NPC, assign a step NPC:
   ```gdscript
   _create_npc("Scout", "scout", Vector2i(x, y), {
       "quest_id": "my_quest",
       "quest_role": "step",
       "quest_step_index": 0,
   })
   ```
5. For steps advanced by defeating a rival, set `defeat_quest_id` on the rival NPC:
   ```gdscript
   _create_npc("Boss", "boss", Vector2i(x, y), {
       "is_rival": true,
       "rival_party": [...],
       "defeat_quest_id": "my_quest",
       ...
   })
   ```
6. Create dialogue entries for the quest giver's variants:
   - `<dialogue_id>` -- initial dialogue (shown when quest is given)
   - `<dialogue_id>_active` -- shown when quest is in progress
   - `<dialogue_id>_complete` -- shown when turning in completed quest
   - `<dialogue_id>_done` -- shown after quest is already completed
   - `<dialogue_id>_quest` -- shown by step NPCs when advancing a step

### Modifying rewards

Edit `reward.gold` and `reward.items` in the quest JSON. Item IDs must exist in `data/items/items.json`.

## Runtime Behavior

### Quest state machine

Each quest tracks two values in `GameManager.quests`:
- `status` -- `"active"` or `"completed"` (absent if not started)
- `step` -- integer index into the `steps` array (0-based)

### Lifecycle

1. **Start**: Player talks to a giver NPC (`quest_role == "giver"`) with no active/completed status. `GameManager.start_quest()` is called. Any banked pending advances are applied to the starting step. A toast notification appears.

2. **Advance**: Steps are advanced in two ways:
   - **Talk to step NPC**: When `quest_role == "step"` and the quest's current step matches `quest_step_index`, `advance_quest_step()` increments the step counter.
   - **Defeat a rival**: When a rival NPC with `defeat_quest_id` is defeated, `advance_quest_step()` is called. If the quest has not been started yet, the advance is banked in `_pending_quest_advances`.

3. **Complete**: Player returns to the giver NPC. `is_quest_ready_to_complete()` checks if `step >= len(steps)`. If true, `complete_quest()` grants `reward.gold` and `reward.items`, and sets status to `"completed"`.

### Pending advance mechanism

`_pending_quest_advances` is a dict of `{quest_id: int}` counting banked step advances. When `advance_quest_step()` is called for a quest that is not active, the count is incremented. When `start_quest()` is later called, the banked count becomes the initial step value. This allows the player to defeat a boss before talking to the quest giver.

### Quest log UI

`quest_log.gd` builds a scrollable panel (CanvasLayer, layer 10) that reads `GameManager.quests` and `DataLoader.get_quest_data()`. Active quests appear first with the current step description highlighted. Completed quests appear below with a checkmark. Opened via the hub menu; closed with the Back button or Escape key.

### Notifications

`quest_notification.gd` creates a top-center toast ("New Quest Added!") that holds for 2.5 seconds, fades out over 0.6 seconds, then frees itself. Spawned by `npc.gd._show_quest_notification()` after the quest-start dialogue ends.
