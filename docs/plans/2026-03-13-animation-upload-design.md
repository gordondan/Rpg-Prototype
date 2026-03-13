# Animation Upload & Image Type System Design

## Problem

The web editor's image upload pipeline resizes all creature sprites to 128x128, which destroys sprite sheet animations. Tilesets and sprite sheets need different processing than single character images. The upload component is also hardcoded for two sprite types (overworld/battle) and isn't reusable.

## Solution

A reusable image upload component with a type selector that drives different processing pipelines, including Godot resource generation for animations.

## Image Types

| Type | Processing | Output |
|------|-----------|--------|
| Character Image | Resize to 128x128, background removal | Single PNG |
| Animation (Sprite 2D) | No resize, Gemini grid detection, generate SpriteFrames .tres | Folder with sheet + .tres |
| Animation (Player) | No resize, Gemini grid detection, generate AnimationPlayer .tres | Folder with sheet + .tres |
| Map | None (pass-through) | Stored as-is |

## Folder Structure

Creatures get a folder when their first animation is uploaded. Legacy flat files continue to work.

```
assets/sprites/creatures/
├── flame_squire.png                    # legacy single sprites (still work)
├── flame_squire_battle.png
├── goblin_firebomber/                  # creature with animations
│   ├── overworld.png                   # character image (overworld)
│   ├── battle.png                      # character image (battle)
│   ├── idle/                           # animation folder
│   │   ├── spritesheet.png             # uploaded sprite sheet
│   │   └── idle.tres                   # generated Godot resource
│   └── walk/
│       ├── spritesheet.png
│       └── walk.tres
```

- Creature gets a folder only when an animation is uploaded (no big migration)
- Character images can live as legacy flat files OR inside the folder — backend checks both
- Animation name becomes the subfolder name
- Generated .tres file is named after the animation
- spritesheet.png is the consistent name inside each animation folder

## Backend Processing Pipeline

### Character Image (current behavior)
- Resize to max 128x128, background removal via rembg
- Save to `{creature_id}/overworld.png` or `battle.png` (or legacy flat path)

### Animation (Sprite 2D) / Animation (Player)
1. Save original sprite sheet (no resize, no bg removal) to `{creature_id}/{animation_name}/spritesheet.png`
2. If Gemini API key configured, call Gemini vision to auto-detect frame dimensions, columns, rows, frame count
3. Return detected values as editable defaults in response
4. On confirmation, generate the appropriate .tres resource:
   - **Sprite 2D**: SpriteFrames resource with AtlasTexture regions
   - **Player**: Animation resource with keyframed sprite regions
5. Save metadata alongside the animation

### Map
- Save as-is, no processing

### Gemini Integration
- Uses Gemini vision to analyze sprite sheet images
- Detects: frame dimensions, grid layout, total frame count
- Results are suggestions — user can override before generation
- Graceful fallback: if no API key or Gemini fails, user fills in fields manually

## Configuration

Gemini API key managed via existing pydantic-settings pattern:
- Add `gemini_api_key: str = ""` to `Settings` in `config.py`
- Add `.env` to `.gitignore`
- Key stored in `web/.env` (never committed)

## Frontend: Reusable ImageUpload Component

### Props
- `type`: valid image types for this context
- `entityId`: creature ID or other identifier
- `onUpload`: callback with result

### UI Flow
1. Type selector dropdown
2. File picker / drag-and-drop
3. For animation types, additional fields after file selection:
   - Animation name (text input)
   - Frame width x height (auto-populated by Gemini)
   - Columns x Rows (auto-populated)
   - Frame count (editable for partial last rows)
   - FPS (default 8)
   - Loop (default checked)
   - Preview of first detected frame
4. Upload triggers processing + resource generation

For Character Image and Map types, just file picker + upload (same as today).

### Usage
- `CreatureForm` — replaces hardcoded sprite upload buttons
- `AssetManager` — upload dialog
- Future pages can reuse with appropriate type constraints

## Godot Resource Generation

### SpriteFrames .tres (Sprite 2D type)
AtlasTexture per frame referencing regions of the sprite sheet. Includes animation name, FPS, loop settings.

### Animation .tres (Player type)
Keyframed texture/region_rect tracks. Each frame at `frame_index / FPS` seconds.

### Implementation
- New `SpriteSheetService` handles generation
- Writes .tres as text (Godot's text-based resource format)
- No Godot dependency — direct text generation
- Must produce files loadable by Godot without modification

## Animation Upload Defaults

| Field | Default | Auto-detected by Gemini |
|-------|---------|------------------------|
| Frame width | 64 | Yes |
| Frame height | 64 | Yes |
| Columns | image_width / frame_width | Yes |
| Rows | image_height / frame_height | Yes |
| Frame count | columns x rows | Yes |
| FPS | 8 | No |
| Loop | true | No |
