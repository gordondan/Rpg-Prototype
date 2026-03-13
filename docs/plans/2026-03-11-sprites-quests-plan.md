# Creature Sprites & Quest System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add sprite metadata to creatures so thumbnails display in the editor, add a full CRUD quest system with multi-step chains, and add create/delete operations for maps.

**Architecture:** Extend existing FastAPI backend with new Pydantic models, DataService methods, and routers. Extend React frontend with new API modules, editor components, and sidebar routes. Quest data stored as individual JSON files in `data/quests/`. Sprite paths stored as fields in creature JSON.

**Tech Stack:** Python 3.13, FastAPI, Pydantic, React 18, TypeScript, Shadcn/UI, Tailwind CSS

---

## Phase 1: Creature Sprite Metadata

### Task 1: Add Sprite Fields to Creature Schema & Data

**Files:**
- Modify: `web/backend/models/schemas.py`
- Modify: `web/tests/test_schemas.py`

**Step 1: Add sprite fields to Creature model**

In `web/backend/models/schemas.py`, add two optional fields to the `Creature` class after `recruitable`:

```python
    sprite_overworld: str | None = None
    sprite_battle: str | None = None
```

**Step 2: Update schema tests**

In `web/tests/test_schemas.py`, the existing tests should still pass since the fields are optional. Run:

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
source .venv/bin/activate
PYTHONPATH=. pytest tests/test_schemas.py -v
```

Expected: All 6 tests PASS.

**Step 3: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/backend/models/schemas.py
git commit -m "feat: add sprite_overworld and sprite_battle fields to Creature model"
```

---

### Task 2: Auto-Match Sprites Endpoint

**Files:**
- Modify: `web/backend/services/data_service.py`
- Modify: `web/backend/routers/creatures.py`
- Create: `web/tests/test_sprite_matching.py`

**Step 1: Add sprite auto-matching to DataService**

Add this method to `DataService` in `web/backend/services/data_service.py`:

```python
    def auto_match_sprites(self) -> dict[str, dict[str, str | None]]:
        """Scan assets/sprites/creatures/ and fuzzy-match filenames to creature IDs."""
        sprites_dir = self.repo_path / "assets" / "sprites" / "creatures"
        if not sprites_dir.exists():
            return {}

        # Build lookup of normalized filenames
        sprite_files: dict[str, str] = {}
        for f in sprites_dir.glob("*.png"):
            if f.suffix == ".import":
                continue
            sprite_files[f.name] = str(f.relative_to(self.repo_path))

        creatures = self.get_all_creatures()
        matches: dict[str, dict[str, str | None]] = {}

        for creature_id, creature_data in creatures.items():
            name = creature_data.get("name", creature_id)
            overworld = None
            battle = None

            # Try exact battle match: {creature_id}_battle.png
            battle_name = f"{creature_id}_battle.png"
            if battle_name in sprite_files:
                battle = sprite_files[battle_name]

            # Try overworld matches in order of likelihood
            # 1. Name with underscores: Flame_Squire.png
            name_underscore = name.replace(" ", "_") + ".png"
            # 2. Name with spaces: Giant Bat.png
            name_spaces = name + ".png"
            # 3. ID-based: goblin_basic.png or Goblin_Basic.png
            id_based = creature_id + ".png"

            for candidate in [name_underscore, name_spaces, id_based]:
                if candidate in sprite_files:
                    overworld = sprite_files[candidate]
                    break
                # Case-insensitive fallback
                for fname, fpath in sprite_files.items():
                    if fname.lower() == candidate.lower():
                        overworld = fpath
                        break
                if overworld:
                    break

            matches[creature_id] = {"overworld": overworld, "battle": battle}

        return matches

    def apply_sprite_matches(self, matches: dict[str, dict[str, str | None]]) -> int:
        """Apply sprite path matches to creature data files. Returns count of updated creatures."""
        count = 0
        for creature_id, paths in matches.items():
            creature = self.get_creature(creature_id)
            if not creature:
                continue
            changed = False
            if paths.get("overworld") and creature.get("sprite_overworld") != paths["overworld"]:
                creature["sprite_overworld"] = paths["overworld"]
                changed = True
            if paths.get("battle") and creature.get("sprite_battle") != paths["battle"]:
                creature["sprite_battle"] = paths["battle"]
                changed = True
            if changed:
                self.update_creature(creature_id, creature)
                count += 1
        return count
```

**Step 2: Add endpoints to creatures router**

Add to `web/backend/routers/creatures.py`:

```python
@router.get("/auto-match-sprites")
def auto_match_sprites():
    return data_svc.auto_match_sprites()


@router.post("/apply-sprite-matches")
def apply_sprite_matches(body: dict):
    count = data_svc.apply_sprite_matches(body.get("matches", {}))
    return {"status": "applied", "updated_count": count}
```

IMPORTANT: These two routes MUST be defined BEFORE the `/{creature_id}` route, otherwise FastAPI will try to match "auto-match-sprites" as a creature_id.

**Step 3: Write test**

Create `web/tests/test_sprite_matching.py`:

```python
import shutil
from pathlib import Path

import pytest

from backend.services.data_service import DataService

REPO = Path(__file__).parent.parent.parent


@pytest.fixture
def data_service(tmp_path):
    shutil.copytree(REPO / "data", tmp_path / "data")
    sprites_dir = tmp_path / "assets" / "sprites" / "creatures"
    sprites_dir.mkdir(parents=True)
    # Copy a few real sprites
    src = REPO / "assets" / "sprites" / "creatures"
    for name in ["Flame_Squire.png", "flame_squire_battle.png", "Goblin_Basic.png", "goblin_battle.png"]:
        src_file = src / name
        if src_file.exists():
            shutil.copy2(src_file, sprites_dir / name)
    return DataService(repo_path=tmp_path)


def test_auto_match_finds_sprites(data_service):
    matches = data_service.auto_match_sprites()
    assert "flame_squire" in matches
    assert matches["flame_squire"]["battle"] is not None
    assert "battle" in matches["flame_squire"]["battle"]
    assert matches["flame_squire"]["overworld"] is not None


def test_auto_match_goblin(data_service):
    matches = data_service.auto_match_sprites()
    assert "goblin" in matches
    assert matches["goblin"]["battle"] is not None


def test_apply_sprite_matches(data_service):
    matches = data_service.auto_match_sprites()
    count = data_service.apply_sprite_matches(matches)
    assert count >= 2
    # Verify persisted
    creature = data_service.get_creature("flame_squire")
    assert creature["sprite_battle"] is not None
```

**Step 4: Run tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
source .venv/bin/activate
PYTHONPATH=. pytest tests/test_sprite_matching.py -v
```

Expected: All 3 tests PASS.

**Step 5: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/backend/services/data_service.py web/backend/routers/creatures.py web/tests/test_sprite_matching.py
git commit -m "feat: add sprite auto-matching and apply endpoints"
```

---

### Task 3: Frontend Sprite Display

**Files:**
- Modify: `web/frontend/src/api/creatures.ts`
- Modify: `web/frontend/src/pages/DataEditor/CreatureList.tsx`
- Modify: `web/frontend/src/pages/DataEditor/CreatureForm.tsx`

**Step 1: Add sprite fields to Creature TypeScript interface**

In `web/frontend/src/api/creatures.ts`, add to the `Creature` interface:

```typescript
  sprite_overworld?: string
  sprite_battle?: string
```

Add to `creaturesApi`:

```typescript
  autoMatchSprites: () => get<Record<string, { overworld: string | null; battle: string | null }>>('/creatures/auto-match-sprites'),
  applySprites: (matches: Record<string, { overworld: string | null; battle: string | null }>) =>
    post('/creatures/apply-sprite-matches', { matches }),
```

**Step 2: Fix CreatureList.tsx sprite display**

Replace the current broken img src in `CreatureList.tsx` (line 62-69):

```typescript
<img
  src={creature.sprite_battle ? `/api/assets/thumbnail/${creature.sprite_battle}?size=64` : undefined}
  alt={creature.name}
  className="size-8 object-contain"
  onError={(e) => {
    ;(e.target as HTMLImageElement).style.display = 'none'
  }}
/>
```

If `sprite_battle` is null/undefined, show a placeholder icon instead of a broken img.

**Step 3: Fix CreatureForm.tsx sprite display**

Replace the header sprite section in `CreatureForm.tsx` (lines 51-61) to show both overworld and battle sprites using the actual paths:

```typescript
{/* Overworld sprite */}
<div className="flex flex-col items-center gap-1">
  <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
    {form.sprite_overworld ? (
      <img
        src={`/api/assets/thumbnail/${form.sprite_overworld}?size=128`}
        alt={`${form.name} overworld`}
        className="size-20 object-contain"
      />
    ) : (
      <span className="text-xs text-parchment/30">No sprite</span>
    )}
  </div>
  <span className="text-[10px] text-parchment/40">Overworld</span>
</div>

{/* Battle sprite */}
<div className="flex flex-col items-center gap-1">
  <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
    {form.sprite_battle ? (
      <img
        src={`/api/assets/thumbnail/${form.sprite_battle}?size=128`}
        alt={`${form.name} battle`}
        className="size-20 object-contain"
      />
    ) : (
      <span className="text-xs text-parchment/30">No sprite</span>
    )}
  </div>
  <span className="text-[10px] text-parchment/40">Battle</span>
</div>
```

Also add a "Sprites" card section at the bottom of CreatureForm with an "Auto-Match All Sprites" button that calls `creaturesApi.autoMatchSprites()` then `creaturesApi.applySprites(matches)` and shows a toast with the count.

**Step 4: Build and verify**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run build
```

Expected: Build passes with 0 errors.

**Step 5: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/frontend/src/api/creatures.ts web/frontend/src/pages/DataEditor/CreatureList.tsx web/frontend/src/pages/DataEditor/CreatureForm.tsx
git commit -m "feat: display creature sprites using metadata paths with auto-match"
```

---

## Phase 2: Full CRUD for Maps

### Task 4: Map Create & Delete Backend

**Files:**
- Modify: `web/backend/services/data_service.py`
- Modify: `web/backend/routers/maps.py`
- Modify: `web/tests/test_data_service.py`

**Step 1: Add create_map and delete_map to DataService**

Add to `DataService` in `web/backend/services/data_service.py`:

```python
    def create_map(self, map_id: str, map_data: dict) -> bool:
        path = self.data_path / "maps" / f"{map_id}.json"
        if path.exists():
            return False
        path.parent.mkdir(parents=True, exist_ok=True)
        self._write_json(path, map_data)
        return True

    def delete_map(self, map_id: str) -> bool:
        path = self.data_path / "maps" / f"{map_id}.json"
        if not path.exists():
            return False
        path.unlink()
        return True
```

**Step 2: Add endpoints to maps router**

Replace `web/backend/routers/maps.py`:

```python
from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService

router = APIRouter(prefix="/api/maps", tags=["maps"])
data_svc = DataService()


@router.get("/")
def list_maps():
    return data_svc.get_all_maps()


@router.post("/")
def create_map(body: dict):
    map_id = body.pop("id", None)
    if not map_id:
        raise HTTPException(400, "Missing 'id' field")
    if not data_svc.create_map(map_id, body):
        raise HTTPException(409, f"Map '{map_id}' already exists")
    return {"status": "created", "map_id": map_id}


@router.put("/{map_id}")
def update_map(map_id: str, body: dict):
    if not data_svc.update_map(map_id, body):
        raise HTTPException(404, f"Map '{map_id}' not found")
    return {"status": "updated", "map_id": map_id}


@router.delete("/{map_id}")
def delete_map(map_id: str):
    if not data_svc.delete_map(map_id):
        raise HTTPException(404, f"Map '{map_id}' not found")
    return {"status": "deleted", "map_id": map_id}
```

**Step 3: Add tests**

Add to `web/tests/test_data_service.py`:

```python
def test_create_map(data_service):
    result = data_service.create_map("test_map", {"name": "Test", "description": "A test map", "encounters": []})
    assert result is True
    maps = data_service.get_all_maps()
    assert "test_map" in maps


def test_create_map_duplicate(data_service):
    assert data_service.create_map("route_1", {"name": "Dup"}) is False


def test_delete_map(data_service):
    data_service.create_map("to_delete", {"name": "Del", "description": "", "encounters": []})
    assert data_service.delete_map("to_delete") is True
    assert "to_delete" not in data_service.get_all_maps()


def test_delete_map_not_found(data_service):
    assert data_service.delete_map("nonexistent") is False
```

**Step 4: Run tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
source .venv/bin/activate
PYTHONPATH=. pytest tests/test_data_service.py -v
```

Expected: All tests PASS (7 existing + 4 new = 11).

**Step 5: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/backend/services/data_service.py web/backend/routers/maps.py web/tests/test_data_service.py
git commit -m "feat: add create and delete operations for maps"
```

---

### Task 5: Map Create & Delete Frontend

**Files:**
- Modify: `web/frontend/src/api/maps.ts`
- Modify: `web/frontend/src/pages/DataEditor/MapsList.tsx`
- Modify: `web/frontend/src/pages/DataEditor/MapForm.tsx`
- Modify: `web/frontend/src/pages/DataEditor/index.tsx`

**Step 1: Update maps API client**

In `web/frontend/src/api/maps.ts`, add create and delete:

```typescript
import { get, put, post, httpDelete } from './client'

export interface GameMap {
  name: string
  description: string
  encounters: { creature_id: string; level_min: number; level_max: number; weight: number }[]
}

export const mapsApi = {
  list: () => get<Record<string, GameMap>>('/maps/'),
  create: (id: string, data: GameMap) => post<{ status: string; map_id: string }>('/maps/', { id, ...data }),
  update: (id: string, data: GameMap) => put<GameMap>(`/maps/${id}`, data),
  delete: (id: string) => httpDelete<{ status: string }>(`/maps/${id}`),
}
```

**Step 2: Add "New Map" button to MapsList.tsx**

Add a "New Map" button above the search that opens a dialog to enter a map ID, then calls `mapsApi.create()`. The parent `DataEditor/index.tsx` must pass an `onRefresh` callback so the list reloads after creation.

**Step 3: Add delete button to MapForm.tsx**

Add a "Delete Map" button (red, with confirmation dialog) at the bottom of the form. Calls `mapsApi.delete(id)` then triggers list refresh via callback.

**Step 4: Update DataEditor/index.tsx**

Pass `onRefresh={loadData}` and `onDelete` callbacks to MapsList and MapForm. When a map is created, reload data and select the new map. When deleted, reload and clear selection.

**Step 5: Build and verify**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run build
```

Expected: Build passes.

**Step 6: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/frontend/src/api/maps.ts web/frontend/src/pages/DataEditor/
git commit -m "feat: add map create and delete UI with confirmation dialog"
```

---

## Phase 3: Quest System Backend

### Task 6: Quest Pydantic Models

**Files:**
- Modify: `web/backend/models/schemas.py`

**Step 1: Add quest models to schemas.py**

Add after the Shop class:

```python
# --- Quests ---

class QuestReward(BaseModel):
    gold: int = 0
    items: list[str] = []
    exp: int = 0


class QuestStage(BaseModel):
    id: str
    type: str  # talk_to_npc, defeat_creatures, collect_items, reach_location, boss_encounter
    description: str
    npc_id: str | None = None
    dialogue_id: str | None = None
    creature_id: str | None = None
    count: int | None = None
    item_id: str | None = None
    map_id: str | None = None
    level: int | None = None


class Quest(BaseModel):
    name: str
    description: str
    map_id: str
    prerequisite_quest_id: str | None = None
    reward: QuestReward
    stages: list[QuestStage]
```

**Step 2: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/backend/models/schemas.py
git commit -m "feat: add Quest, QuestStage, QuestReward Pydantic models"
```

---

### Task 7: Quest DataService Methods

**Files:**
- Modify: `web/backend/services/data_service.py`
- Create: `web/tests/test_quest_service.py`

**Step 1: Add quest CRUD to DataService**

Add to `DataService`:

```python
    # --- Quests ---

    def get_all_quests(self) -> dict[str, dict]:
        quests = {}
        quests_dir = self.data_path / "quests"
        if quests_dir.exists():
            for f in quests_dir.glob("*.json"):
                quests[f.stem] = self._read_json(f)
        return quests

    def get_quest(self, quest_id: str) -> dict | None:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if path.exists():
            return self._read_json(path)
        return None

    def create_quest(self, quest_id: str, quest_data: dict) -> bool:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if path.exists():
            return False
        path.parent.mkdir(parents=True, exist_ok=True)
        self._write_json(path, quest_data)
        return True

    def update_quest(self, quest_id: str, quest_data: dict) -> bool:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if not path.exists():
            return False
        self._write_json(path, quest_data)
        return True

    def delete_quest(self, quest_id: str) -> bool:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if not path.exists():
            return False
        path.unlink()
        return True
```

**Step 2: Write tests**

Create `web/tests/test_quest_service.py`:

```python
import shutil
from pathlib import Path

import pytest

from backend.services.data_service import DataService

REPO = Path(__file__).parent.parent.parent

SAMPLE_QUEST = {
    "name": "Clear the Road",
    "description": "Help the guard clear goblins.",
    "map_id": "route_1",
    "prerequisite_quest_id": None,
    "reward": {"gold": 500, "items": ["healing_potion"], "exp": 200},
    "stages": [
        {
            "id": "talk_guard",
            "type": "talk_to_npc",
            "description": "Talk to the guard",
            "npc_id": "village_guard",
            "dialogue_id": "quest_start",
        },
        {
            "id": "kill_goblins",
            "type": "defeat_creatures",
            "description": "Defeat 3 goblins",
            "creature_id": "goblin",
            "count": 3,
            "map_id": "route_1",
        },
    ],
}


@pytest.fixture
def data_service(tmp_path):
    shutil.copytree(REPO / "data", tmp_path / "data")
    return DataService(repo_path=tmp_path)


def test_create_quest(data_service):
    assert data_service.create_quest("clear_road", SAMPLE_QUEST) is True
    quest = data_service.get_quest("clear_road")
    assert quest is not None
    assert quest["name"] == "Clear the Road"


def test_create_quest_duplicate(data_service):
    data_service.create_quest("dup", SAMPLE_QUEST)
    assert data_service.create_quest("dup", SAMPLE_QUEST) is False


def test_get_all_quests(data_service):
    data_service.create_quest("q1", SAMPLE_QUEST)
    data_service.create_quest("q2", {**SAMPLE_QUEST, "name": "Quest 2"})
    quests = data_service.get_all_quests()
    assert len(quests) == 2


def test_update_quest(data_service):
    data_service.create_quest("q1", SAMPLE_QUEST)
    updated = {**SAMPLE_QUEST, "name": "Updated Quest"}
    assert data_service.update_quest("q1", updated) is True
    quest = data_service.get_quest("q1")
    assert quest["name"] == "Updated Quest"


def test_update_quest_not_found(data_service):
    assert data_service.update_quest("nonexistent", SAMPLE_QUEST) is False


def test_delete_quest(data_service):
    data_service.create_quest("to_delete", SAMPLE_QUEST)
    assert data_service.delete_quest("to_delete") is True
    assert data_service.get_quest("to_delete") is None


def test_delete_quest_not_found(data_service):
    assert data_service.delete_quest("nonexistent") is False


def test_quest_stages_structure(data_service):
    data_service.create_quest("q1", SAMPLE_QUEST)
    quest = data_service.get_quest("q1")
    assert len(quest["stages"]) == 2
    assert quest["stages"][0]["type"] == "talk_to_npc"
    assert quest["stages"][1]["type"] == "defeat_creatures"
    assert quest["stages"][1]["count"] == 3
```

**Step 3: Run tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
source .venv/bin/activate
PYTHONPATH=. pytest tests/test_quest_service.py -v
```

Expected: All 8 tests PASS.

**Step 4: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/backend/services/data_service.py web/tests/test_quest_service.py
git commit -m "feat: add quest CRUD operations to DataService"
```

---

### Task 8: Quest API Router

**Files:**
- Create: `web/backend/routers/quests.py`
- Modify: `web/backend/app.py`

**Step 1: Create quest router**

Create `web/backend/routers/quests.py`:

```python
from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService

router = APIRouter(prefix="/api/quests", tags=["quests"])
data_svc = DataService()


@router.get("/")
def list_quests():
    return data_svc.get_all_quests()


@router.get("/{quest_id}")
def get_quest(quest_id: str):
    quest = data_svc.get_quest(quest_id)
    if not quest:
        raise HTTPException(404, f"Quest '{quest_id}' not found")
    return quest


@router.post("/")
def create_quest(body: dict):
    quest_id = body.pop("id", None)
    if not quest_id:
        raise HTTPException(400, "Missing 'id' field")
    if not data_svc.create_quest(quest_id, body):
        raise HTTPException(409, f"Quest '{quest_id}' already exists")
    return {"status": "created", "quest_id": quest_id}


@router.put("/{quest_id}")
def update_quest(quest_id: str, body: dict):
    if not data_svc.update_quest(quest_id, body):
        raise HTTPException(404, f"Quest '{quest_id}' not found")
    return {"status": "updated", "quest_id": quest_id}


@router.delete("/{quest_id}")
def delete_quest(quest_id: str):
    if not data_svc.delete_quest(quest_id):
        raise HTTPException(404, f"Quest '{quest_id}' not found")
    return {"status": "deleted", "quest_id": quest_id}
```

**Step 2: Register in app.py**

In `web/backend/app.py`, add to the imports:

```python
from backend.routers import creatures, moves, items, maps, shops, assets, git_ops, quests
```

And add after `app.include_router(git_ops.router)`:

```python
app.include_router(quests.router)
```

**Step 3: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/backend/routers/quests.py web/backend/app.py
git commit -m "feat: add quest API router with full CRUD"
```

---

## Phase 4: Quest Editor Frontend

### Task 9: Quest API Client & Route Setup

**Files:**
- Create: `web/frontend/src/api/quests.ts`
- Modify: `web/frontend/src/components/Sidebar.tsx`
- Modify: `web/frontend/src/context/ChangeContext.tsx`

**Step 1: Create quest API module**

Create `web/frontend/src/api/quests.ts`:

```typescript
import { get, put, post, httpDelete } from './client'

export interface QuestReward {
  gold: number
  items: string[]
  exp: number
}

export interface QuestStage {
  id: string
  type: 'talk_to_npc' | 'defeat_creatures' | 'collect_items' | 'reach_location' | 'boss_encounter'
  description: string
  npc_id?: string
  dialogue_id?: string
  creature_id?: string
  count?: number
  item_id?: string
  map_id?: string
  level?: number
}

export interface Quest {
  name: string
  description: string
  map_id: string
  prerequisite_quest_id?: string | null
  reward: QuestReward
  stages: QuestStage[]
}

export const questsApi = {
  list: () => get<Record<string, Quest>>('/quests/'),
  getOne: (id: string) => get<Quest>(`/quests/${id}`),
  create: (id: string, data: Quest) => post<{ status: string; quest_id: string }>('/quests/', { id, ...data }),
  update: (id: string, data: Quest) => put<Quest>(`/quests/${id}`, data),
  delete: (id: string) => httpDelete<{ status: string }>(`/quests/${id}`),
}
```

**Step 2: Add Quests to Sidebar**

In `web/frontend/src/components/Sidebar.tsx`, add to the `dataEditorLinks` array:

```typescript
  { to: '/editor/quests', label: 'Quests', icon: ScrollText },
```

Add `ScrollText` to the lucide-react import.

**Step 3: Add quests to ChangeContext**

In `web/frontend/src/context/ChangeContext.tsx`:

- Add `'quests'` to the `Change['type']` union: `type: 'creatures' | 'moves' | 'items' | 'maps' | 'shops' | 'quests'`
- Import `questsApi` from `@/api/quests`
- Add a case in `saveAll` switch:
```typescript
case 'quests':
  await questsApi.update(change.id, change.data as Parameters<typeof questsApi.update>[1])
  break
```

**Step 4: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/frontend/src/api/quests.ts web/frontend/src/components/Sidebar.tsx web/frontend/src/context/ChangeContext.tsx
git commit -m "feat: add quest API client, sidebar link, and change tracking"
```

---

### Task 10: Quest List & Form Components

**Files:**
- Create: `web/frontend/src/pages/DataEditor/QuestsList.tsx`
- Create: `web/frontend/src/pages/DataEditor/QuestForm.tsx`
- Modify: `web/frontend/src/pages/DataEditor/index.tsx`

**Step 1: Create QuestsList.tsx**

List of quests with search/filter. Shows quest name, associated map badge, stage count. Has a "New Quest" button that opens a dialog to create a quest (enter ID, name, map_id).

Pattern: Follow `MapsList.tsx` structure. Use `ScrollText` icon from lucide-react. Badge shows stage count. "New Quest" button calls `questsApi.create()`.

**Step 2: Create QuestForm.tsx**

Full quest editor with these sections:

**Identity section:**
- `name` (Input)
- `description` (Textarea)
- `map_id` (Input — or ideally a dropdown populated from mapsApi)
- `prerequisite_quest_id` (Input — dropdown populated from other quest IDs, nullable)

**Reward section** (Card):
- `gold` (number Input)
- `exp` (number Input)
- `items` (list of item ID inputs with add/remove, similar to learnset in CreatureForm)

**Stages section** (Card):
- Ordered list of stages, each in its own sub-card
- Each stage has: `id` (Input), `type` (select dropdown with 5 options), `description` (Input)
- Conditional fields based on type:
  - `talk_to_npc`: `npc_id` (Input), `dialogue_id` (Input)
  - `defeat_creatures`: `creature_id` (Input), `count` (number Input), `map_id` (Input, optional)
  - `collect_items`: `item_id` (Input), `count` (number Input)
  - `reach_location`: `map_id` (Input)
  - `boss_encounter`: `creature_id` (Input), `level` (number Input)
- Add Stage / Remove Stage buttons
- Each stage change calls `markChanged('quests', questId, updatedQuest, questName)`

**Delete section:**
- "Delete Quest" button (red, with confirmation dialog)

Pattern: Follow `MapForm.tsx` and `CreatureForm.tsx` patterns for styling (bg-stone/50, border-stone-light/30, text-parchment, gold headings, etc.)

**Step 3: Wire into DataEditor/index.tsx**

Add quest state, loading, and rendering to `DataEditor/index.tsx`:

- Import `questsApi`, `Quest`, `QuestsList`, `QuestForm`
- Add `quests` state: `const [quests, setQuests] = useState<Record<string, Quest>>({})`
- Add `case 'quests'` to the `loadData` switch
- Add `category === 'quests'` rendering for list and form panels
- Pass `onRefresh={loadData}` callback for create/delete operations

**Step 4: Build and verify**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run build
```

Expected: Build passes with 0 TypeScript errors.

**Step 5: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/frontend/src/pages/DataEditor/
git commit -m "feat: add quest list and form editor with multi-stage support"
```

---

### Task 11: Map Editor — Associated Quests Section

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/MapForm.tsx`

**Step 1: Add associated quests section**

Add a read-only Card at the bottom of `MapForm.tsx` that fetches quests from `questsApi.list()` and displays those whose `map_id` matches the current map:

```typescript
// Inside MapForm, add state and effect:
const [quests, setQuests] = useState<Record<string, Quest>>({})
useEffect(() => {
  questsApi.list().then(setQuests)
}, [])

const associatedQuests = Object.entries(quests).filter(([, q]) => q.map_id === id)
```

Render as a Card with quest names as badges/links. Clicking navigates to `/editor/quests` (user can then select the quest). If no quests, show "No quests for this map."

**Step 2: Build and verify**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run build
```

**Step 3: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/frontend/src/pages/DataEditor/MapForm.tsx
git commit -m "feat: show associated quests in map editor"
```

---

## Phase 5: Integration & Verification

### Task 12: Update Integration Tests

**Files:**
- Modify: `web/tests/test_integration.py`

**Step 1: Add quest and map CRUD integration tests**

Add to `web/tests/test_integration.py`:

```python
def test_create_map(client):
    r = client.post("/api/maps/", json={"id": "test_map", "name": "Test Map", "description": "A test", "encounters": []})
    assert r.status_code == 200
    r = client.get("/api/maps/")
    assert "test_map" in r.json()


def test_delete_map(client):
    client.post("/api/maps/", json={"id": "to_delete", "name": "Del", "description": "", "encounters": []})
    r = client.delete("/api/maps/to_delete")
    assert r.status_code == 200
    assert "to_delete" not in client.get("/api/maps/").json()


def test_quest_crud(client):
    quest_data = {
        "id": "test_quest",
        "name": "Test Quest",
        "description": "A test quest",
        "map_id": "route_1",
        "prerequisite_quest_id": None,
        "reward": {"gold": 100, "items": [], "exp": 50},
        "stages": [
            {"id": "s1", "type": "reach_location", "description": "Go to route 1", "map_id": "route_1"}
        ],
    }
    # Create
    r = client.post("/api/quests/", json=quest_data)
    assert r.status_code == 200

    # Read
    r = client.get("/api/quests/test_quest")
    assert r.status_code == 200
    assert r.json()["name"] == "Test Quest"

    # Update
    updated = r.json()
    updated["name"] = "Updated Quest"
    r = client.put("/api/quests/test_quest", json=updated)
    assert r.status_code == 200

    # Verify update
    r = client.get("/api/quests/test_quest")
    assert r.json()["name"] == "Updated Quest"

    # List
    r = client.get("/api/quests/")
    assert "test_quest" in r.json()

    # Delete
    r = client.delete("/api/quests/test_quest")
    assert r.status_code == 200
    r = client.get("/api/quests/test_quest")
    assert r.status_code == 404


def test_sprite_auto_match(client):
    r = client.get("/api/creatures/auto-match-sprites")
    assert r.status_code == 200
    matches = r.json()
    assert "flame_squire" in matches
```

**Step 2: Update the integration test fixture**

In the `test_repo` fixture, also create a `data/quests` directory and add the quests router service to the `client` fixture:

In the `client` fixture, add:
```python
from backend.routers import quests as quests_router
quests_router.data_svc = data_service.DataService(repo_path=test_repo)
```

**Step 3: Run all tests**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web
source .venv/bin/activate
PYTHONPATH=. pytest tests/ -v
```

Expected: All tests PASS.

**Step 4: Rebuild frontend**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend
npm run build
```

**Step 5: Commit**

```bash
cd /Users/gordon/Documents/Tyrell/monster-game
git add web/tests/test_integration.py
git commit -m "test: add integration tests for quest CRUD, map CRUD, and sprite matching"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-3 | Creature sprite metadata: schema, auto-match, frontend display |
| 2 | 4-5 | Full CRUD for maps: create/delete backend + frontend |
| 3 | 6-8 | Quest system backend: models, DataService, API router |
| 4 | 9-11 | Quest editor frontend: API client, list, form, map integration |
| 5 | 12 | Integration tests and final verification |
