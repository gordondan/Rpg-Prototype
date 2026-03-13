# Dialogue System

The dialogue system handles NPC conversations, branching choices, and special actions (resting, creature recruitment).

## Key Files

| File | Role |
|---|---|
| `scripts/autoload/dialogue_manager.gd` | Loads dialogue JSON, manages dialogue lifecycle |
| `scripts/ui/dialogue_box.gd` | Typewriter text, choice buttons, visual presentation |
| `scenes/ui/dialogue_box.tscn` | Dialogue box UI layout |
| `data/dialogue/*.json` | Dialogue content files |

## Flow

```
NPC.interact()
    │
    ├── DialogueManager.start_dialogue(dialogue_id)
    │   └── Looks up dialogue_id in loaded JSON data
    │
    └── DialogueManager.show_lines([...])
        └── For inline dialogue (no JSON lookup needed)
    │
    ▼
DialogueManager._begin_dialogue(lines)
    ├── Set GameManager state to DIALOGUE
    ├── Emit dialogue_started signal
    ├── Instantiate dialogue_box.tscn (if not already present)
    └── Call dialogue_box.show_dialogue(lines)
           │
           ▼
    DialogueBox renders each entry:
        ├── String → plain text, no speaker
        └── Dictionary → {text, speaker, portrait, choices}
               │
               ├── Typewriter effect (0.03s/char, 0.01s fast-mode)
               ├── Continue indicator: "▼" (more lines) or "■" (last line)
               └── Choices → dynamic buttons in ChoiceContainer
                      │
                      ▼
               choice_made signal → DialogueManager._on_choice_made()
                      │
                      ├── "rest" → Heal party for 25 gold
                      ├── "recruit_fairy" → Add creature to party
                      └── Other → emit choice_selected for custom handling
    │
    ▼
dialogue_finished → DialogueManager._on_dialogue_finished()
    ├── Set GameManager state back to OVERWORLD
    ├── Emit dialogue_ended
    └── Clean up dialogue box (queue_free)
```

## Dialogue Data Format (JSON)

```json
{
  "tavern_keeper": {
    "name": "Tavern Keeper",
    "requires_flag": "",
    "lines": [
      {
        "text": "Welcome to the tavern, adventurer!",
        "speaker": "Tavern Keeper",
        "portrait": "tavern_keeper",
        "choices": [
          {
            "text": "Rest (25 gold)",
            "id": "rest",
            "next": [
              {"text": "You rest and recover your strength.", "speaker": ""}
            ]
          },
          {
            "text": "Just passing through",
            "id": "leave",
            "next": [
              {"text": "Safe travels!", "speaker": "Tavern Keeper"}
            ]
          }
        ]
      }
    ]
  }
}
```

### Entry Types

Each entry in the `lines` array can be:

- **String**: `"Hello there!"` — plain text, no speaker name or portrait
- **Dictionary** with these optional fields:
  - `text` (String): The dialogue text
  - `speaker` (String): Name shown in the name panel
  - `portrait` (String): Portrait image ID (loaded from `assets/sprites/portraits/`)
  - `choices` (Array): Branching options, each with `text`, `id`, and optional `next` array

### Flag Gating

Dialogue entries can have a `requires_flag` field. If the flag hasn't been set in `GameManager.story_flags`, the dialogue won't play.

## Special Choice Actions

| Choice ID | Action |
|---|---|
| `rest` | Deducts 25 gold, heals entire party. Shows rejection message if insufficient gold. |
| `recruit_fairy` | Creates a Mischievous Fairy (Lv.5), adds to party or barracks, sets `fairy_recruited` flag, removes NPC from map. |

## Signals

| Signal | Emitter | Purpose |
|---|---|---|
| `dialogue_started` | DialogueManager | Notify systems dialogue is active |
| `dialogue_ended` | DialogueManager | Dialogue complete, return to overworld |
| `choice_selected(choice_id)` | DialogueManager | A choice button was pressed |
| `dialogue_finished` | DialogueBox | All lines exhausted |
| `choice_made(index, id)` | DialogueBox | Player selected a choice |
