# MonsterQuest — Project Overview

MonsterQuest is a Pokemon-inspired monster-catching RPG built with **Godot 4.3** using GDScript. Players lead a party of creatures through an overworld, engage in turn-based 3v3 battles, recruit new creatures, and manage their roster.

## Quick Facts

| Property | Value |
|---|---|
| Engine | Godot 4.3 (GL Compatibility renderer) |
| Language | GDScript |
| Viewport | 480x320 (scaled 2x to 960x640) |
| Main Scene | `res://scenes/overworld/overworld.tscn` |
| Pixel Art | Nearest-neighbor filtering (no texture smoothing) |
| Testing | GUT (Godot Unit Testing) addon |

## Controls

| Action | Key |
|---|---|
| Move | W / A / S / D |
| Interact | Space |
| Cancel | Escape |
| Menu | Tab |
| Inventory | I |

## Project Directory Structure

```
monster-game/
├── project.godot              # Engine config, autoloads, input mappings
├── assets/
│   ├── audio/
│   │   ├── music/             # MP3 tracks (overworld, battle)
│   │   └── sfx/               # WAV sound effects
│   └── sprites/
│       ├── creatures/         # Battle sprites ({id}_battle.png)
│       ├── portraits/         # NPC/creature portraits
│       └── tilesets/          # Tileset art (runtime-loaded)
├── data/
│   ├── creatures/             # starters.json, wild.json
│   ├── dialogue/              # NPC dialogue trees (JSON)
│   ├── maps/                  # Encounter tables (route_1.json, etc.)
│   └── moves/                 # moves.json
├── scenes/
│   ├── battle/                # battle_scene.tscn
│   ├── overworld/             # overworld.tscn
│   └── ui/                    # dialogue_box.tscn, party_editor.tscn
├── scripts/
│   ├── autoload/              # 5 global singletons
│   ├── battle/                # Battle logic (state machine, calculator, types)
│   ├── overworld/             # Player, NPC, encounters, map building
│   └── ui/                    # Dialogue box, party editor
├── tests/
│   ├── unit/                  # Low-level system tests
│   ├── component/             # Autoload/singleton tests
│   ├── integration/           # End-to-end flow tests
│   └── helpers/               # Test utilities
├── addons/gut/                # GUT testing framework
└── documentation/             # You are here
```

## High-Level Architecture

The game follows a **signal-driven, autoload-based architecture**:

- **5 autoload singletons** manage global state and cross-system communication
- **Scenes are instantiated at runtime** (battle, dialogue, party editor) rather than pre-placed
- **All game content is data-driven** via JSON files — creatures, moves, encounters, and dialogue
- **Systems communicate through signals**, keeping them loosely coupled
- **Assets are loaded at runtime**, bypassing Godot's import pipeline for flexibility

See [02-architecture.md](02-architecture.md) for details on each system.
