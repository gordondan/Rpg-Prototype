# NPC Hostile Flag & Roster Editor Design

**Date:** 2026-03-12
**Status:** Approved

## Goal

Add a hostile flag and creature roster (lead + party + reserves) to NPC data in characters.json, and make these editable from the web app.

## Data Model Changes (characters.json)

Add four new optional fields to NPC entries (category `"npc"`):

```json
{
  "name": "Mog",
  "category": "npc",
  "is_hostile": true,
  "lead_creature": { "creature_id": "goblin_firebomber", "level": 8 },
  "roster": [
    { "creature_id": "spark_thief", "level": 6 },
    { "creature_id": "stone_sentinel", "level": 7 }
  ],
  "reserves": [
    { "creature_id": "goblin_firebomber", "level": 5 }
  ]
}
```

- **`is_hostile`**: boolean (default `false`). Maps to `is_rival` in GDScript.
- **`lead_creature`**: `{creature_id, level}` or `null`. The NPC's primary creature — the one the player can recruit after winning.
- **`roster`**: array of `{creature_id, level}`. Additional party members for battle. Maps to `rival_party` in GDScript.
- **`reserves`**: array of `{creature_id, level}`, max 3. Backup creatures swapped in during battle. Maps to `rival_reserves` in GDScript.

For non-hostile NPCs, these fields are omitted or null/empty.

## Backend Changes

- Add `is_hostile`, `lead_creature`, `roster`, `reserves` to the `Creature` Pydantic schema (all optional)
- No new routes needed — existing creature CRUD handles it

## Frontend: NPC Form Section

Add a collapsible **"Battle Configuration"** section in CreatureForm, visible only when `category === 'npc'`:

- **Hostile toggle** — checkbox for `is_hostile`
- **Lead Creature** — dropdown (populated from creature list) + level number input
- **Party** — editable list of `{creature_id, level}` rows with add/remove
- **Reserves** — same format, capped at 3 entries

Creature dropdowns filter to non-NPC creatures (starters + wild).

## GDScript Integration

The NPC script can read these fields from `characters.json` to set defaults, with scene `@export` vars still available as overrides. This is a follow-up task that doesn't block the web editor work.
