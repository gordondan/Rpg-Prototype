# Automated Testing Design — MonsterQuest

## Goal

Broad regression coverage across all game systems using GUT (Godot Unit Test) with a three-layer test strategy: unit, component, and integration.

## Framework

GUT (Godot Unit Test) — installed via AssetLib. Provides assertions, signal watching, scene testing, editor dock, and headless CLI runner.

## Project Structure

```
tests/
├── unit/                         # Pure logic, no scene tree
│   ├── test_battle_calculator.gd
│   ├── test_type_chart.gd
│   ├── test_creature_instance.gd
│   └── test_data_loader.gd
├── component/                    # Single-system behavior with signals/state
│   ├── test_battle_state_machine.gd
│   ├── test_dialogue_manager.gd
│   └── test_game_manager.gd
├── integration/                  # Multi-system scripted flows
│   ├── test_wild_battle_flow.gd
│   ├── test_npc_interaction_flow.gd
│   └── test_encounter_trigger_flow.gd
└── helpers/
    └── test_helpers.gd           # Factory methods, common setup
```

Config: `.gutconfig.json` at project root.

## Layer 1: Unit Tests

### BattleCalculator
- Damage formula produces expected values for known inputs
- Critical hits apply 2x multiplier
- STAB applies 1.5x for matching type
- Zero power moves deal no damage
- Accuracy check respects move accuracy value
- EXP yield formula with/without trainer bonus

### TypeChart
- Super effective returns 2.0 (fire vs grass)
- Not very effective returns 0.5 (fire vs water)
- Immune returns 0.0 (normal vs ghost)
- Neutral returns 1.0 (fire vs fire)
- Dual-type multipliers compound correctly (fire vs grass/bug = 4.0)

### CreatureInstance
- `create()` at level 1 produces correct stat values from base stats
- `create()` at level 50 produces correct stats
- Move learning picks the right 4 moves for a given level
- `take_damage()` clamps HP to 0
- `heal()` clamps HP to max
- `is_fainted()` returns true at 0 HP
- `gain_experience()` triggers level up at threshold

### DataLoader
- All starter creatures load with required fields (name, types, base_stats, learnset)
- All moves load with required fields (type, category, power, accuracy, pp)
- Encounter table weights sum correctly
- `get_creature_data()` returns null for invalid ID
- `get_move_data()` returns null for invalid ID

## Layer 2: Component Tests

### BattleStateMachine
- Initial state is INTRO after setup
- Transitions INTRO -> PLAYER_TURN on advance
- Selecting a move transitions to PLAYER_ACTION
- Faster creature acts first in turn resolution
- Fainting enemy transitions to WIN state
- Fainting player creature transitions to LOSE state
- Run attempt succeeds/fails based on speed ratio
- Poison/burn applies damage at end of turn
- `battle_message` signal emits for each action
- `battle_ended` signal emits with correct result (win/lose/run)

### DialogueManager
- Starting dialogue emits `dialogue_started`
- Advancing through lines reaches end and emits `dialogue_ended`
- Branching choice presents correct options
- Selecting a choice follows the right `next` path
- Flag requirements gate dialogue lines correctly
- "Rest" choice triggers healing action

### GameManager
- Initial state is OVERWORLD
- `change_state()` emits `game_state_changed` with correct value
- `add_creature_to_party()` respects max 6 limit
- `is_player_free()` returns true only in OVERWORLD state
- Save/load round-trips party, gold, and story flags correctly
- Story flag set/get works

## Layer 3: Integration Tests

### Wild Battle Flow
Trigger encounter -> BattleManager loads battle scene -> BattleStateMachine reaches PLAYER_TURN -> select move -> damage applied -> enemy faints -> EXP gained -> battle scene removed -> GameManager state returns to OVERWORLD.

### NPC Interaction Flow
Spawn player near NPC -> simulate interact input -> DialogueManager starts -> advance through lines -> dialogue ends -> GameManager state returns to OVERWORLD. Rival variant: dialogue ends -> battle starts -> win -> defeated_flag set.

### Encounter Trigger Flow
Spawn player + GrassArea -> simulate stepping into grass -> over N steps, verify encounters trigger at roughly expected rate. Spawned creature is from correct encounter table with valid level range.

### Test Helpers (`tests/helpers/test_helpers.gd`)
- `create_test_creature(id, level)` — shortcut for creature instances
- `advance_battle_to_player_turn(state_machine)` — skip intro state
- `simulate_input_action(action, node)` — fake input events
- `wait_for_signal_or_timeout(obj, signal, timeout)` — async wait with safety timeout

## Running Tests

| Method | Command | Use case |
|--------|---------|----------|
| Editor panel | GUT dock -> Run All | During development |
| CLI headless | `godot --headless -s addons/gut/gut_cmdln.gd` | Pre-commit check |
| CLI filtered | Same + `-gtest=tests/unit/` | Run one layer |

## Future CI

GitHub Actions workflow: install Godot 4.3, run CLI command, fail build on test failure. Not built now — GUT's CLI mode makes it trivial to add later.
