# Docker Deployment Design: rpg.dagordons.com/monsta-quest

**Date:** 2026-03-12
**Status:** Approved

## Goal

Deploy the MonsterQuest web app as a Docker container accessible at `https://rpg.dagordons.com/monsta-quest`, using the same Cloudflare tunnel pattern as `todo.dagordons.com/todo-list`.

Local access at `http://localhost:8080/monsta-quest`.

## Architecture

```
Internet → Cloudflare Tunnel → cloudflared container
                                    ↓ (cloudflare-tunnel Docker network)
                              monsta-quest-nginx:80 (host port 8080)
                                    ↓ (strips /monsta-quest/ prefix)
                              monsta-quest-api:8000
                                    ↓ (mounts repo at /repo)
                              game data files (read/write via git)
```

Same pattern as the todo app (`~/source/repos/todo-lists`):
- Separate `api` + `nginx` Docker services
- nginx joins external `cloudflare-tunnel` network
- nginx strips the subpath prefix before proxying to the API
- API is unaware of the prefix

## Changes Required

### 1. nginx.conf — Subpath routing

Rewrite to serve under `/monsta-quest/`:
- `location /monsta-quest/` → `proxy_pass http://api:8000/` (trailing slash strips prefix)
- `location = /monsta-quest` → redirect to `/monsta-quest/`
- `location /` → redirect to `/monsta-quest/`
- Pass `X-Forwarded-Prefix /monsta-quest` header
- Keep existing: buffering off, 300s timeout, 50MB body size

### 2. docker-compose.yml — Port and naming

- Port mapping: `8080:80` (todo uses `80:80`)
- Container names: `monsta-quest-api`, `monsta-quest-nginx`
- nginx on both `default` and external `cloudflare-tunnel` networks
- Mount repo path via `REPO_PATH` env var (default to current directory)

### 3. Frontend — Subpath awareness

**vite.config.ts:**
- Add `base: '/monsta-quest/'` for production builds
- Dev proxy stays as-is (no prefix in dev)

**App.tsx (React Router):**
- Add `basename="/monsta-quest"` to `<BrowserRouter>`

**api/client.ts:**
- Change `BASE` from `'/api'` to use `import.meta.env.BASE_URL + 'api'`
- In dev: `BASE_URL` is `/` → `BASE` = `/api` (unchanged behavior)
- In prod: `BASE_URL` is `/monsta-quest/` → `BASE` = `/monsta-quest/api`

**api/assets.ts:**
- `thumbnailUrl()` and `fileUrl()` build URLs directly — update to use the same base prefix

### 4. publish.py — Deployment script

New script at repo root, modeled after todo's `publish.py`:
- Commands: `build`, `run`, `stop`, `logs`, `status` (default: build + run)
- Runs `docker compose -f web/docker-compose.yml`
- Sets `REPO_PATH` env var to the repo root

### 5. Cloudflare Tunnel — New route

- Add `rpg.dagordons.com` hostname in cloudflared config
- Point to `monsta-quest-nginx:80` (or `http://nginx:80` using docker-compose service name)
- Dashboard: https://dash.cloudflare.com/e6d9b5bf79091032ab5c249e65782fd0/domains/overview

### 6. Cloudflare Access (deferred)

Separate access policy for rpg.dagordons.com with a different allowed-users list. Can be configured later in Cloudflare Zero Trust dashboard without code changes.

## What stays unchanged

- **Dockerfile** — already correct (multi-stage Node+Python build, port 8000)
- **FastAPI backend** — unaware of prefix; nginx handles stripping
- **.dockerignore** — already appropriate
- **Dev workflow** — `start-web.sh` and Vite dev server unaffected (no prefix in dev)

## Reference: Todo App Pattern

The todo app at `~/source/repos/todo-lists` uses this exact pattern:
- nginx on port 80, strips `/todo-list/` prefix
- `cloudflare-tunnel` external Docker network
- `publish.py` wraps docker compose commands
- cloudflared routes `todo.dagordons.com` → nginx container
