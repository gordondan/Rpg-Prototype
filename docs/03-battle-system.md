# Battle System

The battle system is a turn-based 3v3 combat system with speed-based turn ordering, status effects, type effectiveness, and reserve swapping.

## Key Files

| File | Role |
|---|---|
| `scripts/battle/battle_state_machine.gd` | Core turn loop and state management |
| `scripts/battle/battle_scene.gd` | UI binding, player input routing |
| `scripts/battle/battle_calculator.gd` | Damage formula, XP calculation |
| `scripts/battle/type_chart.gd` | 18-type effectiveness matrix |
| `scripts/battle/creature_instance.gd` | Creature data model (stats, moves, HP) |
| `scripts/autoload/battle_manager.gd` | Battle initiation and cleanup |
| `scenes/battle/battle_scene.tscn` | Battle UI layout |

## Battle Flow

```
Trigger (GrassArea / NPC)
    │
    ▼
BattleManager.start_wild_battle() or start_rival_battle()
    │
    ├── GameManager.set_state(BATTLE)
    ├── Load and instantiate battle_scene.tscn
    └── Call setup_battle(player_active, enemy_team, is_wild, reserves)
           │
           ▼
    BattleStateMachine.start_battle()
           │
           ▼
    ┌──── INTRO ◄───────────────────────────────────────┐
    │      │  (flavor text, 2s delay)                    │
    │      ▼                                             │
    │  TURN_START                                        │
    │      │  Build speed-sorted turn order              │
    │      ▼                                             │
    │  For each combatant (fastest first):               │
    │      ├── Player? → PLAYER_SELECT                   │
    │      │              (emit request_player_action)   │
    │      │              Wait for select_fight/run/swap │
    │      │                                             │
    │      └── Enemy?  → EXECUTE_ACTION                  │
    │                    (random move + random target)   │
    │      │                                             │
    │      ▼                                             │
    │  EXECUTE_ACTION                                    │
    │      │  Accuracy check → Damage calc → Apply       │
    │      │  Check faint → Award XP → Auto-swap reserve │
    │      ▼                                             │
    │  CHECK_END                                         │
    │      ├── All enemies down → WIN → end_battle("win")│
    │      ├── All allies down  → LOSE → end_battle("lose")
    │      └── Continue ────────────────────────────────►│
    │      ▼                                             │
    │  RESOLVE (end-of-round)                            │
    │      │  Apply poison/burn tick damage               │
    │      │  Check for additional faints                 │
    │      └── Loop back to TURN_START ──────────────────┘
    │
    ▼
BattleManager.end_battle(result)
    ├── "win"  → Return to overworld
    ├── "lose" → Heal party, deduct gold, respawn at tavern
    └── "run"  → Return to overworld
```

## State Machine States

```gdscript
enum BattleState {
    INTRO,           # Opening message
    TURN_START,      # Build turn order for new round
    PLAYER_SELECT,   # Waiting for player input
    EXECUTE_ACTION,  # Executing one combatant's action
    RESOLVE,         # End-of-round effects (poison, burn)
    CHECK_END,       # Check win/lose conditions
    WIN,             # Victory
    LOSE,            # Defeat
    RUN,             # Escaped (wild battles only)
}
```

## Damage Formula

Uses a simplified **Gen III Pokemon damage formula**:

```
base = ((2 * Level / 5 + 2) * Power * Atk / Def) / 50 + 2
final = base * Critical * STAB * TypeEffectiveness * Random
```

| Modifier | Value |
|---|---|
| Critical hit | 2.0x (6.25% base chance) |
| STAB (Same Type Attack Bonus) | 1.5x when move type matches attacker type |
| Type effectiveness | 0.0x / 0.5x / 1.0x / 2.0x (multiplied for dual types) |
| Random factor | 0.85 to 1.0 |
| Minimum damage | 1 (unless immune) |

Physical moves use `attack` vs `defense`. Special moves use `sp_attack` vs `sp_defense`.

## XP and Leveling

```
XP Yield = (base_exp * defeated_level * trainer_bonus) / 7
```

- `base_exp`: defined per creature species in JSON
- `trainer_bonus`: 1.0 for wild, 1.5 for trainer/rival battles
- Level-up stat recalculation uses: `base_stat * level / 50 + 5`

## Escape Mechanic

Only available in wild battles. Chance is based on speed:

```
escape_chance = clamp(player_speed / enemy_speed * 0.5 + 0.25, 0.2, 1.0)
```

Uses the fastest living creature from each side.

## Type Chart

18 types with the classic effectiveness matrix: normal, fire, water, grass, electric, ice, fighting, poison, ground, flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy.

Stored as a sparse dictionary — only non-1.0 matchups are recorded. For dual-typed defenders, effectiveness values are multiplied together.

## Status Effects

Applied via status moves or damaging move side-effects (via `effect_chance`):

| Status | End-of-Round Damage |
|---|---|
| Poison | max(1, max_hp / 8) |
| Burn | max(1, max_hp / 16) |
| Sleep | None (not yet fully implemented) |
| Paralysis | None (not yet fully implemented) |
| Freeze | None (not yet fully implemented) |

## Stat Stages

Status moves can raise or lower stats:

| Stages | Multiplier |
|---|---|
| +2 | 2.0x |
| +1 | 1.5x |
| -1 | 0.67x |
| -2 | 0.5x |

Applied directly to the creature's current stat value. Affected stats: attack, defense, sp_attack, sp_defense, speed.

## Reserve Swapping

- Party supports up to 6 creatures; first 3 are active, rest are reserves
- When an active ally faints, the next non-fainted reserve automatically swaps in
- Players can voluntarily swap during their turn (consumes the turn)
- Battle ends in loss only when all active + reserve creatures are fainted

## Signals

| Signal | Emitter | Data |
|---|---|---|
| `battle_message(text)` | BattleStateMachine | Narration text for the message label |
| `state_changed(new_state)` | BattleStateMachine | Current BattleState enum value |
| `creature_hp_changed(is_player, index, hp, max_hp)` | BattleStateMachine | HP bar updates |
| `creature_fainted(is_player, index)` | BattleStateMachine | Faint animation trigger |
| `exp_gained(creature, amount, leveled_up)` | BattleStateMachine | XP display updates |
| `request_player_action(creature, ally_index)` | BattleStateMachine | Prompt player for input |
| `battle_started()` | BattleManager | Battle scene loaded |
| `battle_finished(result)` | BattleManager | "win", "lose", or "run" |
