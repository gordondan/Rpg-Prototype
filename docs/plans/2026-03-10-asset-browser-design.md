# Asset Browser/Editor Design

## Overview

A web-based asset browser and editor for the MonsterQuest Godot project, served at `rpg1.dagordons.com`. Allows browsing, editing, and managing game data (creatures, moves, items, maps, shops) and sprite/audio assets through a fantasy-accented clean UI. All writes are git-backed for full audit trail and easy rollback.

## Architecture

**Stack:** FastAPI (Python) + React (Vite/TypeScript) monolith
**Deployment:** Docker container with nginx reverse proxy, connected to Cloudflare tunnel via `cloudflare-tunnel` Docker network (same pattern as `todo.dagordons.com`)
**Auth:** Handled at nginx layer via Google OAuth — app itself has no auth logic

### Project Structure

```
monster-game/web/
├── docker-compose.yml
├── Dockerfile
├── nginx.conf
├── .dockerignore
├── requirements.txt
├── backend/
│   ├── app.py                  # FastAPI entry point, serves React build + API
│   ├── routers/
│   │   ├── creatures.py        # CRUD for creature JSON data
│   │   ├── moves.py            # CRUD for moves
│   │   ├── items.py            # CRUD for items
│   │   ├── maps.py             # CRUD for encounter tables
│   │   ├── shops.py            # CRUD for shops
│   │   ├── assets.py           # Sprite upload/replace/rename/browse
│   │   └── git_ops.py          # Commit history, diff, rollback
│   ├── services/
│   │   ├── git_service.py      # GitPython wrapper
│   │   ├── data_service.py     # JSON read/write with validation
│   │   └── asset_service.py    # File operations, thumbnail generation
│   └── models/
│       └── schemas.py          # Pydantic models matching game JSON schemas
├── frontend/
│   ├── package.json
│   ├── vite.config.ts
│   ├── src/
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   ├── components/         # Shared UI components
│   │   ├── pages/
│   │   │   ├── DataEditor/     # Creature/move/item editing
│   │   │   ├── AssetManager/   # Upload, replace, rename sprites
│   │   │   └── Gallery/        # Browse all assets visually
│   │   ├── api/                # API client functions
│   │   └── theme/              # Fantasy-accented styling
│   └── public/
```

## Feature 1: Data Editor (Priority 1)

Sidebar nav lists data categories: Creatures, Moves, Items, Maps, Shops.

### Creatures Editor

- **Left panel:** Searchable/filterable list of all creatures (starters + wild). Shows name, sprite thumbnail, types as colored badges.
- **Right panel:** Form editor with sections:
  - **Identity** — name, description, class, types (dropdown with type colors)
  - **Base Stats** — numeric inputs for HP/ATK/DEF/SP.ATK/SP.DEF/SPD with radar chart preview
  - **Learnset** — table of level + move_id pairs, add/remove rows, move_id is searchable dropdown from moves.json
  - **Evolution** — optional: target creature_id (dropdown), level, flavor text
  - **Recruitment** (wild only) — method, chance (slider 0-1), dialogue text
  - **Sprites** — thumbnail previews of overworld + battle sprites, click to jump to Asset Manager

### Moves Editor

Same list+detail pattern. Fields: name, type, category (physical/special/status), power, accuracy, PP, description, effect_chance, effect object.

### Items, Maps, Shops

Same pattern, forms matching their JSON schemas.

### Change Tracking

- Edited fields get a subtle highlight
- Persistent bottom bar: "3 unsaved changes" with Save and Discard buttons
- Save = auto-commit behind the scenes (branch created automatically, no user-facing branch workflow)
- Toast confirms save with brief summary ("Updated Flame Squire stats")
- History button opens panel showing recent commits with diffs and per-commit Revert option

## Feature 2: Asset Manager (Priority 2)

### Layout

Grid view of sprite directories as folders: Creatures, NPCs, Tilesets, Audio.

### Creature Assets View

- Cards show overworld + battle sprites side by side (placeholder if missing)
- Color-coded by status: green = both present, yellow = missing one, red = no sprites
- Badges flag naming issues (e.g., typos like "Spark Theif.png")

### Actions

- **Replace** — drag-and-drop or file picker
- **Rename** — inline, with warning if it breaks naming convention
- **Delete** — with confirmation
- **Upload** — for adding missing sprites
- **Bulk upload** — drag-and-drop zone, auto-matches to creatures by filename

### Sprite Preview

- Click for larger modal with file size, dimensions, repo path
- Battle sprites shown at game scale (480x320 viewport)

### Audio Assets

- Playback controls (play/pause/seek)
- Same replace/rename/delete/upload actions

### Asset Metadata

Each asset has a `status` stored in `web/asset_metadata.json` (git-tracked):
- **Active** — in use in the game
- **In Development** — work in progress
- **Deprecated** — being phased out
- **Unused** — not referenced

### Dashboard Bar (top of Asset Manager)

Summary chips: `12 Active` / `4 In Development` / `2 Deprecated` / `3 Unused` / `5 Missing Sprites`
- Each chip filters the view
- "Needs Attention" count (in-dev + deprecated + missing) is prominent

### Filtering & Sorting

- Filter by: status, creature type, sprite completeness
- Sort by: name, status, file size, last modified
- Persistent filter state

## Feature 3: Gallery (Priority 3)

- Grid of all sprites, large thumbnails
- Lightbox view with metadata overlay (dimensions, size, status, owner creature/NPC)
- Category tabs: Creatures, NPCs, Tilesets, Audio
- Side-by-side compare: select two sprites to view together
- Search by filename or creature name

## Git Workflow

Invisible to the user. Implementation:

- Container mounts the game repo
- On first edit, auto-creates a working branch (no user interaction)
- "Save" button commits changes with descriptive messages
- Bottom bar shows count of uncommitted changes
- History panel shows commit log with diffs
- Revert option per commit
- User merges branches via GitHub (or future PR integration)

## UI Theme

**Base:** Clean modern admin (Shadcn/UI or Radix components)

**Fantasy accents:**
- Heading font: "Cinzel" or "MedievalSharp" (Google Fonts)
- Body: clean sans-serif
- Subtle stone/parchment texture on sidebar
- Element-colored type badges (fire=red/orange, water=blue, etc.)
- Ornate border on creature cards
- Palette: dark slate, warm golds, aged parchment
- Minimal decoration — thematic but not overwhelming

**Layout:**
- Collapsible sidebar with nav + dashboard chips
- Breadcrumbs in main content area
- Persistent bottom change bar
- Desktop-first, responsive but not mobile-optimized

## Deployment

Follows the same pattern as `todo.dagordons.com`:
- Docker container runs FastAPI serving built React + API
- nginx reverse proxy in front
- Connected to `cloudflare-tunnel` external Docker network
- Cloudflare DNS routes `rpg1.dagordons.com` to the tunnel
- Auth via Google OAuth at nginx layer
