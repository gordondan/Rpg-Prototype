# Moves

## Overview

Moves are the actions creatures use in battle. Each move has a type, category, power, accuracy, and PP (power points). The game currently contains 34 moves spanning 10 types plus `no_affinity`. Moves are defined in a single JSON file and referenced by ID in creature learnsets.

## Data Schema

All moves live in `data/moves/moves.json` as a flat object keyed by move ID (e.g. `"fire_bolt"`).

### Required Fields

| Field         | Type     | Description                                                                                     |
|---------------|----------|-------------------------------------------------------------------------------------------------|
| `name`        | `string` | Display name shown in battle UI.                                                                |
| `type`        | `string` | Elemental type. One of: `fire`, `aqua`, `nature`, `storm`, `no_affinity`, `warrior`, `wind`, `poison`, `earth`, `construct`, `witch`, `specter`, `arcane`, `frost`, `dragon`, `shadow`, `machine`, `fey`. |
| `category`    | `string` | `physical`, `special`, or `status`.                                                             |
| `power`       | `int`    | Base power. `0` for status moves.                                                               |
| `accuracy`    | `int`    | Hit chance (1--100). 100 = never misses.                                                        |
| `pp`          | `int`    | Maximum uses per battle before resting.                                                         |
| `description` | `string` | Flavor text shown in move info.                                                                 |

### Optional Fields

| Field           | Type     | Default    | Description                                                              |
|-----------------|----------|------------|--------------------------------------------------------------------------|
| `priority`      | `int`    | `0`        | Turn-order priority. `1` = always acts first (e.g. `tidal_rush`, `swift_strike`). |
| `target`        | `string` | `"single"` | Targeting mode: `single`, `all_enemies`, or `all_allies`.                |
| `effect_chance` | `int`    | `0`        | Percent chance (0--100) a damaging move's secondary effect triggers.     |
| `effect`        | `object` | --         | Status or stat effect. See below.                                        |

### Effect Object

| Field    | Type     | Description                                                                             |
|----------|----------|-----------------------------------------------------------------------------------------|
| `stat`   | `string` | Stat to modify: `attack`, `defense`, `sp_attack`, `sp_defense`, `speed`, `accuracy`.    |
| `stages` | `int`    | Stage change. Positive = buff, negative = debuff. Typically -2 to +2.                   |
| `status` | `string` | Status condition to inflict: `burn`, `poison`, `sleep`, `paralysis`, `freeze`.          |
| `target` | `string` | Who the effect applies to: `"enemy"` (default) or `"self"` / `"ally"`.                  |

An effect can contain stat fields, status fields, or both. For damaging moves, the effect only triggers when the `effect_chance` roll succeeds. For status-category moves, the effect always applies (accuracy permitting).

### Example Entries

```json
"fire_bolt": {
  "name": "Fire Bolt",
  "type": "fire",
  "category": "special",
  "power": 40,
  "accuracy": 100,
  "pp": 25,
  "description": "Hurls a small bolt of fire. May inflict a burn.",
  "effect_chance": 10,
  "effect": { "status": "burn", "target": "enemy" }
}

"iron_guard": {
  "name": "Iron Guard",
  "type": "no_affinity",
  "category": "status",
  "power": 0,
  "accuracy": 100,
  "pp": 30,
  "target": "all_allies",
  "description": "Raises shields across the whole party, increasing Defense for all allies.",
  "effect": { "stat": "defense", "stages": 1, "target": "ally" }
}
```

## Code Paths

| Path | Role |
|------|------|
| `data/moves/moves.json` | Canonical data file (34 moves). |
| `scripts/battle/battle_calculator.gd` | Damage formula, accuracy roll, crit roll, STAB, type effectiveness. |
| `scripts/battle/type_chart.gd` | 18-type effectiveness chart (`_chart` dictionary). |
| `scripts/battle/battle_state_machine.gd` | Move execution, PP deduction, status effect application, multi-target logic. |
| `scripts/battle/creature_instance.gd` | Learnset resolution (`_learn_moves_for_level`), per-move `current_pp`/`max_pp` tracking. |
| `web/backend/routers/moves.py` | REST API: list, get, create, update, delete. |
| `web/backend/models/schemas.py` | Pydantic models: `Move`, `MoveEffect`. |
| `web/frontend/src/pages/DataEditor/MoveForm.tsx` | Web editor form for editing a single move. |
| `web/frontend/src/pages/DataEditor/MovesList.tsx` | Web editor move list/sidebar. |

## How to Add or Modify

### Via the Web Editor

1. Open the Data Editor and navigate to the Moves tab.
2. Click **Create** to add a new move (auto-assigned an ID like `new_move_N`).
3. Fill in all fields in the Properties and Effect cards.
4. Changes are staged locally; click **Save** to persist to `moves.json`.
5. To delete, click the trash icon on the move form and confirm.

### Via JSON

1. Open `data/moves/moves.json`.
2. Add a new key using a snake_case ID (e.g. `"ice_lance"`).
3. Populate all required fields. Add optional fields as needed.
4. Reference the move ID in a creature's `learnset` array (in `data/creatures/creatures.json`):
   ```json
   { "level": 12, "move_id": "ice_lance" }
   ```

## Runtime Behavior

### Damage Formula

The battle system uses a simplified Gen III formula (see `battle_calculator.gd`):

```
base = ((2 * level / 5 + 2) * power * ATK / DEF) / 50 + 2
final = base * STAB * effectiveness * crit * random(0.85, 1.0)
```

- **ATK/DEF selection**: `physical` moves use Attack vs Defense; `special` moves use Sp. Attack vs Sp. Defense.
- Minimum damage is 1 (unless the target is immune, i.e. effectiveness = 0).

### STAB (Same Type Attack Bonus)

If the move's type matches any of the attacker's types, damage is multiplied by **1.5x**.

### Critical Hits

- Base rate: **6.25%** per attack.
- Multiplier: **2x** damage.

### Type Effectiveness

Defined in `type_chart.gd` across 18 types. For dual-type defenders, individual multipliers are multiplied together.

| Multiplier | Meaning |
|------------|---------|
| 2.0x       | Super effective |
| 0.5x       | Not very effective |
| 0.0x       | No effect (immune) |

### PP (Power Points)

- Each move instance in battle tracks `current_pp` and `max_pp`.
- One PP is consumed each time the move is used.
- When `current_pp` reaches 0 the move cannot be selected.
- PP is fully restored on `full_heal()` (rest/heal events).

### Status Effects

Status conditions persist until healed or battle ends. A creature can have only one status at a time.

| Status      | End-of-round effect              |
|-------------|----------------------------------|
| `burn`      | Loses 1/16 of max HP per round.  |
| `poison`    | Loses 1/8 of max HP per round.   |
| `sleep`     | Cannot act (duration-based).     |
| `paralysis` | May be unable to act.            |
| `freeze`    | Cannot act until thawed.         |

### Stat Stage Changes

Stat modifiers are applied directly to the creature's current stat value in battle:

- **+1 stage**: multiply stat by 1.5x
- **+2 stages**: multiply stat by 2.0x
- **-1 stage**: multiply stat by ~0.67x
- **-2 stages**: multiply stat by 0.5x

The stat floor is 1 (stats cannot drop below 1).

### Targeting and Multi-Target Moves

The top-level `target` field controls how many combatants are hit:

- `"single"` (default) -- hits one selected target.
- `"all_enemies"` -- hits every living enemy (e.g. `war_cry`, `firebomb`).
- `"all_allies"` -- applies to every living ally (e.g. `iron_guard`).

### Move Priority

Moves with `priority: 1` act before the normal speed-based turn order (e.g. `tidal_rush`, `swift_strike`). The default priority is 0.

### Learnsets

Creatures learn moves via their `learnset` array, which pairs a `level` with a `move_id`. When a creature is created at a given level, it knows the last 4 moves it would have learned up to that level. On level-up, any new move at that exact level is added if the creature has fewer than 4 moves.
