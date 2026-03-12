# Docker Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy MonsterQuest web app at `rpg.dagordons.com/monsta-quest` behind Cloudflare tunnel, with local access at `localhost:8080/monsta-quest`.

**Architecture:** nginx reverse proxy strips `/monsta-quest/` prefix before forwarding to FastAPI on port 8000. Frontend built with Vite `base` set to `/monsta-quest/`. Same Docker + Cloudflare tunnel pattern as the todo app.

**Tech Stack:** Docker Compose, nginx:alpine, Vite (base path), React Router (basename), Cloudflare Tunnel

**Design doc:** `docs/plans/2026-03-12-docker-deployment-design.md`

---

### Task 1: Update nginx.conf for subpath routing

**Files:**
- Modify: `web/nginx.conf`

**Reference:** `~/source/repos/todo-lists/nginx.conf` uses same pattern for `/todo-list/`.

**Step 1: Replace nginx.conf contents**

```nginx
server {
    listen 80;
    server_name _;

    client_max_body_size 50M;

    location = /monsta-quest {
        return 301 /monsta-quest/;
    }

    location / {
        return 301 /monsta-quest$request_uri;
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

Key points:
- `location /monsta-quest/` with `proxy_pass http://api:8000/` — trailing slashes on both sides strip the prefix
- `location = /monsta-quest` — redirect bare path to trailing-slash version
- `location /` — catch-all redirect to `/monsta-quest/`

**Step 2: Commit**

```bash
git add web/nginx.conf
git commit -m "feat: update nginx.conf for /monsta-quest/ subpath routing"
```

---

### Task 2: Update docker-compose.yml

**Files:**
- Modify: `web/docker-compose.yml`

**Step 1: Update docker-compose.yml**

The file already has `8080:80` and the `cloudflare-tunnel` network. Add container names and a project name for clarity:

```yaml
services:
  api:
    build: .
    container_name: monsta-quest-api
    volumes:
      - ${REPO_PATH:-/Users/gordon/Documents/Tyrell/monster-game}:/repo
    environment:
      - REPO_PATH=/repo
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    container_name: monsta-quest-nginx
    ports:
      - "8080:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - api
    restart: unless-stopped
    networks:
      - default
      - cloudflare-tunnel

networks:
  cloudflare-tunnel:
    external: true
```

Only change: add `container_name` to both services.

**Step 2: Commit**

```bash
git add web/docker-compose.yml
git commit -m "feat: add container names to docker-compose"
```

---

### Task 3: Update frontend API base URL

**Files:**
- Modify: `web/frontend/src/api/client.ts`
- Modify: `web/frontend/src/api/assets.ts`

This is the critical change that makes the frontend subpath-aware.

**Step 1: Update client.ts to derive BASE from Vite's BASE_URL**

Change line 1 from:
```typescript
const BASE = '/api'
```
to:
```typescript
// import.meta.env.BASE_URL is '/' in dev, '/monsta-quest/' in prod
export const BASE = `${import.meta.env.BASE_URL}api`
```

This resolves to:
- Dev: `/api` (unchanged behavior)
- Prod: `/monsta-quest/api`

**Step 2: Update assets.ts to use BASE instead of hardcoded '/api'**

Change the import line and all hardcoded `/api` references:

```typescript
import { get, post, httpDelete, BASE } from './client'
```

Update the four methods that hardcode `/api`:
- `thumbnailUrl`: `` `/api/assets/thumbnail/...` `` → `` `${BASE}/assets/thumbnail/...` ``
- `fileUrl`: `` `/api/assets/file/...` `` → `` `${BASE}/assets/file/...` ``
- `updateStatus`: `` `/api/assets/status/...` `` → `` `${BASE}/assets/status/...` ``
- `upload`: `` `/api/assets/upload/...` `` → `` `${BASE}/assets/upload/...` ``

Full updated file:

```typescript
import { get, post, httpDelete, BASE } from './client'

export interface AssetInfo {
  path: string
  filename: string
  category: string
  size_bytes: number
  width?: number
  height?: number
  status: string
  notes: string
}

export const assetsApi = {
  list: (category?: string) =>
    get<AssetInfo[]>(`/assets/${category ? `?category=${category}` : ''}`),
  summary: () => get<Record<string, number>>('/assets/summary'),
  thumbnailUrl: (path: string, size = 128) =>
    `${BASE}/assets/thumbnail/${path}?size=${size}`,
  fileUrl: (path: string) => `${BASE}/assets/file/${path}`,
  updateStatus: (path: string, status: string, notes = '') =>
    fetch(`${BASE}/assets/status/${path}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status, notes }),
    }),
  upload: (path: string, file: File) => {
    const fd = new FormData()
    fd.append('file', file)
    return fetch(`${BASE}/assets/upload/${path}`, { method: 'POST', body: fd })
  },
  delete: (path: string) => httpDelete(`/assets/${path}`),
  rename: (oldPath: string, newPath: string) =>
    post('/assets/rename', { old_path: oldPath, new_path: newPath }),
}
```

Note: `list`, `summary`, `delete`, and `rename` go through the `client.ts` functions which already prepend `BASE`, so they remain unchanged.

**Step 3: Commit**

```bash
git add web/frontend/src/api/client.ts web/frontend/src/api/assets.ts
git commit -m "feat: make API base URL subpath-aware using Vite BASE_URL"
```

---

### Task 4: Fix hardcoded /api references in components

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureList.tsx` (lines 159, 390)
- Modify: `web/frontend/src/pages/DataEditor/CreatureForm.tsx` (lines 56, 70, 92, 109, 130, 518, 557)

These components have hardcoded `/api` in fetch calls, img src attributes, and audio URLs.

**Step 1: Update CreatureList.tsx**

Add import at top:
```typescript
import { BASE } from '@/api/client'
```

Line 159 — reprocess fetch:
```typescript
// Before:
const res = await fetch('/api/assets/reprocess-sprites', { method: 'POST' })
// After:
const res = await fetch(`${BASE}/assets/reprocess-sprites`, { method: 'POST' })
```

Line 390 — thumbnail img src:
```typescript
// Before:
src={`/api/assets/thumbnail/${creature.npc_sprite ? creature.npc_sprite.replace('res://', '') : spritePath(id, 'battle')}?size=64`}
// After:
src={`${BASE}/assets/thumbnail/${creature.npc_sprite ? creature.npc_sprite.replace('res://', '') : spritePath(id, 'battle')}?size=64`}
```

**Step 2: Update CreatureForm.tsx**

Add import at top:
```typescript
import { BASE } from '@/api/client'
```

Replace ALL occurrences of the literal string `/api/assets/` with `${BASE}/assets/` in:
- Line 56: `fetch(`/api/assets/upload/${path}`...)` → `fetch(`${BASE}/assets/upload/${path}`...)`
- Line 70: `a.href = `/api/assets/file/${originalPath}`` → `a.href = `${BASE}/assets/file/${originalPath}``
- Line 92: `src={`/api/assets/thumbnail/...`}` → `src={`${BASE}/assets/thumbnail/...`}`
- Line 109: same pattern
- Line 130: same pattern
- Line 518: `fetch(`/api/assets/upload/${path}`...)` → `fetch(`${BASE}/assets/upload/${path}`...)`
- Line 557: `new Audio(`/api/assets/file/${audioPath}`)` → `new Audio(`${BASE}/assets/file/${audioPath}`)`

**Step 3: Verify no remaining hardcoded /api references**

Run: `grep -r "'/api\|\"\/api\|\`/api" web/frontend/src/ --include="*.ts" --include="*.tsx"`

Expected: Only `client.ts` BASE definition should remain.

**Step 4: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureList.tsx web/frontend/src/pages/DataEditor/CreatureForm.tsx
git commit -m "fix: replace hardcoded /api refs with BASE in components"
```

---

### Task 5: Update Vite config and React Router for subpath

**Files:**
- Modify: `web/frontend/vite.config.ts`
- Modify: `web/frontend/src/App.tsx`

**Step 1: Add base to vite.config.ts**

Add `base: '/monsta-quest/',` to the config. This tells Vite to prefix all asset URLs with `/monsta-quest/` in production builds. In dev mode, Vite ignores this for the dev server.

```typescript
export default defineConfig({
  base: '/monsta-quest/',
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
})
```

**Step 2: Add basename to BrowserRouter in App.tsx**

The basename must match the subpath so React Router generates correct URLs. Use `import.meta.env.BASE_URL` to keep it DRY (Vite sets this from the `base` config, with trailing slash removed for basename).

```typescript
function App() {
  // import.meta.env.BASE_URL is '/monsta-quest/' in prod, '/' in dev
  // React Router basename needs no trailing slash
  const basename = import.meta.env.BASE_URL.replace(/\/$/, '') || '/'

  return (
    <ChangeProvider>
      <BrowserRouter basename={basename}>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/" element={<Navigate to="/editor/creatures" replace />} />
            <Route path="/editor/:category/:id?" element={<DataEditor />} />
            <Route path="/assets/*" element={<AssetManager />} />
            <Route path="/gallery" element={<Gallery />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </ChangeProvider>
  )
}
```

Note: Route paths stay as `/editor/...`, `/assets/...` etc. — React Router prepends the basename automatically.

**Step 3: Test dev server still works**

Run: `cd web/frontend && npm run dev`

Open: `http://localhost:5173/` — should work normally (basename resolves to `/` in dev).

**Step 4: Test production build**

Run: `cd web/frontend && npm run build`

Verify: Check `dist/index.html` — script/link tags should reference `/monsta-quest/assets/...`.

Run: `grep -o 'src="[^"]*"' web/frontend/dist/index.html`

Expected: paths starting with `/monsta-quest/assets/`

**Step 5: Commit**

```bash
git add web/frontend/vite.config.ts web/frontend/src/App.tsx
git commit -m "feat: configure Vite base path and Router basename for /monsta-quest"
```

---

### Task 6: Create publish.py

**Files:**
- Create: `publish.py` (repo root)

**Step 1: Write publish.py**

Modeled after `~/source/repos/todo-lists/publish.py` but adapted for this project:

```python
#!/usr/bin/env python3
"""
publish.py - Build and deploy MonstaQuest via Docker Compose.

Usage:
    python publish.py              # Build and run (default)
    python publish.py build        # Build images only
    python publish.py run          # Start existing images
    python publish.py stop         # Stop all containers
    python publish.py logs         # Tail container logs
    python publish.py status       # Show container status
"""

import os
import sys
import subprocess
from pathlib import Path

# Resolve paths
SCRIPT_DIR = Path(__file__).resolve().parent
COMPOSE_FILE = SCRIPT_DIR / "web" / "docker-compose.yml"
REPO_PATH = SCRIPT_DIR

# Colors
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
RED = "\033[0;31m"
RESET = "\033[0m"


def log(msg):
    print(f"{CYAN}[publish]{RESET} {msg}")


def ok(msg):
    print(f"{GREEN}[publish]{RESET} {msg}")


def err(msg):
    print(f"{RED}[publish]{RESET} {msg}", file=sys.stderr)


def compose(*args):
    """Run docker compose with the project compose file and resolved REPO_PATH."""
    env = os.environ.copy()
    env["REPO_PATH"] = str(REPO_PATH)
    cmd = ["docker", "compose", "-f", str(COMPOSE_FILE), *args]
    return subprocess.run(cmd, env=env)


def build_images():
    log("Building images...")
    result = compose("build")
    if result.returncode != 0:
        err("Build failed.")
        sys.exit(result.returncode)
    ok("Images built successfully.")


def run_services():
    log("Starting services...")
    result = compose("up", "-d")
    if result.returncode != 0:
        err("Failed to start services.")
        sys.exit(result.returncode)
    ok("Services running.")
    ok("  App:      http://localhost:8080/monsta-quest")
    ok("  API docs: http://localhost:8080/monsta-quest/docs")


def stop_services():
    log("Stopping services...")
    result = compose("down")
    if result.returncode != 0:
        err("Failed to stop services.")
        sys.exit(result.returncode)
    ok("Services stopped.")


def show_status():
    compose("ps")


def show_logs():
    try:
        compose("logs", "-f")
    except KeyboardInterrupt:
        pass


ACTIONS = {
    "build": build_images,
    "run": run_services,
    "stop": stop_services,
    "logs": show_logs,
    "status": show_status,
}


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "default"

    if action == "default":
        build_images()
        run_services()
    elif action in ACTIONS:
        ACTIONS[action]()
    else:
        err(f"Unknown action: {action}")
        print(f"Usage: {sys.argv[0]} {{build|run|stop|logs|status}}")
        sys.exit(1)


if __name__ == "__main__":
    main()
```

Key differences from todo's publish.py:
- `COMPOSE_FILE` points to `web/docker-compose.yml` (not repo root)
- Sets `REPO_PATH` instead of `REPOS_DIR`
- URLs show port 8080 and `/monsta-quest` path

**Step 2: Make executable**

Run: `chmod +x publish.py`

**Step 3: Test it runs**

Run: `python publish.py status`

Expected: Shows docker compose ps output (may show no containers if none running yet).

**Step 4: Commit**

```bash
git add publish.py
git commit -m "feat: add publish.py deployment script for Docker Compose"
```

---

### Task 7: Docker build smoke test

**Files:** None (verification only)

**Step 1: Ensure cloudflare-tunnel Docker network exists**

Run: `docker network create cloudflare-tunnel 2>/dev/null; echo "ok"`

This is idempotent — creates the network if it doesn't exist, ignores error if it does.

**Step 2: Build with publish.py**

Run: `python publish.py build`

Expected: Multi-stage build succeeds — Node frontend builds, Python backend installs deps.

**Step 3: Run with publish.py**

Run: `python publish.py run`

Expected: Both containers start. Output shows URLs.

**Step 4: Verify subpath routing**

Run: `curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://localhost:8080/`

Expected: `301 http://localhost:8080/monsta-quest/` (root redirects to subpath)

Run: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/monsta-quest/`

Expected: `200` (app loads)

Run: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/monsta-quest/api/health`

Expected: `200` (API accessible through prefix)

**Step 5: Verify frontend assets use correct prefix**

Run: `curl -s http://localhost:8080/monsta-quest/ | grep -o 'src="[^"]*"' | head -3`

Expected: Asset paths start with `/monsta-quest/assets/`

**Step 6: Stop services**

Run: `python publish.py stop`

**Step 7: Commit any fixes if needed**

---

### Task 8: Cloudflare tunnel configuration (manual/guided)

This task requires access to the server and Cloudflare dashboard. No code changes.

**Step 1: Find the cloudflared configuration on the server**

Look for:
- `docker ps | grep cloudflared` — find the running tunnel container
- `docker inspect <container>` — find mounted config
- Common locations: `~/.cloudflared/config.yml`, `/etc/cloudflared/config.yml`
- Or check if tunnel is configured via Cloudflare dashboard (Zero Trust → Networks → Tunnels)

**Step 2: Add rpg.dagordons.com route**

If config file based, add to the ingress rules:
```yaml
- hostname: rpg.dagordons.com
  service: http://monsta-quest-nginx:80
```

If dashboard based:
- Go to Zero Trust → Networks → Tunnels → select tunnel → Public Hostname
- Add hostname: `rpg.dagordons.com`
- Service: `http://monsta-quest-nginx:80`

**Step 3: Add DNS record in Cloudflare**

Dashboard: https://dash.cloudflare.com/e6d9b5bf79091032ab5c249e65782fd0/domains/overview

- Select `dagordons.com` domain
- Add CNAME record: `rpg` → `<tunnel-id>.cfargotunnel.com` (same target as `todo` CNAME)

**Step 4: Verify external access**

Open: `https://rpg.dagordons.com/monsta-quest`

Expected: App loads with Cloudflare Access login gate.

---

## Summary of all modified/created files

| File | Action |
|------|--------|
| `web/nginx.conf` | Modify — subpath routing |
| `web/docker-compose.yml` | Modify — container names |
| `web/frontend/src/api/client.ts` | Modify — export BASE using BASE_URL |
| `web/frontend/src/api/assets.ts` | Modify — use BASE instead of '/api' |
| `web/frontend/src/pages/DataEditor/CreatureList.tsx` | Modify — use BASE |
| `web/frontend/src/pages/DataEditor/CreatureForm.tsx` | Modify — use BASE |
| `web/frontend/vite.config.ts` | Modify — add base path |
| `web/frontend/src/App.tsx` | Modify — add Router basename |
| `publish.py` | Create — deployment script |
