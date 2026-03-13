# Web Game Export Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Play Game" button to the web app that opens the Godot game in the browser, with automated export integrated into `publish.py`.

**Architecture:** Godot web export runs as a pre-build step in `publish.py`, outputting static files to `web/game/`. Nginx serves these directly at `/monsta-quest/game/` with COOP/COEP headers, independent from FastAPI. The React sidebar links to the game in a new tab.

**Tech Stack:** Godot 4.6.1 (headless export), nginx (static serving), React + lucide-react (sidebar link)

---

### Task 1: Create Godot Web Export Preset

**Files:**
- Create: `export_presets.cfg`
- Modify: `.gitignore:16-17`

**Step 1: Generate the export preset**

Run Godot headless to create a Web export preset. Open the Godot editor, go to **Project → Export → Add → Web**, then close.

Alternatively, create `export_presets.cfg` manually at the repo root:

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="web/game/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

**Step 2: Un-ignore export_presets.cfg**

In `.gitignore`, remove the `export_presets.cfg` line (line 17). Keep the `export/` line.

Change `.gitignore:16-17` from:
```
export/
export_presets.cfg
```
to:
```
export/
```

**Step 3: Add web/game/ to .gitignore**

Add `web/game/` to `.gitignore` (build artifact). Add it after the `export/` line:
```
export/
web/game/
```

**Step 4: Test the export**

Run:
```bash
mkdir -p web/game
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" web/game/index.html
```

Expected: `web/game/` contains `index.html`, `index.wasm`, `index.js`, `index.pck` (and possibly `index.audio.worklet.js`, `index.worker.js`).

**Step 5: Commit**

```bash
git add export_presets.cfg .gitignore
git commit -m "feat: add Godot web export preset and gitignore updates"
```

---

### Task 2: Add export_game() to publish.py

**Files:**
- Modify: `publish.py:1-58`

**Step 1: Add the export_game function**

Add after the `err()` function definition (after line 40) in `publish.py`:

```python
GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"
GAME_OUTPUT = SCRIPT_DIR / "web" / "game"


def export_game():
    """Export Godot project to web format."""
    if not Path(GODOT_BIN).exists():
        err(f"Godot not found at {GODOT_BIN}")
        err("Install Godot 4.6+ or update GODOT_BIN path.")
        sys.exit(1)

    log("Exporting game for web...")
    GAME_OUTPUT.mkdir(parents=True, exist_ok=True)
    output_file = GAME_OUTPUT / "index.html"
    result = subprocess.run(
        [GODOT_BIN, "--headless", "--export-release", "Web", str(output_file)],
        cwd=str(SCRIPT_DIR),
    )
    if result.returncode != 0:
        err("Game export failed.")
        sys.exit(result.returncode)
    ok("Game exported successfully.")
```

**Step 2: Call export_game() in the default action**

Change the `main()` default action from:
```python
    if action == "default":
        build_images()
        run_services()
```
to:
```python
    if action == "default":
        export_game()
        build_images()
        run_services()
```

**Step 3: Add export as a standalone action**

Add to the `ACTIONS` dict:
```python
ACTIONS = {
    "export": export_game,
    "build": build_images,
    ...
}
```

**Step 4: Update the URLs printed on startup**

In `run_services()`, add the game URL:
```python
    ok("  Game:     http://localhost:8080/monsta-quest/game/")
```

**Step 5: Test export_game standalone**

Run:
```bash
python publish.py export
```

Expected: "Exporting game for web..." → "Game exported successfully." and files in `web/game/`.

**Step 6: Commit**

```bash
git add publish.py
git commit -m "feat: add Godot web export step to publish.py"
```

---

### Task 3: Configure Nginx to Serve the Game

**Files:**
- Modify: `web/nginx.conf:1-28`
- Modify: `web/docker-compose.yml:11-23`

**Step 1: Add game location block to nginx.conf**

Insert before the existing `/monsta-quest/` block (before line 16). The full `nginx.conf` becomes:

```nginx
server {
    listen 80;
    server_name _;
    absolute_redirect off;

    client_max_body_size 50M;

    location = /monsta-quest {
        return 301 /monsta-quest/;
    }

    location / {
        return 301 /monsta-quest$request_uri;
    }

    location /monsta-quest/game/ {
        alias /usr/share/nginx/html/game/;
        add_header Cross-Origin-Opener-Policy same-origin;
        add_header Cross-Origin-Embedder-Policy require-corp;
        try_files $uri $uri/ /usr/share/nginx/html/game/index.html;
    }

    location /monsta-quest/ {
        proxy_pass http://api:8000/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Prefix /monsta-quest;

        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
    }
}
```

**Step 2: Add game volume mount to docker-compose.yml**

Add the game directory volume to the nginx service. Change the nginx volumes from:
```yaml
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
```
to:
```yaml
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./game:/usr/share/nginx/html/game:ro
```

**Step 3: Test with Docker**

Run:
```bash
python publish.py
```

Then visit `http://localhost:8080/monsta-quest/game/` in a browser. The Godot game should load and run.

Verify headers:
```bash
curl -I http://localhost:8080/monsta-quest/game/
```
Expected: Response includes `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.

**Step 4: Commit**

```bash
git add web/nginx.conf web/docker-compose.yml
git commit -m "feat: serve Godot web export via nginx with COOP/COEP headers"
```

---

### Task 4: Add "Play Game" Link to Sidebar

**Files:**
- Modify: `web/frontend/src/components/Sidebar.tsx:1-136`

**Step 1: Add Gamepad2 to lucide-react imports**

In `Sidebar.tsx` line 3-16, add `Gamepad2` to the import:

```typescript
import {
  Sword,
  Zap,
  Package,
  Map,
  Store,
  ImageIcon,
  GalleryHorizontalEnd,
  ChevronRight,
  ChevronLeft,
  PawPrint,
  ScrollText,
  Users,
  Gamepad2,
} from 'lucide-react'
```

**Step 2: Add the Play Game link**

After the separator `<div>` (line 110) and before the `{/* Main links */}` comment (line 112), add the Play Game external link:

```tsx
          {/* Play Game */}
          <a
            href={`${import.meta.env.BASE_URL}game/`.replace(/\/\/$/, '/')}
            target="_blank"
            rel="noopener noreferrer"
            className={cn(
              'flex items-center gap-2 rounded-md px-2 py-1.5 text-sm transition-colors',
              collapsed && 'justify-center px-0',
              'text-parchment/70 hover:text-parchment hover:bg-stone-light/30'
            )}
            title={collapsed ? 'Play Game' : undefined}
          >
            <Gamepad2 className="size-4 shrink-0" />
            {!collapsed && 'Play Game'}
          </a>

          {/* Separator */}
          <div className="mx-2 my-2 h-px bg-stone-light/30" />
```

Move the existing separator to after the Play Game link (so it separates Play Game from the tool links below).

**Step 3: Verify in dev mode**

Run:
```bash
cd web/frontend && npm run dev
```

Check sidebar shows "Play Game" with gamepad icon. Click should open a new tab pointing to `/game/` (will 404 in dev since nginx isn't running, that's expected).

**Step 4: Commit**

```bash
git add web/frontend/src/components/Sidebar.tsx
git commit -m "feat: add Play Game link to sidebar"
```

---

### Task 5: End-to-End Test

**Step 1: Full publish**

```bash
python publish.py
```

**Step 2: Verify game loads**

Visit `http://localhost:8080/monsta-quest/game/` — game should load and be playable.

**Step 3: Verify sidebar link**

Visit `http://localhost:8080/monsta-quest/` — sidebar should show "Play Game" button. Clicking opens game in new tab.

**Step 4: Verify headers are scoped**

```bash
# Game path should have COOP/COEP headers
curl -sI http://localhost:8080/monsta-quest/game/ | grep -i "cross-origin"

# App path should NOT have COOP/COEP headers
curl -sI http://localhost:8080/monsta-quest/ | grep -i "cross-origin"
```

**Step 5: Final commit if any fixes needed**
