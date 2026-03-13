# Design Patterns & Conventions

## Patterns Used

### Signal-Driven Architecture
Systems communicate through Godot signals rather than direct method calls. This keeps autoloads loosely coupled — `BattleStateMachine` doesn't reference `BattleScene` directly; it emits signals that the UI listens to.

### Autoload Singletons
Global managers (GameManager, BattleManager, etc.) are registered as autoloads in `project.godot`. They persist across scene changes and provide global access without passing references.

### State Machine Pattern
`BattleStateMachine` uses an explicit enum for battle states with `_set_state()` enforcing clean transitions. `GameManager.GameState` governs the overall game mode.

### Factory Method
`CreatureInstance.create(id, level)` encapsulates data loading + stat calculation + move learning into a single static call that returns a fully initialized instance.

### JSON-Driven Content
All game balance data lives in JSON files, not in GDScript. Adding a new creature means adding a JSON entry — no code changes needed. This separates content authoring from game logic.

### Runtime Asset Loading
Sprites, audio, and tilesets are loaded at runtime rather than through Godot's import pipeline. This enables:
- Hot-reloading during development
- Adding assets without editor re-import
- Fallback placeholders for missing files

### Scene Instantiation
Battle scenes, dialogue boxes, and the party editor are instantiated at runtime via `load()` + `.instantiate()` rather than being pre-placed in the scene tree. This keeps the overworld scene clean and allows these UI elements to be fully self-contained.

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Scripts | `snake_case.gd` | `battle_state_machine.gd` |
| Scenes | `snake_case.tscn` | `battle_scene.tscn` |
| Classes | `PascalCase` | `BattleStateMachine`, `CreatureInstance` |
| Signals | `snake_case` | `battle_message`, `creature_hp_changed` |
| Constants | `UPPER_SNAKE_CASE` | `MUSIC_OVERWORLD`, `MAX_SFX_CHANNELS` |
| Private methods | `_prefixed` | `_build_turn_order()`, `_roll_encounter()` |
| JSON keys | `snake_case` | `creature_id`, `base_attack`, `level_min` |
| Asset files | `snake_case` | `flame_squire_battle.png` |

## Code Organization

- Each script directory maps to a game system: `autoload/`, `battle/`, `overworld/`, `ui/`
- Autoloads handle cross-system coordination
- Scene scripts handle their own UI binding and local logic
- Static utility classes (`BattleCalculator`, `TypeChart`) use `extends RefCounted` with static methods

## Adding New Content

### New Creature
1. Add entry to `data/creatures/creatures.json` with `"category": "wild"`
2. Add battle sprite to `assets/sprites/creatures/{id}_battle.png`
3. Define moves in `data/moves/moves.json` if needed
4. Add to encounter tables in `data/maps/` to make it appear in the wild

### New Move
1. Add entry to `data/moves/moves.json`
2. Reference the move ID in creature learnsets

### New NPC
1. Add dialogue data to `data/dialogue/` (JSON file)
2. Place NPC node in the overworld scene or via `MapBuilder`
3. Set `dialogue_id` export to match the JSON key

### New Encounter Area
1. Create encounter table JSON in `data/maps/`
2. Add `GrassArea` node to the overworld with matching `encounter_table_id`
