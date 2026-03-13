# Sprite Pipeline: Website to Game

This document describes the full journey of an image from upload on the web editor to rendering inside the game.

---

## Overview

The pipeline has three stages: **upload**, **naming**, and **runtime loading**. There is no build step or configuration file to update — the game resolves sprites purely by filename at runtime.

```
Web Editor Upload
      ↓
File saved to assets/sprites/{folder}/{filename}.png
      ↓
Godot auto-generates .import file on next project open
      ↓
Game loads PNG directly at runtime using creature_id or dialogue entry
```

---

## Stage 1 — Upload

The web editor saves uploaded images directly into the game's asset folders. The destination folder depends on the sprite type:

| Sprite type | Destination folder |
|---|---|
| Creature battle sprite | `assets/sprites/creatures/` |
| Creature overworld sprite | `assets/sprites/creatures/` |
| NPC overworld sprite | `assets/sprites/npcs/` |

The filename you give the image determines everything downstream — the game will not find the sprite if the name doesn't match the expected convention.

---

## Stage 2 — Naming Convention

### Creature sprites

Creature sprites are resolved from the creature's `creature_id` (the key used in `data/creatures/creatures.json`).

| Use | Filename pattern | Example |
|---|---|---|
| Battle (required) | `{creature_id}_battle.png` | `goblin_warrior_battle.png` |
| Overworld | `{creature_id}.png` | `goblin_warrior.png` |
| Gendered variant | `{creature_id}_{gender}_battle.png` | `spark_thief_female_battle.png` |

The battle sprite is what appears in combat. The overworld sprite is used when the creature appears on the map (e.g. a recruitable NPC's creature form).

**Special cases in `battle_scene.gd`:**

Some creatures don't follow the standard naming because their sprite filename differs from their creature ID, or they pick randomly from multiple sprites each battle:

- `SPRITE_OVERRIDES` — maps a `creature_id` to a specific hardcoded path (e.g. `alexia` uses `wind_scout_battle.png`)
- `SPRITE_RANDOM_POOLS` — maps a `creature_id` to a list of paths, one picked at random each encounter (e.g. `spark_thief` randomly shows male or female sprite)

If your creature's filename matches `{creature_id}_battle.png` exactly, no code changes are needed.

### NPC sprites

NPC sprites are referenced explicitly in the dialogue JSON rather than derived from a naming template. Each dialogue entry can include a `"sprite"` field with the full `res://` path:

```json
"mischievous_fairy": {
  "sprite": "res://assets/sprites/npcs/mischievous_fairy_overworld.png",
  "lines": [...]
}
```

The path is set in `data/dialogue/npcs.json` for each NPC dialogue entry that needs it. If an NPC's dialogue entry has no `"sprite"` field, a colored placeholder rectangle is shown on the map instead.

---

## Stage 3 — Runtime Loading

### Creature battle sprites

`battle_scene.gd` handles loading via `_load_creature_sprite(target, creature_id)`:

1. Checks `SPRITE_RANDOM_POOLS` — if the creature has multiple gendered variants, picks one at random.
2. Checks `SPRITE_OVERRIDES` — if the creature has a hardcoded path, uses that.
3. Falls back to the template: `res://assets/sprites/creatures/{creature_id}_battle.png`

Notably, the game loads the raw PNG directly using `Image.load_from_file()` rather than going through Godot's import system. This means the sprite will work as soon as the file exists on disk — a `.import` file is not required at runtime.

### NPC overworld sprites

`map_builder.gd` reads the `"sprite"` field from the NPC's dialogue entry and loads it with `_load_texture()`. If the texture loads successfully it is attached as a `Sprite2D` child of the NPC node. If it fails or the field is missing, the colored placeholder is used instead.

---

## Godot `.import` Files

Godot generates a `.import` file alongside each image when the project is opened in the editor. These are tracked in git.

Because creature sprites are loaded via `Image.load_from_file()` at runtime (bypassing the import cache), a missing `.import` file will not cause a crash or blank sprite in-game. The `.import` file is still needed for the Godot editor itself to display the sprite in the inspector and scene tree.

After adding a new sprite, open the project in Godot and it will auto-generate the `.import` file. You do not need to create it manually.

---

## Adding a New Creature Sprite — Checklist

1. Name the file `{creature_id}_battle.png` where `creature_id` matches the key in `creatures.json`
2. Upload via the web editor — it will be saved to `assets/sprites/creatures/`
3. No code changes needed unless the filename can't follow the standard convention (see `SPRITE_OVERRIDES` in `battle_scene.gd`)
4. Open the project in Godot to generate the `.import` file

## Adding a New NPC Sprite — Checklist

1. Name the file anything descriptive (e.g. `goblin_boss_overworld.png`)
2. Upload via the web editor — it will be saved to `assets/sprites/npcs/`
3. Add or update the `"sprite"` field in the NPC's dialogue entry in `data/dialogue/npcs.json`:
   ```json
   "sprite": "res://assets/sprites/npcs/goblin_boss_overworld.png"
   ```
4. Open the project in Godot to generate the `.import` file
