# Sprite Version History

## Problem

When a sprite is uploaded to replace an existing one, the processed game-ready file is overwritten in place. The old sprite is lost and cannot be recovered. Users want the ability to revert to previous sprites.

## Solution

Automatically archive the current sprite before overwriting it. Store archived versions as timestamped files in `.versions/` subfolders. Provide API endpoints and UI to browse and restore old versions.

## Storage

Each sprite category gets its own `.versions/` subfolder:

```
assets/sprites/creatures/.versions/
  flame_squire_battle_2026-03-10T14-30-00-123456.png
  flame_squire_battle_2026-03-08T09-15-22-654321.png
assets/sprites/npcs/.versions/
  town_guard_2026-03-09T11-00-00-000000.png
```

- Filename format: `{original_stem}_{ISO-timestamp}.png`
- ISO timestamp uses hyphens instead of colons for filesystem compatibility, with microsecond precision to avoid collisions: `%Y-%m-%dT%H-%M-%S-%f` (e.g., `2026-03-10T14-30-00-123456`)
- No limit on number of versions kept
- `.versions/` directories are committed to git (shared across the team)
- A `.gdignore` file is created inside each `.versions/` directory to prevent Godot from scanning/importing archived sprites

## Backend Changes

### `asset_service.py` — Archive Before Overwrite

A new private method `_archive_if_exists()` handles versioning. It is called from the **upload route handler** in `assets.py`, not from `process_sprite()` or `save_uploaded_file()` directly. This keeps the archiving decision at the route level, so that `reprocess_all_sprites()` does not accidentally archive sprites during a pipeline re-run.

```python
def _archive_if_exists(self, full_path: Path) -> None:
    if not full_path.exists():
        return
    versions_dir = full_path.parent / ".versions"
    versions_dir.mkdir(parents=True, exist_ok=True)
    # Ensure Godot ignores this directory
    gdignore = versions_dir / ".gdignore"
    if not gdignore.exists():
        gdignore.touch()
    timestamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S-%f")
    stem = full_path.stem
    archive_name = f"{stem}_{timestamp}{full_path.suffix}"
    shutil.copy2(full_path, versions_dir / archive_name)
```

### `list_assets()` — Exclude `.versions/`

The existing `list_assets()` method uses `rglob("*")` and already filters out `original/` paths. Add a matching filter to exclude files under `.versions/` directories, so archived sprites do not appear as regular assets in the Asset Manager.

### New API Endpoints in `assets.py`

#### `GET /api/assets/versions/{path:path}`

List all archived versions of a sprite.

- **Input:** Relative path to the current sprite (e.g., `assets/sprites/creatures/flame_squire_battle.png`)
- **Output:** JSON array of version objects, sorted newest first:

```json
[
  {
    "timestamp": "2026-03-10T14-30-00-123456",
    "filename": "flame_squire_battle_2026-03-10T14-30-00-123456.png",
    "thumbnail_url": "/api/assets/thumbnail/assets/sprites/creatures/.versions/flame_squire_battle_2026-03-10T14-30-00-123456.png",
    "size_bytes": 4523,
    "date_display": "Mar 10, 2026"
  }
]
```

- Scans the `.versions/` directory for files matching the pattern `^{stem}_\d{4}-\d{2}-\d{2}T` to avoid false positives (e.g., `flame_squire` matching `flame_squire_battle` versions)
- Parses timestamps from filenames to sort and format dates
- Returns **404** if the sprite path is invalid or the parent directory does not exist

#### `POST /api/assets/versions/{path:path}/restore/{timestamp}`

Restore a specific version as the active sprite.

- **Input:** Path to the current sprite + timestamp identifier
- **Behavior:**
  1. Archive the current sprite first (using `_archive_if_exists`)
  2. Copy the selected version file to the active sprite path
  3. Return success with the new active path
- **Output:** `{"status": "restored", "path": "assets/sprites/creatures/flame_squire_battle.png"}`
- **Errors:**
  - **404** if the version file matching the timestamp is not found
  - **404** if the sprite path is invalid

### Existing Endpoints — Changes

- `POST /api/assets/upload/{path}` — the route handler now calls `_archive_if_exists` before delegating to `process_sprite()` or `save_uploaded_file()`
- `GET /api/assets/thumbnail/{path}` — already works for any path, so `.versions/` thumbnails work automatically
- `GET /api/assets/` (`list_assets`) — updated to exclude `.versions/` paths
- `DELETE /api/assets/{path}` — unchanged; does not affect versions (orphaned versions are a known limitation, cleanup can be added later)

## Frontend Changes

### TypeScript Types in `assets.ts`

```typescript
interface VersionEntry {
  timestamp: string
  filename: string
  thumbnail_url: string
  size_bytes: number
  date_display: string
}
```

### New API Client Functions in `assets.ts`

```typescript
assetsApi.versions(path: string): Promise<VersionEntry[]>
assetsApi.restore(path: string, timestamp: string): Promise<void>
```

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

### NPC Sprites — Backend Only for Now

NPC sprite versioning is handled by the same backend `_archive_if_exists` mechanism (since NPC uploads go through the same upload route). However, the NPC sprite UI in `CreatureForm.tsx` does not currently have a dedicated history panel — this will be added in a future iteration. NPC sprite versions can still be browsed via the Asset Manager's detail modal.

## Behavior Rules

| Scenario | What Happens |
|----------|-------------|
| First upload (no existing sprite) | No archiving — nothing to save |
| Upload replacing existing sprite | Current sprite archived to `.versions/`, new one saved |
| Restore an old version | Current sprite archived first, then old version copied to active path |
| Delete a sprite | Only the active sprite is deleted; versions remain in `.versions/` (known limitation) |
| Reprocess all sprites | No archiving — `reprocess_all_sprites()` does not trigger `_archive_if_exists` |

## What Does NOT Change

- Game engine sprite loading — convention-based paths, no modifications needed
- Godot import scanning — `.gdignore` in `.versions/` prevents Godot from processing archived sprites
- `original/` folder behavior — still stores unprocessed uploads as before
- `asset_metadata.json` — versions don't get separate metadata entries
- Sprite processing pipeline (background removal, resize, RGBA conversion)
