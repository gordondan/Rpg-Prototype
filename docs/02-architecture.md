# Architecture & Systems

## Autoload Singletons

Five autoload scripts are registered in `project.godot` and available globally. They initialize in this order:

| # | Autoload | Script | Role |
|---|---|---|---|
| 1 | `DataLoader` | `scripts/autoload/data_loader.gd` | Loads all JSON data (creatures, moves, encounters) at startup |
| 2 | `GameManager` | `scripts/autoload/game_manager.gd` | Player state, party, inventory, flags, save/load, scene transitions |
| 3 | `BattleManager` | `scripts/autoload/battle_manager.gd` | Battle initiation, scene loading, party wipe handling |
| 4 | `AudioManager` | `scripts/autoload/audio_manager.gd` | Music playback with fading, 4-channel SFX |
| 5 | `DialogueManager` | `scripts/autoload/dialogue_manager.gd` | Dialogue data, dialogue box instantiation, choice handling |

## Game States

`GameManager` tracks the current state via an enum:

```
OVERWORLD ──► BATTLE ──► OVERWORLD
    │                        ▲
    ├──► DIALOGUE ───────────┤
    ├──► MENU ───────────────┤
    └──► CUTSCENE ───────────┘
```

State changes emit `game_state_changed(new_state)`, which other systems listen to (e.g., `AudioManager` swaps music on `BATTLE` vs `OVERWORLD`).

## Signal Flow Between Systems

```
                  ┌─────────────┐
                  │ GameManager │  (state hub)
                  └──────┬──────┘
         game_state_changed │
       ┌────────┬───────────┼───────────┐
       ▼        ▼           ▼           ▼
  AudioManager  Player   BattleManager  DialogueManager
  (music swap)  (input)  (battle flow)  (dialogue flow)
```

Key signal chains:

1. **Overworld → Battle:** `GrassArea`/`NPC` → `BattleManager.start_wild_battle()` → `GameManager.set_state(BATTLE)` → loads `battle_scene.tscn`
2. **Battle → Overworld:** `BattleStateMachine.battle_ended` → `BattleManager.end_battle()` → `GameManager.return_from_battle()`
3. **Dialogue:** `NPC.interact()` → `DialogueManager.start_dialogue()` → instantiates `dialogue_box.tscn` → `dialogue_ended` → returns to `OVERWORLD`

## Scene Graph

### Overworld (`scenes/overworld/overworld.tscn`)

```
Overworld (Node2D)
├── MapBuilder (Node2D)          — Procedural map generation
├── Player (CharacterBody2D)     — Grid-based movement, raycasting
│   ├── CharacterSprite (Sprite2D)
│   ├── RayCast2D
│   ├── CollisionShape2D
│   └── Camera2D
├── NPCs (CharacterBody2D ×N)   — Dialogue and rival triggers
├── GrassAreas (Area2D ×N)       — Random encounter zones
└── TestBattleTrigger (Node)     — Debug shortcut
```

### Battle (`scenes/battle/battle_scene.tscn`)

```
BattleScene (Node)
├── BattleStateMachine (Node)    — Turn-based combat logic
└── UI (CanvasLayer)
    ├── BattleField
    │   ├── EnemyArea (3 slots)  — Sprite + HP bar per enemy
    │   └── PlayerArea (3 slots) — Sprite + HP bar + name per ally
    └── BottomArea
        ├── MessageLabel         — Battle narration
        ├── ActionPanel          — Fight / Run / Swap buttons
        ├── MovePanel            — 4 move buttons (dynamically populated)
        ├── TargetPanel          — Enemy target selection
        └── SwapPanel            — Reserve creature selection
```

### Dialogue (`scenes/ui/dialogue_box.tscn`)

```
DialogueBox (CanvasLayer)
├── Panel
│   ├── NamePanel        — Speaker name
│   ├── Portrait         — Character portrait sprite
│   ├── TextLabel        — Typewriter-effect text
│   ├── ContinueIndicator — "▼" (more) or "■" (end)
│   └── ChoiceContainer  — Dynamic choice buttons
```

### Party Editor (`scenes/ui/party_editor.tscn`)

```
PartyEditor (CanvasLayer)
├── PartyList            — Active party (first 3 = active, rest = reserve)
├── BarracksList         — Barracks storage
├── InfoPanel            — Selected creature's stats, moves, XP
└── ActionButtons        — Up/Down/Store/Add controls
```

## Data Flow Diagram

```
JSON Files (data/)
    │
    ▼
DataLoader._ready()          ◄── Loads all JSON into memory at startup
    │
    ├── get_creature_data()   ◄── Used by CreatureInstance.create()
    ├── get_move_data()       ◄── Used by BattleStateMachine, BattleScene
    └── get_encounter_table() ◄── Used by BattleManager._roll_encounter()
```

```
GameManager (runtime state)
    │
    ├── player_party[]        ◄── CreatureInstance objects
    ├── barracks[]            ◄── Overflow creature storage
    ├── inventory{}           ◄── {item_id: quantity}
    ├── story_flags{}         ◄── {flag_name: bool}
    ├── gold, player_name     ◄── Player identity/economy
    │
    ├── save_game() ──► user://save_0.json
    └── load_game() ◄── user://save_0.json
```
