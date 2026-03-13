# Asset Browser/Editor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a web-based asset browser/editor for MonsterQuest at `rpg1.dagordons.com` with data editing, asset management, and gallery features.

**Architecture:** Monolithic FastAPI + React (Vite/TypeScript) app. FastAPI serves the built React SPA and exposes `/api/` routes. All writes go through GitPython for version control. Docker container with nginx reverse proxy connects to existing Cloudflare tunnel.

**Tech Stack:** Python 3.13, FastAPI, GitPython, Pillow (thumbnails), React 18, TypeScript, Vite, Shadcn/UI, Tailwind CSS, Recharts (radar charts), React Router v6

---

## Phase 1: Project Scaffolding & Infrastructure

### Task 1: Create Directory Structure

**Files:**
- Create: `web/backend/__init__.py`
- Create: `web/backend/routers/__init__.py`
- Create: `web/backend/services/__init__.py`
- Create: `web/backend/models/__init__.py`

**Step 1: Create all backend directories**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
mkdir -p web/backend/routers web/backend/services web/backend/models
touch web/backend/__init__.py web/backend/routers/__init__.py web/backend/services/__init__.py web/backend/models/__init__.py
```

**Step 2: Commit**

```bash
git add web/
git commit -m "scaffold: create web app directory structure"
```

---

### Task 2: Backend Requirements & Configuration

**Files:**
- Create: `web/requirements.txt`
- Create: `web/backend/config.py`

**Step 1: Create requirements.txt**

```
fastapi>=0.115.0
uvicorn[standard]>=0.30.0
pydantic>=2.0.0
python-multipart>=0.0.9
GitPython>=3.1.40
Pillow>=10.0.0
```

**Step 2: Create config.py**

```python
from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    repo_path: Path = Path("/repo")
    data_dir: str = "data"
    assets_dir: str = "assets"
    metadata_file: str = "web/asset_metadata.json"
    git_author_name: str = "RPG Asset Browser"
    git_author_email: str = "rpg-browser@dagordons.com"

    @property
    def data_path(self) -> Path:
        return self.repo_path / self.data_dir

    @property
    def assets_path(self) -> Path:
        return self.repo_path / self.assets_dir

    @property
    def metadata_path(self) -> Path:
        return self.repo_path / self.metadata_file


settings = Settings()
```

**Step 3: Commit**

```bash
git add web/requirements.txt web/backend/config.py
git commit -m "scaffold: add backend requirements and config"
```

---

### Task 3: FastAPI Application Entry Point

**Files:**
- Create: `web/backend/app.py`

**Step 1: Create app.py**

```python
import argparse
from pathlib import Path

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

app = FastAPI(title="MonsterQuest Asset Browser", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health():
    return {"status": "ok"}


# Serve React build if it exists
frontend_build = Path(__file__).parent.parent / "frontend" / "dist"
if frontend_build.exists():
    app.mount("/", StaticFiles(directory=str(frontend_build), html=True), name="frontend")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    uvicorn.run("app:app", host=args.host, port=args.port, reload=True)
```

**Step 2: Test it runs**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/backend
pip install -r ../requirements.txt
python app.py &
curl http://localhost:8000/api/health
# Expected: {"status":"ok"}
kill %1
```

**Step 3: Commit**

```bash
git add web/backend/app.py
git commit -m "scaffold: add FastAPI entry point with health check"
```

---

### Task 4: React Frontend Scaffold

**Files:**
- Create: `web/frontend/` (via Vite scaffold)
- Modify: `web/frontend/vite.config.ts`

**Step 1: Scaffold React + TypeScript with Vite**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
npm create vite@latest frontend -- --template react-ts
cd frontend
npm install
```

**Step 2: Configure Vite proxy for API**

Replace `web/frontend/vite.config.ts`:

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
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

**Step 3: Verify frontend runs**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run dev &
# Verify http://localhost:5173 loads
kill %1
```

**Step 4: Commit**

```bash
git add web/frontend/
git commit -m "scaffold: add React + TypeScript frontend with Vite"
```

---

### Task 5: Install Shadcn/UI + Tailwind

**Files:**
- Modify: `web/frontend/package.json`
- Create: `web/frontend/components.json`
- Create: `web/frontend/src/lib/utils.ts`
- Modify: `web/frontend/tailwind.config.js`

**Step 1: Install Tailwind CSS**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm install -D tailwindcss @tailwindcss/vite
```

Add Tailwind plugin to `vite.config.ts`:

```typescript
import tailwindcss from '@tailwindcss/vite'
// add tailwindcss() to plugins array
```

Replace `src/index.css` with:

```css
@import "tailwindcss";
```

**Step 2: Initialize Shadcn/UI**

```bash
npx shadcn@latest init
```

Choose: TypeScript, Default style, Slate base color, CSS variables.

**Step 3: Install needed Shadcn components**

```bash
npx shadcn@latest add button input label select textarea card tabs table badge dialog dropdown-menu separator scroll-area toast sheet popover command slider
```

**Step 4: Commit**

```bash
git add web/frontend/
git commit -m "scaffold: add Tailwind CSS and Shadcn/UI components"
```

---

### Task 6: Docker & Nginx Setup

**Files:**
- Create: `web/Dockerfile`
- Create: `web/docker-compose.yml`
- Create: `web/nginx.conf`
- Create: `web/.dockerignore`

**Step 1: Create Dockerfile**

```dockerfile
FROM node:20-slim AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM python:3.13-slim
WORKDIR /app

# Install git for GitPython
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/
COPY --from=frontend-build /app/frontend/dist ./frontend/dist

EXPOSE 8000

WORKDIR /app/backend
CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "8000"]
```

**Step 2: Create docker-compose.yml**

```yaml
services:
  api:
    build: .
    volumes:
      - ${REPO_PATH:-/Users/gordon/Documents/Tyrell/monster-game}:/repo
    environment:
      - REPO_PATH=/repo
    restart: unless-stopped

  nginx:
    image: nginx:alpine
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

**Step 3: Create nginx.conf**

```nginx
server {
    listen 80;
    server_name _;

    client_max_body_size 50M;

    location / {
        proxy_pass http://api:8000/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
    }
}
```

**Step 4: Create .dockerignore**

```
frontend/node_modules
frontend/.git
__pycache__
*.pyc
.env
.vscode
.git
```

**Step 5: Commit**

```bash
git add web/Dockerfile web/docker-compose.yml web/nginx.conf web/.dockerignore
git commit -m "scaffold: add Docker and nginx configuration"
```

---

## Phase 2: Backend Core Services

### Task 7: Pydantic Models for Game Data

**Files:**
- Create: `web/backend/models/schemas.py`

**Step 1: Create schemas matching exact JSON structures**

Reference files:
- `data/creatures/starters.json` — creatures without recruit fields
- `data/creatures/wild.json` — creatures with recruit_method, recruit_chance, recruit_dialogue
- `data/moves/moves.json` — moves with optional effect/effect_chance/priority
- `data/items/items.json` — items with effect object
- `data/maps/route_1.json` — map with name, description, encounters[]
- `data/shops/shops.json` — shops with name, greeting, items[]

```python
from __future__ import annotations

from pydantic import BaseModel, Field


# --- Creatures ---

class LearnsetEntry(BaseModel):
    level: int
    move_id: str


class Evolution(BaseModel):
    creature_id: str
    level: int
    flavor: str


class Creature(BaseModel):
    name: str
    description: str
    types: list[str]
    base_hp: int
    base_attack: int
    base_defense: int
    base_sp_attack: int
    base_sp_defense: int
    base_speed: int
    base_exp: int
    class_: str = Field(alias="class")
    evolution: Evolution | None = None
    recruit_method: str | None = None
    recruit_chance: float | None = None
    recruit_dialogue: str | None = None
    learnset: list[LearnsetEntry] = []

    model_config = {"populate_by_name": True}


# --- Moves ---

class MoveEffect(BaseModel):
    stat: str | None = None
    stages: int | None = None
    target: str | None = None
    status: str | None = None


class Move(BaseModel):
    name: str
    type: str
    category: str  # physical, special, status
    power: int
    accuracy: int
    pp: int
    description: str
    effect: MoveEffect | None = None
    effect_chance: int | None = None
    priority: int | None = None


# --- Items ---

class ItemEffect(BaseModel):
    type: str
    amount: int | None = None


class Item(BaseModel):
    name: str
    description: str
    price: int
    effect: ItemEffect


# --- Maps ---

class Encounter(BaseModel):
    creature_id: str
    level_min: int
    level_max: int
    weight: int


class GameMap(BaseModel):
    name: str
    description: str
    encounters: list[Encounter]


# --- Shops ---

class Shop(BaseModel):
    name: str
    greeting: str
    items: list[str]


# --- Dialogue ---

class DialogueChoice(BaseModel):
    text: str
    id: str
    next: list[DialogueLine] = []


class DialogueLine(BaseModel):
    text: str
    speaker: str
    choices: list[DialogueChoice] | None = None


class NPC(BaseModel):
    name: str
    sprite: str
    lines: list[DialogueLine]


# Rebuild for forward references
DialogueChoice.model_rebuild()


# --- Asset Metadata ---

class AssetMeta(BaseModel):
    status: str = "active"  # active, in_development, deprecated, unused
    notes: str = ""
```

**Step 2: Write test for schema validation**

Create `web/tests/__init__.py` and `web/tests/test_schemas.py`:

```python
import json
from pathlib import Path

from backend.models.schemas import Creature, Move, Item, GameMap, Shop

REPO = Path(__file__).parent.parent.parent  # monster-game root


def test_creature_schema_matches_starters():
    data = json.loads((REPO / "data/creatures/starters.json").read_text())
    for cid, cdata in data.items():
        creature = Creature.model_validate(cdata)
        assert creature.name
        assert creature.evolution is not None


def test_creature_schema_matches_wild():
    data = json.loads((REPO / "data/creatures/wild.json").read_text())
    for cid, cdata in data.items():
        creature = Creature.model_validate(cdata)
        assert creature.recruit_method is not None


def test_move_schema():
    data = json.loads((REPO / "data/moves/moves.json").read_text())
    for mid, mdata in data.items():
        move = Move.model_validate(mdata)
        assert move.name


def test_item_schema():
    data = json.loads((REPO / "data/items/items.json").read_text())
    for iid, idata in data.items():
        item = Item.model_validate(idata)
        assert item.price >= 0


def test_map_schema():
    data = json.loads((REPO / "data/maps/route_1.json").read_text())
    game_map = GameMap.model_validate(data)
    assert len(game_map.encounters) > 0


def test_shop_schema():
    data = json.loads((REPO / "data/shops/shops.json").read_text())
    for sid, sdata in data.items():
        shop = Shop.model_validate(sdata)
        assert len(shop.items) > 0
```

**Step 3: Run tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
pip install pytest
PYTHONPATH=. pytest tests/test_schemas.py -v
```

Expected: All 6 tests PASS.

**Step 4: Commit**

```bash
git add web/backend/models/schemas.py web/tests/
git commit -m "feat: add Pydantic models matching all game data schemas"
```

---

### Task 8: Data Service

**Files:**
- Create: `web/backend/services/data_service.py`
- Create: `web/tests/test_data_service.py`

**Step 1: Create data_service.py**

This service reads/writes JSON data files. It handles the creature split (starters.json vs wild.json) and provides a unified API.

```python
import json
from pathlib import Path

from backend.config import settings
from backend.models.schemas import Creature, Move, Item, GameMap, Shop


class DataService:
    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path
        self.data_path = self.repo_path / settings.data_dir

    def _read_json(self, path: Path) -> dict:
        return json.loads(path.read_text())

    def _write_json(self, path: Path, data: dict) -> None:
        path.write_text(json.dumps(data, indent=2) + "\n")

    # --- Creatures ---

    def get_all_creatures(self) -> dict[str, dict]:
        creatures = {}
        starters_path = self.data_path / "creatures" / "starters.json"
        wild_path = self.data_path / "creatures" / "wild.json"
        if starters_path.exists():
            creatures.update(self._read_json(starters_path))
        if wild_path.exists():
            creatures.update(self._read_json(wild_path))
        return creatures

    def get_creature(self, creature_id: str) -> dict | None:
        all_creatures = self.get_all_creatures()
        return all_creatures.get(creature_id)

    def _find_creature_file(self, creature_id: str) -> Path | None:
        for filename in ["starters.json", "wild.json"]:
            path = self.data_path / "creatures" / filename
            if path.exists():
                data = self._read_json(path)
                if creature_id in data:
                    return path
        return None

    def update_creature(self, creature_id: str, creature_data: dict) -> bool:
        path = self._find_creature_file(creature_id)
        if not path:
            return False
        data = self._read_json(path)
        data[creature_id] = creature_data
        self._write_json(path, data)
        return True

    # --- Moves ---

    def get_all_moves(self) -> dict[str, dict]:
        path = self.data_path / "moves" / "moves.json"
        return self._read_json(path) if path.exists() else {}

    def get_move(self, move_id: str) -> dict | None:
        return self.get_all_moves().get(move_id)

    def update_move(self, move_id: str, move_data: dict) -> bool:
        path = self.data_path / "moves" / "moves.json"
        data = self._read_json(path)
        data[move_id] = move_data
        self._write_json(path, data)
        return True

    # --- Items ---

    def get_all_items(self) -> dict[str, dict]:
        path = self.data_path / "items" / "items.json"
        return self._read_json(path) if path.exists() else {}

    def update_item(self, item_id: str, item_data: dict) -> bool:
        path = self.data_path / "items" / "items.json"
        data = self._read_json(path)
        data[item_id] = item_data
        self._write_json(path, data)
        return True

    # --- Maps ---

    def get_all_maps(self) -> dict[str, dict]:
        maps = {}
        maps_dir = self.data_path / "maps"
        if maps_dir.exists():
            for f in maps_dir.glob("*.json"):
                maps[f.stem] = self._read_json(f)
        return maps

    def update_map(self, map_id: str, map_data: dict) -> bool:
        path = self.data_path / "maps" / f"{map_id}.json"
        if not path.exists():
            return False
        self._write_json(path, map_data)
        return True

    # --- Shops ---

    def get_all_shops(self) -> dict[str, dict]:
        path = self.data_path / "shops" / "shops.json"
        return self._read_json(path) if path.exists() else {}

    def update_shop(self, shop_id: str, shop_data: dict) -> bool:
        path = self.data_path / "shops" / "shops.json"
        data = self._read_json(path)
        data[shop_id] = shop_data
        self._write_json(path, data)
        return True

    def get_changed_files(self) -> list[str]:
        """Return list of data files modified relative to repo path."""
        changed = []
        for pattern in ["creatures/*.json", "moves/*.json", "items/*.json", "maps/*.json", "shops/*.json"]:
            for f in (self.data_path).glob(pattern):
                changed.append(str(f.relative_to(self.repo_path)))
        return changed
```

**Step 2: Write tests**

```python
# web/tests/test_data_service.py
import json
import tempfile
import shutil
from pathlib import Path

import pytest

from backend.services.data_service import DataService

REPO = Path(__file__).parent.parent.parent


@pytest.fixture
def data_service(tmp_path):
    """Copy real data to temp dir for isolated testing."""
    data_dest = tmp_path / "data"
    shutil.copytree(REPO / "data", data_dest)
    return DataService(repo_path=tmp_path)


def test_get_all_creatures(data_service):
    creatures = data_service.get_all_creatures()
    assert "flame_squire" in creatures
    assert "spark_thief" in creatures
    assert len(creatures) > 10


def test_get_creature(data_service):
    c = data_service.get_creature("flame_squire")
    assert c is not None
    assert c["name"] == "Flame Squire"


def test_update_creature(data_service):
    c = data_service.get_creature("flame_squire")
    c["base_hp"] = 999
    data_service.update_creature("flame_squire", c)
    updated = data_service.get_creature("flame_squire")
    assert updated["base_hp"] == 999


def test_get_all_moves(data_service):
    moves = data_service.get_all_moves()
    assert "sword_strike" in moves


def test_get_all_items(data_service):
    items = data_service.get_all_items()
    assert "healing_potion" in items


def test_get_all_maps(data_service):
    maps = data_service.get_all_maps()
    assert "route_1" in maps
    assert maps["route_1"]["name"] == "The King's Road"


def test_get_all_shops(data_service):
    shops = data_service.get_all_shops()
    assert "village_merchant" in shops
```

**Step 3: Run tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
PYTHONPATH=. pytest tests/test_data_service.py -v
```

Expected: All 7 tests PASS.

**Step 4: Commit**

```bash
git add web/backend/services/data_service.py web/tests/test_data_service.py
git commit -m "feat: add data service for reading/writing game JSON files"
```

---

### Task 9: Git Service

**Files:**
- Create: `web/backend/services/git_service.py`
- Create: `web/tests/test_git_service.py`

**Step 1: Create git_service.py**

```python
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from git import Repo, Actor

from backend.config import settings


@dataclass
class CommitInfo:
    sha: str
    message: str
    author: str
    date: str
    files: list[str]


class GitService:
    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path
        self._repo: Repo | None = None

    @property
    def repo(self) -> Repo:
        if self._repo is None:
            self._repo = Repo(self.repo_path)
        return self._repo

    @property
    def author(self) -> Actor:
        return Actor(settings.git_author_name, settings.git_author_email)

    def has_changes(self) -> bool:
        return self.repo.is_dirty(untracked_files=True)

    def get_changed_files(self) -> list[str]:
        changed = []
        diff = self.repo.index.diff(None)
        for d in diff:
            changed.append(d.a_path)
        for f in self.repo.untracked_files:
            changed.append(f)
        # Also check staged
        if self.repo.head.is_valid():
            staged = self.repo.index.diff("HEAD")
            for d in staged:
                if d.a_path not in changed:
                    changed.append(d.a_path)
        return changed

    def stage_and_commit(self, files: list[str], message: str) -> str:
        for f in files:
            self.repo.index.add([f])
        commit = self.repo.index.commit(message, author=self.author, committer=self.author)
        return commit.hexsha

    def stage_all_and_commit(self, message: str) -> str:
        self.repo.git.add(A=True)
        commit = self.repo.index.commit(message, author=self.author, committer=self.author)
        return commit.hexsha

    def get_history(self, max_count: int = 50) -> list[CommitInfo]:
        commits = []
        for c in self.repo.iter_commits(max_count=max_count):
            files = list(c.stats.files.keys()) if c.stats.files else []
            commits.append(CommitInfo(
                sha=c.hexsha,
                message=c.message.strip(),
                author=str(c.author),
                date=datetime.fromtimestamp(c.committed_date).isoformat(),
                files=files,
            ))
        return commits

    def get_diff(self, sha: str | None = None) -> str:
        if sha:
            commit = self.repo.commit(sha)
            if commit.parents:
                return self.repo.git.diff(commit.parents[0].hexsha, sha)
            return self.repo.git.diff(sha, "--root")
        return self.repo.git.diff()

    def revert_commit(self, sha: str) -> str:
        self.repo.git.revert(sha, no_edit=True)
        return self.repo.head.commit.hexsha
```

**Step 2: Write tests**

```python
# web/tests/test_git_service.py
import os
from pathlib import Path

import pytest
from git import Repo

from backend.services.git_service import GitService


@pytest.fixture
def git_service(tmp_path):
    """Create a fresh git repo for testing."""
    repo = Repo.init(tmp_path)
    # Initial commit
    readme = tmp_path / "README.md"
    readme.write_text("test repo")
    repo.index.add(["README.md"])
    repo.index.commit("initial commit")
    return GitService(repo_path=tmp_path)


def test_has_no_changes(git_service):
    assert not git_service.has_changes()


def test_has_changes_after_edit(git_service):
    (git_service.repo_path / "README.md").write_text("modified")
    assert git_service.has_changes()


def test_stage_and_commit(git_service):
    new_file = git_service.repo_path / "test.txt"
    new_file.write_text("hello")
    sha = git_service.stage_and_commit(["test.txt"], "add test file")
    assert len(sha) == 40
    assert not git_service.has_changes()


def test_get_history(git_service):
    history = git_service.get_history()
    assert len(history) == 1
    assert history[0].message == "initial commit"


def test_get_diff(git_service):
    (git_service.repo_path / "README.md").write_text("changed")
    diff = git_service.get_diff()
    assert "changed" in diff
```

**Step 3: Run tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
PYTHONPATH=. pytest tests/test_git_service.py -v
```

Expected: All 5 tests PASS.

**Step 4: Commit**

```bash
git add web/backend/services/git_service.py web/tests/test_git_service.py
git commit -m "feat: add git service for version-controlled writes"
```

---

### Task 10: Asset Service

**Files:**
- Create: `web/backend/services/asset_service.py`
- Create: `web/tests/test_asset_service.py`

**Step 1: Create asset_service.py**

```python
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from backend.config import settings


@dataclass
class AssetInfo:
    path: str  # relative to repo root
    filename: str
    category: str  # creatures, npcs, tilesets, audio
    size_bytes: int
    width: int | None = None
    height: int | None = None
    status: str = "active"
    notes: str = ""


class AssetService:
    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path
        self.assets_path = self.repo_path / settings.assets_dir

    def _get_metadata(self) -> dict:
        meta_path = self.repo_path / settings.metadata_file
        if meta_path.exists():
            return json.loads(meta_path.read_text())
        return {}

    def _save_metadata(self, metadata: dict) -> None:
        meta_path = self.repo_path / settings.metadata_file
        meta_path.parent.mkdir(parents=True, exist_ok=True)
        meta_path.write_text(json.dumps(metadata, indent=2) + "\n")

    def get_asset_status(self, rel_path: str) -> dict:
        metadata = self._get_metadata()
        return metadata.get(rel_path, {"status": "active", "notes": ""})

    def set_asset_status(self, rel_path: str, status: str, notes: str = "") -> None:
        metadata = self._get_metadata()
        metadata[rel_path] = {"status": status, "notes": notes}
        self._save_metadata(metadata)

    def list_assets(self, category: str | None = None) -> list[AssetInfo]:
        assets = []
        sprite_dirs = {
            "creatures": self.assets_path / "sprites" / "creatures",
            "npcs": self.assets_path / "sprites" / "npcs",
            "tilesets": self.assets_path / "sprites" / "tilesets",
        }
        audio_dir = self.assets_path / "audio"

        metadata = self._get_metadata()

        dirs_to_scan = {}
        if category:
            if category == "audio":
                dirs_to_scan["audio"] = audio_dir
            elif category in sprite_dirs:
                dirs_to_scan[category] = sprite_dirs[category]
        else:
            dirs_to_scan = {**sprite_dirs, "audio": audio_dir}

        for cat, dir_path in dirs_to_scan.items():
            if not dir_path.exists():
                continue
            for f in sorted(dir_path.rglob("*")):
                if f.is_dir() or f.suffix == ".import":
                    continue
                rel = str(f.relative_to(self.repo_path))
                meta = metadata.get(rel, {})
                info = AssetInfo(
                    path=rel,
                    filename=f.name,
                    category=cat,
                    size_bytes=f.stat().st_size,
                    status=meta.get("status", "active"),
                    notes=meta.get("notes", ""),
                )
                if f.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                    try:
                        with Image.open(f) as img:
                            info.width, info.height = img.size
                    except Exception:
                        pass
                assets.append(info)
        return assets

    def get_thumbnail(self, rel_path: str, max_size: int = 128) -> bytes | None:
        full_path = self.repo_path / rel_path
        if not full_path.exists():
            return None
        try:
            with Image.open(full_path) as img:
                img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
                from io import BytesIO
                buf = BytesIO()
                img.save(buf, format="PNG")
                return buf.getvalue()
        except Exception:
            return None

    def save_uploaded_file(self, rel_path: str, content: bytes) -> None:
        full_path = self.repo_path / rel_path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_bytes(content)

    def delete_asset(self, rel_path: str) -> bool:
        full_path = self.repo_path / rel_path
        if full_path.exists():
            full_path.unlink()
            # Also remove from metadata
            metadata = self._get_metadata()
            metadata.pop(rel_path, None)
            self._save_metadata(metadata)
            return True
        return False

    def rename_asset(self, old_rel_path: str, new_rel_path: str) -> bool:
        old_path = self.repo_path / old_rel_path
        new_path = self.repo_path / new_rel_path
        if not old_path.exists() or new_path.exists():
            return False
        new_path.parent.mkdir(parents=True, exist_ok=True)
        old_path.rename(new_path)
        # Update metadata
        metadata = self._get_metadata()
        if old_rel_path in metadata:
            metadata[new_rel_path] = metadata.pop(old_rel_path)
            self._save_metadata(metadata)
        return True

    def get_status_summary(self) -> dict[str, int]:
        metadata = self._get_metadata()
        summary = {"active": 0, "in_development": 0, "deprecated": 0, "unused": 0, "missing_sprites": 0}
        assets = self.list_assets("creatures")
        for a in assets:
            status = metadata.get(a.path, {}).get("status", "active")
            if status in summary:
                summary[status] += 1
        return summary
```

**Step 2: Write basic tests**

```python
# web/tests/test_asset_service.py
import shutil
from pathlib import Path

import pytest

from backend.services.asset_service import AssetService

REPO = Path(__file__).parent.parent.parent


@pytest.fixture
def asset_service(tmp_path):
    """Copy real assets to temp dir for testing."""
    assets_dest = tmp_path / "assets" / "sprites" / "creatures"
    assets_dest.mkdir(parents=True)
    # Copy just a few small battle sprites
    src = REPO / "assets" / "sprites" / "creatures"
    for f in list(src.glob("*_battle.png"))[:3]:
        shutil.copy2(f, assets_dest / f.name)
    (tmp_path / "web").mkdir()
    return AssetService(repo_path=tmp_path)


def test_list_assets(asset_service):
    assets = asset_service.list_assets("creatures")
    assert len(assets) >= 1
    assert all(a.category == "creatures" for a in assets)


def test_set_and_get_status(asset_service):
    asset_service.set_asset_status("assets/sprites/creatures/test.png", "deprecated", "old art")
    meta = asset_service.get_asset_status("assets/sprites/creatures/test.png")
    assert meta["status"] == "deprecated"
    assert meta["notes"] == "old art"
```

**Step 3: Run tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
PYTHONPATH=. pytest tests/test_asset_service.py -v
```

Expected: All tests PASS.

**Step 4: Commit**

```bash
git add web/backend/services/asset_service.py web/tests/test_asset_service.py
git commit -m "feat: add asset service for file operations and metadata"
```

---

## Phase 3: API Routers

### Task 11: Creatures Router

**Files:**
- Create: `web/backend/routers/creatures.py`
- Modify: `web/backend/app.py` (register router)

**Step 1: Create creatures.py**

```python
from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService
from backend.services.git_service import GitService

router = APIRouter(prefix="/api/creatures", tags=["creatures"])
data_svc = DataService()
git_svc = GitService()


@router.get("/")
def list_creatures():
    return data_svc.get_all_creatures()


@router.get("/{creature_id}")
def get_creature(creature_id: str):
    creature = data_svc.get_creature(creature_id)
    if not creature:
        raise HTTPException(404, f"Creature '{creature_id}' not found")
    return creature


@router.put("/{creature_id}")
def update_creature(creature_id: str, body: dict):
    if not data_svc.get_creature(creature_id):
        raise HTTPException(404, f"Creature '{creature_id}' not found")
    data_svc.update_creature(creature_id, body)
    return {"status": "updated", "creature_id": creature_id}
```

**Step 2: Register router in app.py**

Add to `web/backend/app.py` after the health endpoint:

```python
from backend.routers import creatures
app.include_router(creatures.router)
```

**Step 3: Commit**

```bash
git add web/backend/routers/creatures.py web/backend/app.py
git commit -m "feat: add creatures API router"
```

---

### Task 12: Moves, Items, Maps, Shops Routers

**Files:**
- Create: `web/backend/routers/moves.py`
- Create: `web/backend/routers/items.py`
- Create: `web/backend/routers/maps.py`
- Create: `web/backend/routers/shops.py`
- Modify: `web/backend/app.py` (register all routers)

**Step 1: Create each router**

All follow the same pattern as creatures. Key differences:

`moves.py`: prefix `/api/moves`, uses `get_all_moves()`, `get_move()`, `update_move()`
`items.py`: prefix `/api/items`, uses `get_all_items()`, `update_item()`
`maps.py`: prefix `/api/maps`, uses `get_all_maps()`, `update_map()`
`shops.py`: prefix `/api/shops`, uses `get_all_shops()`, `update_shop()`

**Step 2: Register all routers in app.py**

```python
from backend.routers import creatures, moves, items, maps, shops
app.include_router(creatures.router)
app.include_router(moves.router)
app.include_router(items.router)
app.include_router(maps.router)
app.include_router(shops.router)
```

**Step 3: Commit**

```bash
git add web/backend/routers/ web/backend/app.py
git commit -m "feat: add moves, items, maps, shops API routers"
```

---

### Task 13: Assets Router

**Files:**
- Create: `web/backend/routers/assets.py`
- Modify: `web/backend/app.py`

**Step 1: Create assets.py**

```python
from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import Response

from backend.services.asset_service import AssetService
from backend.services.git_service import GitService

router = APIRouter(prefix="/api/assets", tags=["assets"])
asset_svc = AssetService()
git_svc = GitService()


@router.get("/")
def list_assets(category: str | None = None):
    assets = asset_svc.list_assets(category)
    return [a.__dict__ for a in assets]


@router.get("/summary")
def get_summary():
    return asset_svc.get_status_summary()


@router.get("/thumbnail/{path:path}")
def get_thumbnail(path: str, size: int = 128):
    data = asset_svc.get_thumbnail(path, size)
    if not data:
        raise HTTPException(404, "Asset not found or not an image")
    return Response(content=data, media_type="image/png")


@router.get("/file/{path:path}")
def get_file(path: str):
    full_path = asset_svc.repo_path / path
    if not full_path.exists():
        raise HTTPException(404, "File not found")
    suffix = full_path.suffix.lower()
    media_types = {
        ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".webp": "image/webp", ".mp3": "audio/mpeg", ".ogg": "audio/ogg",
    }
    return Response(
        content=full_path.read_bytes(),
        media_type=media_types.get(suffix, "application/octet-stream"),
    )


@router.post("/upload/{path:path}")
async def upload_asset(path: str, file: UploadFile = File(...)):
    content = await file.read()
    asset_svc.save_uploaded_file(path, content)
    return {"status": "uploaded", "path": path}


@router.put("/status/{path:path}")
def update_status(path: str, body: dict):
    asset_svc.set_asset_status(path, body["status"], body.get("notes", ""))
    return {"status": "updated"}


@router.delete("/{path:path}")
def delete_asset(path: str):
    if not asset_svc.delete_asset(path):
        raise HTTPException(404, "Asset not found")
    return {"status": "deleted"}


@router.post("/rename")
def rename_asset(body: dict):
    if not asset_svc.rename_asset(body["old_path"], body["new_path"]):
        raise HTTPException(400, "Rename failed (source missing or destination exists)")
    return {"status": "renamed"}
```

**Step 2: Register in app.py**

```python
from backend.routers import assets
app.include_router(assets.router)
```

**Step 3: Commit**

```bash
git add web/backend/routers/assets.py web/backend/app.py
git commit -m "feat: add assets API router with upload, thumbnail, metadata"
```

---

### Task 14: Git Operations Router

**Files:**
- Create: `web/backend/routers/git_ops.py`
- Modify: `web/backend/app.py`

**Step 1: Create git_ops.py**

```python
from fastapi import APIRouter, HTTPException

from backend.services.git_service import GitService

router = APIRouter(prefix="/api/git", tags=["git"])
git_svc = GitService()


@router.get("/status")
def get_status():
    return {
        "has_changes": git_svc.has_changes(),
        "changed_files": git_svc.get_changed_files(),
    }


@router.post("/commit")
def commit_changes(body: dict):
    message = body.get("message", "Update via asset browser")
    if not git_svc.has_changes():
        raise HTTPException(400, "No changes to commit")
    sha = git_svc.stage_all_and_commit(message)
    return {"status": "committed", "sha": sha}


@router.get("/history")
def get_history(limit: int = 50):
    commits = git_svc.get_history(max_count=limit)
    return [c.__dict__ for c in commits]


@router.get("/diff")
def get_diff(sha: str | None = None):
    return {"diff": git_svc.get_diff(sha)}


@router.post("/revert/{sha}")
def revert_commit(sha: str):
    try:
        new_sha = git_svc.revert_commit(sha)
        return {"status": "reverted", "new_sha": new_sha}
    except Exception as e:
        raise HTTPException(400, f"Revert failed: {e}")
```

**Step 2: Register in app.py**

```python
from backend.routers import git_ops
app.include_router(git_ops.router)
```

**Step 3: Commit**

```bash
git add web/backend/routers/git_ops.py web/backend/app.py
git commit -m "feat: add git operations router (status, commit, history, revert)"
```

---

## Phase 4: Frontend Foundation

### Task 15: Fantasy Theme Setup

**Files:**
- Create: `web/frontend/src/theme/colors.ts`
- Modify: `web/frontend/src/index.css`

**Step 1: Define the fantasy color palette and type colors**

`web/frontend/src/theme/colors.ts`:

```typescript
export const TYPE_COLORS: Record<string, string> = {
  fire: '#e25822',
  water: '#3b82f6',
  electric: '#eab308',
  rock: '#92400e',
  flying: '#7dd3fc',
  nature: '#22c55e',
  dark: '#6b21a8',
  normal: '#9ca3af',
  poison: '#a855f7',
  ice: '#67e8f9',
}

export const STAT_LABELS: Record<string, string> = {
  base_hp: 'HP',
  base_attack: 'ATK',
  base_defense: 'DEF',
  base_sp_attack: 'SP.ATK',
  base_sp_defense: 'SP.DEF',
  base_speed: 'SPD',
}
```

**Step 2: Add fantasy fonts and theme overrides to index.css**

Add Google Fonts import for Cinzel (headings) and Inter (body) at the top of `index.css`:

```css
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Inter:wght@300;400;500;600&display=swap');
@import "tailwindcss";

@theme {
  --font-heading: 'Cinzel', serif;
  --font-sans: 'Inter', sans-serif;
  --color-parchment: #f5f0e8;
  --color-dark-slate: #1e1b2e;
  --color-gold: #c9a84c;
  --color-gold-dim: #8b7635;
  --color-stone: #2a2540;
  --color-stone-light: #3d3655;
}
```

**Step 3: Commit**

```bash
git add web/frontend/src/theme/ web/frontend/src/index.css
git commit -m "feat: add fantasy theme with Cinzel font and type colors"
```

---

### Task 16: App Layout & Routing

**Files:**
- Modify: `web/frontend/src/App.tsx`
- Create: `web/frontend/src/components/Layout.tsx`
- Create: `web/frontend/src/components/Sidebar.tsx`
- Create: `web/frontend/src/components/ChangeBar.tsx`
- Create: `web/frontend/src/pages/DataEditor/index.tsx`
- Create: `web/frontend/src/pages/AssetManager/index.tsx`
- Create: `web/frontend/src/pages/Gallery/index.tsx`

**Step 1: Install React Router**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm install react-router-dom
```

**Step 2: Create Layout component**

The layout has:
- Collapsible sidebar on the left with nav links
- Main content area with breadcrumbs
- Persistent bottom ChangeBar showing unsaved changes count

**Step 3: Create Sidebar component**

Navigation links: Data Editor (with sub-items: Creatures, Moves, Items, Maps, Shops), Asset Manager, Gallery. Fantasy-styled with Cinzel headings and subtle parchment texture background.

**Step 4: Create ChangeBar component**

Persistent bottom bar. Shows: "[N] unsaved changes" with Save button (calls POST /api/git/commit) and Discard button. History button opens a slide-out panel.

**Step 5: Create placeholder pages**

Each page (`DataEditor/index.tsx`, `AssetManager/index.tsx`, `Gallery/index.tsx`) starts as a simple placeholder with the page title.

**Step 6: Wire up App.tsx with routes**

```typescript
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import DataEditor from './pages/DataEditor'
import AssetManager from './pages/AssetManager'
import Gallery from './pages/Gallery'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<Navigate to="/editor/creatures" replace />} />
          <Route path="/editor/:category" element={<DataEditor />} />
          <Route path="/assets/*" element={<AssetManager />} />
          <Route path="/gallery" element={<Gallery />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
```

**Step 7: Verify the app renders with sidebar and routing**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run dev
# Navigate to http://localhost:5173 — should see sidebar + placeholder content
```

**Step 8: Commit**

```bash
git add web/frontend/
git commit -m "feat: add app layout with sidebar navigation and routing"
```

---

### Task 17: API Client Layer

**Files:**
- Create: `web/frontend/src/api/client.ts`
- Create: `web/frontend/src/api/creatures.ts`
- Create: `web/frontend/src/api/moves.ts`
- Create: `web/frontend/src/api/items.ts`
- Create: `web/frontend/src/api/maps.ts`
- Create: `web/frontend/src/api/shops.ts`
- Create: `web/frontend/src/api/assets.ts`
- Create: `web/frontend/src/api/git.ts`

**Step 1: Create base client**

```typescript
// web/frontend/src/api/client.ts
const BASE = '/api'

export async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`)
  if (!res.ok) throw new Error(`GET ${path}: ${res.status}`)
  return res.json()
}

export async function put<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`PUT ${path}: ${res.status}`)
  return res.json()
}

export async function post<T>(path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  })
  if (!res.ok) throw new Error(`POST ${path}: ${res.status}`)
  return res.json()
}

export async function del<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`DELETE ${path}: ${res.status}`)
  return res.json()
}
```

**Step 2: Create typed API modules**

Each module wraps the base client with typed functions. Example for creatures:

```typescript
// web/frontend/src/api/creatures.ts
import { get, put } from './client'

export interface Creature {
  name: string
  description: string
  types: string[]
  base_hp: number
  base_attack: number
  base_defense: number
  base_sp_attack: number
  base_sp_defense: number
  base_speed: number
  base_exp: number
  class: string
  evolution?: { creature_id: string; level: number; flavor: string }
  recruit_method?: string
  recruit_chance?: number
  recruit_dialogue?: string
  learnset: { level: number; move_id: string }[]
}

export const creaturesApi = {
  list: () => get<Record<string, Creature>>('/creatures/'),
  getOne: (id: string) => get<Creature>(`/creatures/${id}`),
  update: (id: string, data: Creature) => put(`/creatures/${id}`, data),
}
```

Follow same pattern for moves, items, maps, shops, assets, git.

**Step 3: Commit**

```bash
git add web/frontend/src/api/
git commit -m "feat: add typed API client layer for all endpoints"
```

---

### Task 18: Change Tracking Context

**Files:**
- Create: `web/frontend/src/context/ChangeContext.tsx`

**Step 1: Create React context for tracking dirty state**

This context:
- Tracks which entities have been modified (Map of entity type + id → modified data)
- Provides `markChanged(type, id, data)` and `discardAll()` functions
- Provides `saveAll()` which calls the update APIs for each changed entity, then calls POST /api/git/commit
- Provides `changeCount` for the ChangeBar
- Polls GET /api/git/status periodically to stay in sync

```typescript
// web/frontend/src/context/ChangeContext.tsx
import { createContext, useContext, useState, useCallback, ReactNode } from 'react'
import { gitApi } from '@/api/git'

interface Change {
  type: string // "creature", "move", "item", "map", "shop"
  id: string
  data: unknown
  label: string // human-readable like "Flame Squire stats"
}

interface ChangeContextType {
  changes: Map<string, Change>
  changeCount: number
  markChanged: (type: string, id: string, data: unknown, label: string) => void
  discardAll: () => void
  saveAll: () => Promise<void>
  isSaving: boolean
}

const ChangeContext = createContext<ChangeContextType | null>(null)

export function useChanges() {
  const ctx = useContext(ChangeContext)
  if (!ctx) throw new Error('useChanges must be inside ChangeProvider')
  return ctx
}

export function ChangeProvider({ children }: { children: ReactNode }) {
  // Implementation: useState for changes map, save calls update APIs then git commit
}
```

**Step 2: Wrap App in ChangeProvider**

**Step 3: Commit**

```bash
git add web/frontend/src/context/
git commit -m "feat: add change tracking context for dirty state management"
```

---

## Phase 5: Data Editor UI

### Task 19: Creatures List View

**Files:**
- Create: `web/frontend/src/pages/DataEditor/CreatureList.tsx`
- Modify: `web/frontend/src/pages/DataEditor/index.tsx`

**Step 1: Build creature list component**

Left panel showing all creatures. Features:
- Fetches from `creaturesApi.list()` on mount
- Search input filters by name
- Each row shows: thumbnail (from `/api/assets/thumbnail/...`), name, type badges (colored per TYPE_COLORS)
- Clicking a creature sets selectedCreatureId (passed to detail view)
- Starters and wild are visually grouped with section headers

**Step 2: Wire into DataEditor page**

DataEditor renders a split layout: CreatureList on left (300px), detail form on right.

**Step 3: Commit**

```bash
git add web/frontend/src/pages/DataEditor/
git commit -m "feat: add creature list view with search and type badges"
```

---

### Task 20: Creature Detail Form — Identity & Stats

**Files:**
- Create: `web/frontend/src/pages/DataEditor/CreatureForm.tsx`
- Create: `web/frontend/src/components/RadarChart.tsx`

**Step 1: Install Recharts**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm install recharts
```

**Step 2: Create RadarChart component**

Uses Recharts `<RadarChart>` to display the 6 base stats. Each stat is a spoke: HP, ATK, DEF, SP.ATK, SP.DEF, SPD. Max value 100. Updates live as the user edits stat inputs.

**Step 3: Create CreatureForm component**

Sections:
- **Identity**: name (Input), description (Textarea), class (Select: warrior, cleric, rogue, mage, monster, guardian), types (multi-select dropdown)
- **Base Stats**: 6 numeric inputs (base_hp through base_speed) + base_exp, with RadarChart beside them
- Each field onChange calls `useChanges().markChanged("creature", creatureId, updatedData, label)`
- Modified fields get a subtle blue-left-border highlight

**Step 4: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureForm.tsx web/frontend/src/components/RadarChart.tsx
git commit -m "feat: add creature form with identity, stats, and radar chart"
```

---

### Task 21: Creature Detail Form — Learnset, Evolution, Recruitment

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureForm.tsx`

**Step 1: Add Learnset section**

Table with columns: Level (number input), Move (searchable Command/Combobox populated from movesApi.list()). Add Row / Remove Row buttons. Rows sorted by level.

**Step 2: Add Evolution section**

Optional (toggle to show/hide). Fields: creature_id (searchable dropdown from all creature IDs), level (number input), flavor (Textarea).

**Step 3: Add Recruitment section**

Only shown for wild creatures (has recruit_method). Fields: method (Select: defeat), chance (Slider 0-1 with percentage display), dialogue (Textarea).

**Step 4: Add Sprites preview section**

Show thumbnails for overworld (`assets/sprites/creatures/{Name}.png`) and battle (`assets/sprites/creatures/{id}_battle.png`). "View in Asset Manager" link for each.

**Step 5: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureForm.tsx
git commit -m "feat: add learnset, evolution, recruitment, and sprite preview to creature form"
```

---

### Task 22: Moves Editor

**Files:**
- Create: `web/frontend/src/pages/DataEditor/MovesList.tsx`
- Create: `web/frontend/src/pages/DataEditor/MoveForm.tsx`
- Modify: `web/frontend/src/pages/DataEditor/index.tsx`

**Step 1: Build MovesList**

Same list pattern as CreatureList. Shows: name, type badge, category (physical/special/status icon), power.

**Step 2: Build MoveForm**

Fields:
- name (Input), type (Select with all game types), category (Select: physical/special/status)
- power (number), accuracy (number), pp (number)
- description (Textarea)
- effect_chance (number, optional)
- effect (conditional sub-form): stat (Select), stages (number), target (Select: enemy/self), or status (Select: burn/poison/etc.)
- priority (number, optional, default 0)

**Step 3: Wire into DataEditor**

DataEditor switches between creature/move/item/map/shop views based on the `:category` route param.

**Step 4: Commit**

```bash
git add web/frontend/src/pages/DataEditor/
git commit -m "feat: add moves editor with list and detail form"
```

---

### Task 23: Items, Maps, Shops Editors

**Files:**
- Create: `web/frontend/src/pages/DataEditor/ItemsList.tsx`
- Create: `web/frontend/src/pages/DataEditor/ItemForm.tsx`
- Create: `web/frontend/src/pages/DataEditor/MapsList.tsx`
- Create: `web/frontend/src/pages/DataEditor/MapForm.tsx`
- Create: `web/frontend/src/pages/DataEditor/ShopsList.tsx`
- Create: `web/frontend/src/pages/DataEditor/ShopForm.tsx`

**Step 1: Items editor**

List: name, price, effect type. Form: name, description, price, effect.type (Select: heal_hp/full_heal/revive), effect.amount (number, conditional).

**Step 2: Maps editor**

List: map name, encounter count. Form: name, description, encounters table (creature_id dropdown, level_min, level_max, weight). Add/remove encounter rows. Weights shown as percentages.

**Step 3: Shops editor**

List: shop name, item count. Form: name, greeting, items (multi-select from all item IDs with drag-to-reorder).

**Step 4: Commit**

```bash
git add web/frontend/src/pages/DataEditor/
git commit -m "feat: add items, maps, and shops editors"
```

---

### Task 24: Change Bar & History Panel

**Files:**
- Modify: `web/frontend/src/components/ChangeBar.tsx`
- Create: `web/frontend/src/components/HistoryPanel.tsx`

**Step 1: Implement ChangeBar**

- Fixed to bottom of viewport
- Shows: change count badge, list of changed entities as pills (e.g., "Flame Squire", "Fire Bolt")
- Save button: calls `saveAll()` from ChangeContext, shows loading spinner, then toast on success
- Discard button: calls `discardAll()` with confirmation dialog
- History button (clock icon): opens HistoryPanel as a Sheet (Shadcn slide-out)

**Step 2: Implement HistoryPanel**

- Fetches from GET /api/git/history
- Shows list of commits: message, date (relative like "2 hours ago"), file count
- Click a commit to expand and show the diff (from GET /api/git/diff?sha=xxx)
- Revert button per commit (calls POST /api/git/revert/{sha} with confirmation)

**Step 3: Add toast notifications**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
# Toast is already installed via Shadcn, just wire it up
```

**Step 4: Commit**

```bash
git add web/frontend/src/components/
git commit -m "feat: add change bar with save/discard and history panel"
```

---

## Phase 6: Asset Manager UI

### Task 25: Asset Manager Layout & Navigation

**Files:**
- Modify: `web/frontend/src/pages/AssetManager/index.tsx`
- Create: `web/frontend/src/pages/AssetManager/DashboardBar.tsx`
- Create: `web/frontend/src/pages/AssetManager/AssetGrid.tsx`

**Step 1: Build DashboardBar**

Top bar with summary chips from GET /api/assets/summary. Chips: Active (green), In Development (yellow), Deprecated (orange), Unused (gray), Missing Sprites (red). Each chip is clickable to filter. "Needs Attention" count displayed prominently.

**Step 2: Build AssetGrid**

Grid of category folders: Creatures, NPCs, Tilesets, Audio. Each folder card shows category icon and asset count. Clicking navigates to `/assets/creatures`, `/assets/npcs`, etc.

**Step 3: Build category sub-views**

When at `/assets/creatures`, show the creature cards grid (Task 26). Other categories show simple file grids.

**Step 4: Commit**

```bash
git add web/frontend/src/pages/AssetManager/
git commit -m "feat: add asset manager layout with dashboard bar and category navigation"
```

---

### Task 26: Creature Asset Cards

**Files:**
- Create: `web/frontend/src/pages/AssetManager/CreatureCards.tsx`
- Create: `web/frontend/src/pages/AssetManager/AssetDetailModal.tsx`

**Step 1: Build CreatureCards**

For each creature (from creatures API):
- Card showing overworld + battle sprite thumbnails side by side
- Status badge (from asset metadata): color-coded
- Border color: green (both sprites), yellow (one missing), red (none)
- Naming issue badge if filename contains typos
- Status dropdown to change active/in-dev/deprecated/unused
- Click sprite to open AssetDetailModal

**Step 2: Build AssetDetailModal**

Shadcn Dialog showing:
- Full-size sprite
- File info: dimensions, size, repo path
- Replace button (file picker)
- Rename button (inline edit)
- Delete button (with confirmation)

**Step 3: Commit**

```bash
git add web/frontend/src/pages/AssetManager/
git commit -m "feat: add creature asset cards with status indicators and detail modal"
```

---

### Task 27: File Upload & Drag-and-Drop

**Files:**
- Create: `web/frontend/src/components/DropZone.tsx`
- Modify: `web/frontend/src/pages/AssetManager/CreatureCards.tsx`

**Step 1: Build DropZone component**

Reusable drag-and-drop zone. Accepts file drops, shows hover state, calls onDrop callback with files. Also has a click-to-browse fallback.

**Step 2: Add bulk upload to AssetManager**

DropZone at the top of creature cards view. Dropped files are auto-matched to creatures by filename pattern (e.g., `flame_squire_battle.png` → flame_squire battle sprite). Unmatched files prompt user to assign.

**Step 3: Upload calls POST /api/assets/upload/{path} then POST /api/git/commit**

**Step 4: Commit**

```bash
git add web/frontend/src/components/DropZone.tsx web/frontend/src/pages/AssetManager/
git commit -m "feat: add drag-and-drop file upload with auto-matching"
```

---

### Task 28: Filtering & Sorting

**Files:**
- Modify: `web/frontend/src/pages/AssetManager/index.tsx`

**Step 1: Add filter bar**

Below dashboard bar. Filter controls:
- Status dropdown (All, Active, In Development, Deprecated, Unused)
- Type dropdown (All, + each creature type)
- Completeness (All, Has Both Sprites, Missing Overworld, Missing Battle)
- Sort dropdown (Name, Status, File Size, Last Modified)

**Step 2: Persist filter state in URL search params**

Use `useSearchParams()` from React Router so filters survive navigation.

**Step 3: Commit**

```bash
git add web/frontend/src/pages/AssetManager/
git commit -m "feat: add filtering and sorting to asset manager"
```

---

## Phase 7: Gallery

### Task 29: Gallery Grid View

**Files:**
- Modify: `web/frontend/src/pages/Gallery/index.tsx`
- Create: `web/frontend/src/pages/Gallery/Lightbox.tsx`

**Step 1: Build Gallery grid**

- Category tabs at top: Creatures, NPCs, Tilesets, Audio
- Grid of large thumbnails (loaded from /api/assets/thumbnail/{path}?size=256)
- Search bar filters by filename
- Lazy loading for performance (IntersectionObserver)

**Step 2: Build Lightbox**

Click any thumbnail to open full-size view in a Dialog. Shows:
- Full-size image (from /api/assets/file/{path})
- Metadata overlay: filename, dimensions, file size, status, associated creature/NPC name
- Previous/Next navigation arrows
- Close on Escape or click outside

**Step 3: Commit**

```bash
git add web/frontend/src/pages/Gallery/
git commit -m "feat: add gallery with grid view and lightbox"
```

---

### Task 30: Side-by-Side Compare

**Files:**
- Create: `web/frontend/src/pages/Gallery/CompareView.tsx`
- Modify: `web/frontend/src/pages/Gallery/index.tsx`

**Step 1: Build CompareView**

- User selects two sprites (checkbox on gallery items)
- Compare button opens side-by-side view
- Both sprites displayed at same scale
- Metadata shown below each

**Step 2: Wire into Gallery**

Add selection mode toggle and Compare button to gallery toolbar.

**Step 3: Commit**

```bash
git add web/frontend/src/pages/Gallery/
git commit -m "feat: add side-by-side sprite comparison in gallery"
```

---

## Phase 8: Integration & Deployment

### Task 31: End-to-End Integration Test

**Files:**
- Create: `web/tests/test_integration.py`

**Step 1: Write integration test**

Uses FastAPI TestClient to test the full API flow:
- GET /api/creatures/ returns all creatures
- GET /api/creatures/flame_squire returns correct data
- PUT /api/creatures/flame_squire updates and persists
- GET /api/assets/?category=creatures returns asset list
- GET /api/git/status returns clean/dirty state
- POST /api/git/commit creates a commit

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
pip install httpx  # needed for TestClient
PYTHONPATH=. pytest tests/test_integration.py -v
```

**Step 2: Commit**

```bash
git add web/tests/test_integration.py
git commit -m "test: add end-to-end API integration tests"
```

---

### Task 32: Build & Test Docker

**Step 1: Build the frontend**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run build
```

**Step 2: Build and run Docker container**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
docker compose build
docker compose up -d
```

**Step 3: Verify**

```bash
curl http://localhost:8080/api/health
# Expected: {"status":"ok"}

curl http://localhost:8080/api/creatures/ | head -c 200
# Expected: JSON with creature data

# Open http://localhost:8080 in browser — should see React app
```

**Step 4: Fix any issues and commit**

```bash
git add web/
git commit -m "build: verify Docker build and deployment"
```

---

### Task 33: Cloudflare Tunnel Configuration

**Step 1: Add rpg1.dagordons.com route to Cloudflare tunnel**

This is done in the Cloudflare dashboard or via `cloudflared` CLI:
- Add a public hostname: `rpg1.dagordons.com`
- Point to: `http://rpg1-nginx-1:80` (the nginx container on the cloudflare-tunnel network)

**Step 2: Add Google OAuth protection**

Configure in Cloudflare Zero Trust (same as todo.dagordons.com):
- Add application: rpg1.dagordons.com
- Auth policy: allow specific Google accounts

**Step 3: Verify**

```bash
# From browser, navigate to https://rpg1.dagordons.com
# Should prompt Google login, then show the asset browser
```

**Step 4: Commit any config changes**

```bash
git add web/
git commit -m "deploy: configure rpg1.dagordons.com via Cloudflare tunnel"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-6 | Project scaffolding: dirs, backend, frontend, Docker |
| 2 | 7-10 | Core services: schemas, data, git, assets |
| 3 | 11-14 | API routers: creatures, moves, items, maps, shops, assets, git |
| 4 | 15-18 | Frontend foundation: theme, layout, routing, API client, change tracking |
| 5 | 19-24 | Data Editor UI: creature list/form, moves, items, maps, shops, change bar |
| 6 | 25-28 | Asset Manager UI: dashboard, cards, upload, filtering |
| 7 | 29-30 | Gallery: grid, lightbox, compare |
| 8 | 31-33 | Integration tests, Docker build, Cloudflare deployment |
