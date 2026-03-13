# /update-docs — Sync Game Object Documentation

You are executing the `/update-docs` command. Your job is to ensure `docs/game-objects/*.md` accurately reflects the current codebase.

## Step 1: Identify what changed

Run `git diff HEAD~5 --name-only` to see recently changed files (adjust range if needed). Also check `git diff --name-only` for uncommitted changes.

Categorize changed files by which doc they affect:

| Changed file pattern | Doc to check |
|---------------------|--------------|
| `data/creatures/` or `data/characters/` or `scripts/battle/creature_instance.gd` or `scripts/autoload/data_loader.gd` or `web/backend/routers/creatures.py` or `web/backend/models/schemas.py` or `CreatureForm.tsx` or `CreatureList.tsx` | `creatures.md` |
| `scripts/overworld/npc.gd` or `scripts/overworld/map_builder.gd` (NPC sections) or `scripts/autoload/dialogue_manager.gd` or `data/dialogue/` | `npcs.md` |
| `data/moves/` or `scripts/battle/battle_calculator.gd` or `scripts/battle/type_chart.gd` or `MoveForm.tsx` | `moves.md` |
| `data/items/` or `scripts/ui/inventory.gd` or `scripts/autoload/game_manager.gd` (inventory methods) or `ItemForm.tsx` | `items.md` |
| `data/shops/` or `scripts/ui/shop.gd` or `ShopForm.tsx` | `shops.md` |
| `data/maps/` or `scripts/overworld/map_builder.gd` (map sections) or `scripts/overworld/grass_area.gd` | `maps.md` |
| `data/quests/` or `scripts/autoload/game_manager.gd` (quest methods) or `scripts/ui/quest_log.gd` or `QuestForm.tsx` | `quests.md` |

If no relevant files changed, report "Docs are up to date." and stop.

## Step 2: For each affected doc

For each doc that may need updating:

1. Read the current doc from `docs/game-objects/`
2. Read the relevant source files (data JSON, GDScript, Python, TypeScript) to get the current truth
3. Compare: are there new fields, removed fields, changed behavior, new files, renamed paths?
4. If the doc is accurate, skip it
5. If the doc needs changes, update it in place — preserve the existing section structure:
   - Overview
   - Data Schema
   - Code Paths
   - How to Add/Modify
   - Runtime Behavior

## Step 3: Report

For each doc that was updated, report one line:
```
Updated <filename>: <what changed and why>
```

For example:
```
Updated creatures.md: added "elemental_weakness" field to schema (new field in creatures.json)
Updated moves.md: updated damage formula to include defense debuff multiplier (battle_calculator.gd changed)
```

If nothing needed updating: "All docs are current."

## Step 4: Commit (if changes were made)

Stage and commit only the changed docs:
```
git add docs/game-objects/
git commit -m "docs: sync game object documentation with current code

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

## Important

- Do NOT rewrite docs that are already accurate — only update what actually changed
- Keep the same concise, factual tone as the existing docs
- Do not add emojis
- Use subagents to check multiple docs in parallel when possible
- If a doc file doesn't exist yet for a new game object type, create it following the same 5-section structure
