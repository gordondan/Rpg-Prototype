# Web Game Export Design

## Goal

Add a "Play Game" button to the MonsterQuest web app that lets users play the Godot game in their browser. The game is served as a separate nginx location with independent access control, and the export is automated as part of `publish.py`.

## Architecture

The Godot web export is served directly by nginx, completely separate from the FastAPI app. The React app links to it externally (new tab).

```
publish.py
  └── export_game()          # Godot --headless --export-release
  └── build_images()          # Docker build (unchanged)
  └── run_services()          # Docker up (unchanged)

nginx
  /monsta-quest/              # Proxy to FastAPI (existing)
  /monsta-quest/game/         # Static files: Godot web export (new)
                              # COOP/COEP headers scoped here only
```

## Components

### 1. Export Preset (`export_presets.cfg`)

Committed to repo so headless export works without manual setup. Contains a "Web" preset targeting `web/game/index.html`.

### 2. Publish Script (`publish.py`)

New `export_game()` step before `build_images()`:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" web/game/index.html
```

Outputs `.html`, `.wasm`, `.js`, `.pck` to `web/game/`.

### 3. Nginx Config (`web/nginx.conf`)

New location block before the existing `/monsta-quest/` catch-all:

```nginx
location /monsta-quest/game/ {
    alias /usr/share/nginx/html/game/;
    add_header Cross-Origin-Opener-Policy same-origin;
    add_header Cross-Origin-Embedder-Policy require-corp;
    try_files $uri $uri/ /usr/share/nginx/html/game/index.html;
}
```

Headers scoped only to `/game/` to avoid affecting the rest of the site.

### 4. Docker Compose (`web/docker-compose.yml`)

Volume mount game directory into nginx:

```yaml
nginx:
  volumes:
    - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    - ./game:/usr/share/nginx/html/game:ro
```

### 5. Sidebar Link (`web/frontend/src/components/Sidebar.tsx`)

External `<a>` tag (not NavLink) with `target="_blank"` using `Gamepad2` icon. Opens `/monsta-quest/game/` in a new tab. Placed above Asset Manager and Gallery.

### 6. Gitignore

`web/game/` added to `.gitignore` (build artifact).

## Decisions

- **Approach C (separate nginx location)** chosen over iframe or direct React integration — allows independent access control policies for the game vs. the editor.
- **COOP/COEP headers scoped to `/game/` only** — avoids breaking OAuth, third-party embeds, etc. on the editor.
- **Export automated in `publish.py`** — ensures game is always up to date on deploy, at the cost of requiring Godot installed on the deploy machine.
