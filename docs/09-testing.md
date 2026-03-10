# Testing

MonsterQuest uses the **GUT** (Godot Unit Testing) framework for automated testing.

## Setup

- GUT addon installed at `addons/gut/`
- Configuration in `.gutconfig.json`
- Test directories: `tests/unit/`, `tests/component/`, `tests/integration/`
- Test file convention: `test_*.gd` prefix

## Test Structure

```
tests/
├── unit/                              # Isolated logic tests
│   ├── test_creature_instance.gd      # Stat calculation, moves, XP, leveling
│   ├── test_battle_calculator.gd      # Damage formula, effectiveness, XP yield
│   ├── test_type_chart.gd            # Type matchup lookups
│   └── test_data_loader.gd           # JSON loading and data access
│
├── component/                         # Autoload and system tests
│   ├── test_battle_state_machine.gd   # State transitions, turn order, actions
│   ├── test_dialogue_manager.gd       # Dialogue flow, flag gating, choices
│   └── test_game_manager.gd          # Party management, state changes
│
├── integration/                       # End-to-end flow tests
│   ├── test_wild_battle_flow.gd       # Encounter → battle → return
│   ├── test_encounter_trigger_flow.gd # GrassArea step → encounter roll → battle
│   └── test_npc_interaction_flow.gd   # NPC interact → dialogue → rival battle
│
└── helpers/
    └── test_helpers.gd               # Shared test utilities
```

## Test Layers

### Unit Tests
Test individual classes in isolation with no scene tree dependencies:
- `CreatureInstance`: stat scaling formulas, move learning by level, damage/heal, XP accumulation and level-up
- `BattleCalculator`: damage output ranges, critical hit multiplier, STAB bonus, type effectiveness, accuracy, XP yield formula
- `TypeChart`: super-effective, not-effective, immune, and dual-type matchups
- `DataLoader`: JSON file parsing, creature/move/encounter data retrieval

### Component Tests
Test autoload singletons with their dependencies:
- `BattleStateMachine`: state transitions (INTRO → TURN_START → PLAYER_SELECT), turn order sorting by speed, fight/run/swap action execution, win/lose condition detection
- `DialogueManager`: dialogue loading from JSON, line display sequencing, flag-gated dialogues, choice processing
- `GameManager`: party add/remove/swap, barracks operations, battle team splitting, state changes

### Integration Tests
Test cross-system flows end-to-end:
- Wild battle flow: encounter trigger → battle scene load → combat → return to overworld
- Encounter trigger: player stepping on GrassArea → encounter rate check → battle initiation
- NPC interaction: player interact → dialogue display → rival challenge → battle → flag set

## Running Tests

Tests can be run from:
- **Godot editor**: GUT bottom panel (enabled via the GUT plugin)
- **Command line**: `godot --headless -s addons/gut/gut_cmdln.gd`
