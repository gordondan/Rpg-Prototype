# Sprite Processing Pipeline

## Overview

On upload and via a batch "Reprocess All" button, convert GIF/JPEG to PNG and resize to 128x128 game-ready versions. Keep full-resolution originals in an `original/` subdirectory.

## Directory Structure

```
assets/sprites/creatures/
├── flame_squire.png              # game-ready (128x128)
├── flame_squire_battle.png       # game-ready (128x128)
├── original/
│   ├── flame_squire.png          # full resolution source
│   └── flame_squire_battle.png   # full resolution source
```

## Processing Rules

1. Format conversion — GIF/JPEG inputs get converted to PNG
2. Resize — Fit within 128x128, preserving aspect ratio (PIL thumbnail with LANCZOS)
3. Original preservation — Save/move the full-res file to `original/` before writing the game-ready version
4. Already-small images — If already ≤128px in both dimensions, still copy to `original/` but game-ready version is effectively the same

## On Upload

When a sprite is uploaded via `POST /api/assets/upload/{path}`:
1. Save full-res to `original/{filename}`
2. Resize to 128x128 and save to the normal path as PNG
3. Return success

## Batch Reprocess

New endpoint `POST /api/assets/reprocess-sprites`:
1. Scan all files in `assets/sprites/creatures/` (excluding `original/`)
2. For each: move current file to `original/`, generate 128x128 game-ready version
3. Return count of processed files

Triggered from a button on the web page.

## Web Editor

- Thumbnails and form previews use game-ready versions (already ≤128px)
- Download button downloads from `original/` (full resolution)

## Scope

- Creatures only (not NPCs/tilesets)
- No Godot code changes (paths unchanged)
