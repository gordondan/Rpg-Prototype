# MonsterQuest — Pokémon-Style RPG Starter Project

A Godot 4.3 starter project for building a Pokémon Fire Red-inspired monster catching RPG.

## Quick Start

1. **Download Godot 4.3+** from https://godotengine.org/download
2. Open Godot → Import → Select this folder's `project.godot`
3. The project will open but won't run yet — you need to create the scene files (see below)

## What's Included

### Core Systems (Ready to Use)
- **Player Controller** (`scripts/overworld/player.gd`) — Grid-based tile movement with smooth tweening, raycasting for collisions, animation support
- **Battle State Machine** (`scripts/battle/battle_state_machine.gd`) — Full turn-based battle flow: intro → player turn → enemy turn → resolve → check end
- **Damage Calculator** (`scripts/battle/battle_calculator.gd`) — Gen III-style damage formula with STAB, critical hits, type effectiveness, accuracy
- **Type Chart** (`scripts/battle/type_chart.gd`) — All 18 types with full effectiveness matrix
- **Creature Instance** (`scripts/battle/creature_instance.gd`) — Living creature with stats, level-up, experience, moves, status effects
- **Battle Scene Controller** (`scripts/battle/battle_scene.gd`) — Wires UI elements to the battle state machine

### Autoloads (Global Managers)
- **GameManager** — Player party, inventory, story flags, save/load, scene state
- **BattleManager** — Initiates wild and trainer battles, handles transitions
- **DataLoader** — Reads all JSON data files and provides lookup API
- **AudioManager** — Music and SFX with fade-in/out and multiple channels

### Data Files (JSON-driven, easy to edit)
- **3 Starter Creatures** — Emberaptor (fire), Tidalup (water), Sproutlet (grass)
- **4 Wild Creatures** — Zapprat, Fluffowl, Pebblite, Bugbean
- **26 Moves** — Mix of physical, special, and status moves across multiple types
- **Route 1 Encounter Table** — Weighted random encounters with level ranges

### Overworld Scripts
- **Grass Area** (`scripts/overworld/grass_area.gd`) — Triggers random encounters on player movement
- **NPC** (`scripts/overworld/npc.gd`) — Dialogue, trainer battles, line-of-sight, story flags

## What You Need to Build Next

### Step 1: Create Scene Files in the Godot Editor
The scripts reference scenes that you'll create visually:

**Player Scene** (`scenes/overworld/player.tscn`):
- CharacterBody2D (root, attach `player.gd`)
  - AnimatedSprite2D (your character spritesheet)
  - RayCast2D (collision detection)
  - CollisionShape2D

**Overworld Scene** (`scenes/overworld/overworld.tscn`):
- Node2D (root)
  - TileMapLayer (build your map with a tileset)
  - Player (instance your player scene)
  - GrassAreas (Area2D nodes with `grass_area.gd`)
  - NPCs (CharacterBody2D nodes with `npc.gd`)
  - Camera2D (attached to player)

**Battle Scene** (`scenes/battle/battle_scene.tscn`):
- CanvasLayer (root, attach `battle_scene.gd`)
  - BattleStateMachine (Node, attach `battle_state_machine.gd`)
  - UI (Control)
    - MessageBox/MessageLabel
    - PlayerPanel (NameLabel, HPBar, HPLabel, LevelLabel)
    - EnemyPanel (NameLabel, HPBar, LevelLabel)
    - ActionPanel (FightButton, RunButton)
    - MovePanel (MoveButton1–4)

### Step 2: Create or Find Sprite Assets
- 16×16 or 32×32 tileset for the overworld
- Character walk sprites (4 directions × 2–3 frames each)
- Creature sprites (front and back views for battles)
- UI elements (HP bar, text box, buttons)

Free asset packs that work well:
- Search itch.io for "16x16 RPG tileset"
- Search OpenGameArt.org for "Pokemon style sprites"

### Step 3: Expand the Game
Suggested order for adding features:

1. **Dialogue System** — Text box with typewriter effect, multi-page support
2. **Menu System** — Party view, creature stats, move details
3. **Items** — Potions, capture devices, held items
4. **Capture Mechanic** — Throw a capture device, shake animation, catch calculation
5. **PC Storage** — Box system for storing extra creatures
6. **Evolution** — Level-based evolution with animation
7. **Map Transitions** — Walking between areas, door entrances
8. **Trainer AI** — Smarter move selection (prefer super-effective, switch creatures)
9. **More Content** — New creatures, evolutions, maps, trainers, gym leaders

## Controls
- **WASD** — Move
- **Space** — Interact / Confirm
- **Escape** — Cancel / Back
- **Tab** — Menu (not yet implemented)

## Project Structure
```
pokemon-like-godot/
├── project.godot              # Godot project config
├── data/
│   ├── creatures/             # Creature definitions (JSON)
│   ├── moves/                 # Move definitions (JSON)
│   └── maps/                  # Encounter tables (JSON)
├── scripts/
│   ├── autoload/              # Global managers
│   ├── battle/                # Battle system scripts
│   ├── overworld/             # Player, NPCs, grass
│   ├── data/                  # (for custom Resource scripts)
│   └── ui/                    # (for menu/dialogue scripts)
├── scenes/                    # Godot scene files (.tscn)
│   ├── overworld/
│   ├── battle/
│   ├── ui/
│   └── creatures/
├── assets/
│   ├── sprites/               # All sprite art
│   └── audio/                 # Music and SFX
└── resources/                 # Godot resources (.tres)
```

## Tips
- **Test battles early** — You can temporarily hardcode a battle trigger on a key press to test the battle system before wiring up grass encounters
- **Use Godot's debugger** — The print statements in the autoloads will help you trace what's happening
- **JSON is your friend** — Adding a new creature is just adding a JSON entry; no code changes needed
- **Keep it small first** — Get one map and 5 creatures fully working before expanding
