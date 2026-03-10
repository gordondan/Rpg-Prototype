# Party & Creature Management

## Party Structure

The player's creatures are split between two collections in `GameManager`:

| Collection | Capacity | Purpose |
|---|---|---|
| `player_party` | Up to 6 | Active roster. First 3 are the battle team, rest are reserves. |
| `barracks` | Unlimited | Long-term storage for overflow creatures. |

### Battle Team Selection

`GameManager.get_battle_team(max_active=3)` splits the party for battle:

```
player_party: [Creature1, Creature2, Creature3, Creature4, Creature5]
                 ▲          ▲          ▲          ▲          ▲
              active[0]  active[1]  active[2]  reserve[0] reserve[1]
```

- Fainted creatures are skipped — they don't fill active or reserve slots
- Active team is up to 3 living creatures
- Remaining living creatures become reserves

## Party Operations

All operations are methods on `GameManager`:

| Method | Behavior |
|---|---|
| `add_creature_to_party(creature)` | Adds to party if < 6, otherwise to barracks. Returns `true` if added to party. |
| `move_to_barracks(party_index)` | Moves creature from party to barracks. Fails if it would empty the party. |
| `move_to_party(barracks_index)` | Moves creature from barracks to party. Fails if party is full (6). |
| `swap_party_positions(a, b)` | Reorders two creatures within the party (affects battle priority). |
| `heal_all_party()` | Fully heals all party creatures (HP + clear status). |
| `is_party_wiped()` | Returns `true` if all party creatures are fainted. |

## Party Editor UI

The `PartyEditor` scene (`scenes/ui/party_editor.tscn`) provides a visual interface:

- **Party list**: Shows all 6 party slots. Labels indicate "Active" (slots 1-3) vs "Reserve" (slots 4-6).
- **Barracks list**: Shows all stored creatures.
- **Info panel**: Clicking a creature shows its stats, types, moves, and XP progress.
- **Actions**: Up/Down (reorder), Store (party → barracks), Add (barracks → party).

Opened via the inventory input action (I key).

## Creature Recruitment

New creatures join via:

1. **Dialogue choices** — e.g., "recruit_fairy" in NPC dialogue creates a creature and calls `add_creature_to_party()`
2. **Debug setup** — `GameManager._setup_debug_party()` creates 3 starters on game launch

Recruitment sets a story flag to prevent re-recruitment, and optionally removes the NPC from the overworld.

## Party Wipe

When all party creatures faint during battle:

1. `BattleManager._handle_party_wipe()` triggers
2. Entire party is healed to full
3. 10% of gold is deducted (minimum 1)
4. Player is teleported to the tavern respawn point
5. A narrative dialogue sequence plays explaining the rescue
