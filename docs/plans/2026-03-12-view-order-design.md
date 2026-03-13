# View Order: Click-to-Front for Creatures/NPCs

**Date:** 2026-03-12
**Status:** Approved

## Problem

When a creature low in the list is clicked, the user must scroll extensively to get back to the detail editor. The list should reorder so the selected item moves to the front.

## Solution: Separate View Order File (Approach C)

Store display order in a dedicated metadata file, keeping game data clean.

## Data Layer

- New file: `data/characters/view_order.json`
- Contains an ordered JSON array of creature IDs: `["spark_thief", "alexia", ...]`
- On click: selected ID moves to index 0
- On creature create: ID prepended
- On creature delete: ID removed
- Auto-generated from `characters.json` key order if missing or incomplete

## Backend

Two new endpoints on the creatures router:

- `GET /api/creatures/view-order` — returns the view order array (auto-creates from `characters.json` keys if file is missing)
- `PUT /api/creatures/view-order/{creature_id}` — moves the given ID to position 0, writes the file

Existing `create` and `delete` endpoints updated to prepend/remove IDs from the view order file.

## Frontend

- `creaturesApi`: add `getViewOrder()` and `selectCreature(id)` methods
- `CreatureList.tsx`: fetch view order on mount, sort `Object.entries(creatures)` by it, on selection call `PUT /view-order/{id}`, move item to front of local state, scroll `ScrollArea` to top
- No changes to `CreatureForm` or `DataEditor/index.tsx`
