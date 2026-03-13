# Sprite Version History

## Problem

When a sprite is uploaded to replace an existing one, the processed game-ready file is overwritten in place. The old sprite is lost and cannot be recovered. Users want the ability to revert to previous sprites.

## Solution

Automatically archive the current sprite before overwriting it. Store archived versions as timestamped files in `.versions/` subfolders. Provide API endpoints and UI to browse and restore old versions.

## Storage

Each sprite category gets its own `.versions/` subfolder:

```
assets/sprites/creatures/.versions/
  flame_squire_battle_2026-03-10T14-30-00.png
  flame_squire_battle_2026-03-08T09-15-22.png
assets/sprites/npcs/.versions/
  town_guard_2026-03-09T11-00-00.png
```

- Filename format: `{original_stem}_{ISO-timestamp}.png`
- ISO timestamp uses hyphens instead of colons for filesystem compatibility (e.g., `2026-03-10T14-30-00`)
- No limit on number of versions kept
- `.versions/` directories are committed to git (shared across the team)

## Backend Changes

### `asset_service.py` — Archive Before Overwrite

In `process_sprite()` and `save_uploaded_file()`, before writing to the target path:

1. Check if the target file already exists
2. If it does, copy it to the corresponding `.versions/` subfolder with a timestamp suffix
3. Create the `.versions/` directory if it doesn't exist
4. Proceed with the normal write

```python
def _archive_if_exists(self, full_path: Path) -> None:
    if not full_path.exists():
        return
    versions_dir = full_path.parent / ".versions"
    versions_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    stem = full_path.stem
    archive_name = f"{stem}_{timestamp}{full_path.suffix}"
    shutil.copy2(full_path, versions_dir / archive_name)
```

### New API Endpoints in `assets.py`

#### `GET /api/assets/versions/{path:path}`

List all archived versions of a sprite.

- **Input:** Relative path to the current sprite (e.g., `assets/sprites/creatures/flame_squire_battle.png`)
- **Output:** JSON array of version objects, sorted newest first:

```json
[
  {
    "timestamp": "2026-03-10T14-30-00",
    "filename": "flame_squire_battle_2026-03-10T14-30-00.png",
    "thumbnail_url": "/api/assets/thumbnail/assets/sprites/creatures/.versions/flame_squire_battle_2026-03-10T14-30-00.png",
    "size_bytes": 4523,
    "date_display": "Mar 10, 2026"
  }
]
```

- Scans the `.versions/` directory for files matching the sprite's stem prefix
- Parses timestamps from filenames to sort and format dates

#### `POST /api/assets/versions/{path:path}/restore/{timestamp}`

Restore a specific version as the active sprite.

- **Input:** Path to the current sprite + timestamp identifier
- **Behavior:**
  1. Archive the current sprite first (using `_archive_if_exists`)
  2. Copy the selected version file to the active sprite path
  3. Return success with the new active path
- **Output:** `{"status": "restored", "path": "assets/sprites/creatures/flame_squire_battle.png"}`

### Existing Endpoints — No Changes

- `POST /api/assets/upload/{path}` — unchanged externally; internally calls `_archive_if_exists` before processing
- `GET /api/assets/thumbnail/{path}` — already works for any path, so `.versions/` thumbnails work automatically
- `DELETE /api/assets/{path}` — unchanged; does not affect versions

## Frontend Changes

### `CreatureForm.tsx` — Inline History Panel

**New UI elements per sprite (overworld and battle):**

1. A clock/history icon button added alongside the existing upload and download buttons
2. Clicking it toggles an expandable panel below the sprite thumbnails
3. The panel contains a horizontally scrollable strip of version thumbnails

**Panel contents per version:**
- 56x56px thumbnail (using existing `/api/assets/thumbnail/` endpoint)
- Date label (e.g., "Mar 10")
- "Restore" link that calls the restore endpoint and refreshes the sprite display

**Current sprite indicator:**
- The current/active sprite is highlighted with a gold border and labeled "Current"
- Archived versions have a neutral border

**State management:**
- New state: `historyOpen: { overworld: boolean, battle: boolean }` — which panels are expanded
- New state: `versions: { overworld: VersionEntry[], battle: VersionEntry[] }` — fetched from API
- Versions are fetched when the panel is opened (lazy loading)
- After a restore, re-fetch versions and increment `spriteRev` to refresh thumbnails

### `AssetDetailModal.tsx` — Version History in Asset Manager

The same inline history panel pattern is added to the asset detail modal:
- A "Version History" section below the asset preview
- Same horizontal scrollable strip of thumbnails with restore buttons
- Uses the same API endpoints

### New API Client Functions in `assets.ts`

```typescript
assetsApi.versions(path: string): Promise<VersionEntry[]>
assetsApi.restore(path: string, timestamp: string): Promise<void>
```

## Behavior Rules

| Scenario | What Happens |
|----------|-------------|
| First upload (no existing sprite) | No archiving — nothing to save |
| Upload replacing existing sprite | Current sprite archived to `.versions/`, new one saved |
| Restore an old version | Current sprite archived first, then old version copied to active path |
| Delete a sprite | Only the active sprite is deleted; versions remain in `.versions/` |
| Multiple uploads same second | Timestamp includes seconds; collisions extremely unlikely but could append a counter if needed |

## What Does NOT Change

- Game engine sprite loading — convention-based paths, no modifications needed
- Godot `.import` files — not generated for `.versions/` contents
- `original/` folder behavior — still stores unprocessed uploads as before
- `asset_metadata.json` — versions don't get separate metadata entries
- Sprite processing pipeline (background removal, resize, RGBA conversion)
