# Creature Filters & Quick Create — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Consolidate creature data into a single file, add filter/search UI to the creatures list, and add a quick-create button.

**Architecture:** Merge `starters.json` + `wild.json` into `creatures.json` with a `category` field. Simplify backend to single-file CRUD. Add collapsible filter panel and quick-create button to `CreatureList.tsx`.

**Tech Stack:** Python/FastAPI backend, React/TypeScript frontend, Godot GDScript game engine.

---

### Task 1: Merge creature data files

**Important context:** `starters.json` and `wild.json` have 3 duplicate IDs (`flame_squire`, `grove_druid`, `tide_cleric`) — these are distinct creatures with different stats/descriptions. The wild versions currently shadow the starter versions in the API. We must disambiguate them before merging.

**Files:**
- Read: `data/creatures/starters.json`, `data/creatures/wild.json`
- Create: `data/creatures/creatures.json`
- Delete: `data/creatures/starters.json`, `data/creatures/wild.json`

**Step 1: Write a one-time Python merge script**

Create `scripts/merge_creatures.py`:

```python
#!/usr/bin/env python3
"""One-time script to merge starters.json and wild.json into creatures.json."""
import json
from pathlib import Path

data_dir = Path(__file__).parent.parent / "data" / "creatures"
starters = json.loads((data_dir / "starters.json").read_text())
wild = json.loads((data_dir / "wild.json").read_text())

merged = {}

# Add starters with category
for cid, cdata in starters.items():
    cdata["category"] = "starter"
    merged[cid] = cdata

# Add wild creatures with category, renaming duplicates
renames = {}
for cid, cdata in wild.items():
    cdata["category"] = "wild"
    if cid in merged:
        new_id = f"{cid}_wild"
        renames[cid] = new_id
        merged[new_id] = cdata
        print(f"RENAMED: {cid} -> {new_id} (duplicate in starters)")
    else:
        merged[cid] = cdata

(data_dir / "creatures.json").write_text(json.dumps(merged, indent=2) + "\n")
print(f"Wrote {len(merged)} creatures to creatures.json")
if renames:
    print(f"Renames: {renames}")
    print("TODO: Update any map encounter references to these IDs")
```

**Step 2: Run the merge script**

Run: `python scripts/merge_creatures.py`
Expected: Creates `data/creatures/creatures.json` with all creatures, printing rename info for duplicates.

**Step 3: Verify the merged file**

Run: `python -c "import json; d=json.loads(open('data/creatures/creatures.json').read()); print(f'{len(d)} creatures'); assert all('category' in v for v in d.values()); print('All have category field')"`
Expected: "21 creatures" (7 starters + 14 wild, with 3 duplicates renamed), "All have category field"

**Step 4: Check if any map encounters reference the renamed IDs**

Run: `grep -r "flame_squire\|grove_druid\|tide_cleric" data/maps/`

If any map encounters reference these IDs, they refer to the wild versions (since wild.json took priority in the API). Update those references to use the `_wild` suffix.

**Step 5: Delete old files and merge script**

```bash
rm data/creatures/starters.json data/creatures/wild.json scripts/merge_creatures.py
```

**Step 6: Commit**

```bash
git add data/creatures/
git commit -m "data: consolidate creature files into creatures.json with category field"
```

---

### Task 2: Add `category` to Creature schema

**Files:**
- Modify: `web/backend/models/schemas.py:19-38`

**Step 1: Add category field to Creature model**

In `web/backend/models/schemas.py`, add `category` field to the `Creature` class:

```python
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
    category: str = "wild"
    evolution: Evolution | None = None
    recruit_method: str | None = None
    recruit_chance: float | None = None
    recruit_dialogue: str | None = None
    recruitable: bool | None = None
    learnset: list[LearnsetEntry] = []

    model_config = {"populate_by_name": True}
```

**Step 2: Add category to TypeScript interface**

In `web/frontend/src/api/creatures.ts`, add `category` to the `Creature` interface:

```typescript
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
  category: string
  evolution?: { creature_id: string; level: number; flavor: string }
  recruit_method?: string
  recruit_chance?: number
  recruit_dialogue?: string
  learnset: { level: number; move_id: string }[]
}
```

**Step 3: Commit**

```bash
git add web/backend/models/schemas.py web/frontend/src/api/creatures.ts
git commit -m "feat: add category field to Creature schema"
```

---

### Task 3: Simplify backend DataService for single creature file

**Files:**
- Modify: `web/backend/services/data_service.py:19-52`

**Step 1: Rewrite creature methods in DataService**

Replace the creature section of `data_service.py` (lines 19-52) with:

```python
# --- Creatures ---

def _creatures_path(self) -> Path:
    return self.data_path / "creatures" / "creatures.json"

def get_all_creatures(self) -> dict[str, dict]:
    path = self._creatures_path()
    return self._read_json(path) if path.exists() else {}

def get_creature(self, creature_id: str) -> dict | None:
    return self.get_all_creatures().get(creature_id)

def update_creature(self, creature_id: str, creature_data: dict) -> bool:
    path = self._creatures_path()
    data = self._read_json(path)
    if creature_id not in data:
        return False
    data[creature_id] = creature_data
    self._write_json(path, data)
    return True

def create_creature(self, creature_id: str, creature_data: dict) -> bool:
    path = self._creatures_path()
    data = self._read_json(path) if path.exists() else {}
    if creature_id in data:
        return False
    data[creature_id] = creature_data
    self._write_json(path, data)
    return True

def delete_creature(self, creature_id: str) -> bool:
    path = self._creatures_path()
    data = self._read_json(path)
    if creature_id not in data:
        return False
    del data[creature_id]
    self._write_json(path, data)
    return True
```

The `_find_creature_file` method is removed entirely.

**Step 2: Run existing tests to verify**

Run: `cd web && python -m pytest tests/test_data_service.py -v`
Expected: All tests pass (the fixture copies the whole data dir, which now has `creatures.json`).

**Step 3: Commit**

```bash
git add web/backend/services/data_service.py
git commit -m "refactor: simplify DataService to use single creatures.json"
```

---

### Task 4: Add POST and DELETE creature endpoints

**Files:**
- Modify: `web/backend/routers/creatures.py`

**Step 1: Write failing test for POST endpoint**

Add to `web/tests/test_integration.py`:

```python
def test_create_creature(client):
    r = client.post("/api/creatures/")
    assert r.status_code == 200
    data = r.json()
    assert "creature_id" in data
    creature_id = data["creature_id"]
    # Verify it exists
    r = client.get(f"/api/creatures/{creature_id}")
    assert r.status_code == 200
    assert r.json()["name"] == "New Creature"
    assert r.json()["category"] == "wild"


def test_delete_creature(client):
    # Create one first
    r = client.post("/api/creatures/")
    creature_id = r.json()["creature_id"]
    # Delete it
    r = client.delete(f"/api/creatures/{creature_id}")
    assert r.status_code == 200
    # Verify gone
    r = client.get(f"/api/creatures/{creature_id}")
    assert r.status_code == 404
```

**Step 2: Run test to verify it fails**

Run: `cd web && python -m pytest tests/test_integration.py::test_create_creature -v`
Expected: FAIL (405 Method Not Allowed — no POST route)

**Step 3: Implement POST and DELETE endpoints**

Replace `web/backend/routers/creatures.py` with:

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


@router.post("/")
def create_creature():
    all_creatures = data_svc.get_all_creatures()
    # Generate unique ID
    n = 1
    while f"new_creature_{n}" in all_creatures:
        n += 1
    creature_id = f"new_creature_{n}"

    creature_data = {
        "name": "New Creature",
        "description": "",
        "types": ["normal"],
        "base_hp": 50,
        "base_attack": 50,
        "base_defense": 50,
        "base_sp_attack": 50,
        "base_sp_defense": 50,
        "base_speed": 50,
        "base_exp": 50,
        "class": "monster",
        "category": "wild",
        "learnset": [],
    }
    data_svc.create_creature(creature_id, creature_data)
    return {"status": "created", "creature_id": creature_id}


@router.delete("/{creature_id}")
def delete_creature(creature_id: str):
    if not data_svc.delete_creature(creature_id):
        raise HTTPException(404, f"Creature '{creature_id}' not found")
    return {"status": "deleted", "creature_id": creature_id}
```

**Step 4: Run tests to verify they pass**

Run: `cd web && python -m pytest tests/test_integration.py::test_create_creature tests/test_integration.py::test_delete_creature -v`
Expected: PASS

**Step 5: Commit**

```bash
git add web/backend/routers/creatures.py web/tests/test_integration.py
git commit -m "feat: add POST/DELETE endpoints for creatures"
```

---

### Task 5: Update tests for consolidated creature file

**Files:**
- Modify: `web/tests/test_schemas.py:9-21`
- Modify: `web/tests/test_data_service.py`

**Step 1: Update schema tests**

Replace the two creature tests in `web/tests/test_schemas.py` with:

```python
def test_creature_schema():
    data = json.loads((REPO / "data/creatures/creatures.json").read_text())
    for cid, cdata in data.items():
        creature = Creature.model_validate(cdata)
        assert creature.name
        assert cdata["category"] in ("starter", "wild")
```

**Step 2: Add DataService tests for create/delete**

Add to `web/tests/test_data_service.py`:

```python
def test_create_creature(data_service):
    result = data_service.create_creature("test_creature", {
        "name": "Test", "description": "", "types": ["normal"],
        "base_hp": 1, "base_attack": 1, "base_defense": 1,
        "base_sp_attack": 1, "base_sp_defense": 1, "base_speed": 1,
        "base_exp": 1, "class": "monster", "category": "wild", "learnset": [],
    })
    assert result is True
    assert "test_creature" in data_service.get_all_creatures()


def test_create_creature_duplicate(data_service):
    assert data_service.create_creature("flame_squire", {"name": "Dup"}) is False


def test_delete_creature(data_service):
    data_service.create_creature("to_delete", {
        "name": "Del", "description": "", "types": ["normal"],
        "base_hp": 1, "base_attack": 1, "base_defense": 1,
        "base_sp_attack": 1, "base_sp_defense": 1, "base_speed": 1,
        "base_exp": 1, "class": "monster", "category": "wild", "learnset": [],
    })
    assert data_service.delete_creature("to_delete") is True
    assert "to_delete" not in data_service.get_all_creatures()


def test_delete_creature_not_found(data_service):
    assert data_service.delete_creature("nonexistent") is False
```

**Step 3: Run all tests**

Run: `cd web && python -m pytest tests/ -v`
Expected: All pass

**Step 4: Commit**

```bash
git add web/tests/test_schemas.py web/tests/test_data_service.py
git commit -m "test: update tests for consolidated creature file and CRUD"
```

---

### Task 6: Update Godot data loader

**Files:**
- Modify: `scripts/autoload/data_loader.gd:17-19`

**Step 1: Update _load_all_data to use single file**

Replace lines 18-19 of `scripts/autoload/data_loader.gd`:

```gdscript
# Before:
_load_creatures("res://data/creatures/starters.json")
_load_creatures("res://data/creatures/wild.json")

# After:
_load_creatures("res://data/creatures/creatures.json")
```

The `_load_creatures` function already calls `_creatures.merge(data)` which handles a flat dict of creatures. The `category` field is just another field in the dict — Godot will load it fine and ignore it where not needed.

**Step 2: Commit**

```bash
git add scripts/autoload/data_loader.gd
git commit -m "refactor: update Godot data loader for consolidated creatures.json"
```

---

### Task 7: Add `create` to frontend creatures API

**Files:**
- Modify: `web/frontend/src/api/creatures.ts`

**Step 1: Add create and delete methods**

Update the `creaturesApi` object in `web/frontend/src/api/creatures.ts`:

```typescript
import { get, put, post, httpDelete } from './client'

// ... (Creature interface stays the same)

export const creaturesApi = {
  list: () => get<Record<string, Creature>>('/creatures/'),
  getOne: (id: string) => get<Creature>(`/creatures/${id}`),
  update: (id: string, data: Creature) => put<Creature>(`/creatures/${id}`, data),
  create: () => post<{ status: string; creature_id: string }>('/creatures/'),
  delete: (id: string) => httpDelete<{ status: string }>(`/creatures/${id}`),
}
```

**Step 2: Commit**

```bash
git add web/frontend/src/api/creatures.ts
git commit -m "feat: add create/delete to frontend creatures API"
```

---

### Task 8: Add quick-create button to CreatureList

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureList.tsx`
- Modify: `web/frontend/src/pages/DataEditor/index.tsx:93-94`

**Step 1: Update CreatureList props to include onRefresh**

The `Props` interface and component need `onRefresh` to reload data after creation. Update `CreatureList.tsx`:

```typescript
import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Search, Plus } from 'lucide-react'
import { TYPE_COLORS } from '@/theme/colors'
import { type Creature, spritePath, creaturesApi } from '@/api/creatures'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'

interface Props {
  creatures: Record<string, Creature>
  selectedId: string | null
  onSelect: (id: string) => void
  onRefresh?: () => void
}

export default function CreatureList({ creatures, selectedId, onSelect, onRefresh }: Props) {
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    const entries = Object.entries(creatures)
    if (!search) return entries
    const q = search.toLowerCase()
    return entries.filter(
      ([id, c]) =>
        c.name.toLowerCase().includes(q) ||
        id.toLowerCase().includes(q) ||
        c.types.some((t) => t.toLowerCase().includes(q))
    )
  }, [creatures, search])

  const handleCreate = async () => {
    try {
      const result = await creaturesApi.create()
      toast.success('Creature created')
      await onRefresh?.()
      onSelect(result.creature_id)
    } catch (err) {
      toast.error(`Failed to create creature: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  return (
    <div className="flex flex-col h-full border-r border-stone-light/30">
      <div className="p-3 border-b border-stone-light/30 space-y-2">
        <Button
          variant="ghost"
          size="sm"
          onClick={handleCreate}
          className="w-full text-gold/70 hover:text-gold justify-start"
        >
          <Plus className="size-3.5" />
          New Creature
        </Button>
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search creatures..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
        </div>
        {/* Filters section will be added in Task 9 */}
        <p className="mt-1.5 text-xs text-parchment/40">
          {filtered.length} of {Object.keys(creatures).length} creatures
        </p>
      </div>

      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-0.5 p-1.5">
          {filtered.map(([id, creature]) => (
            <button
              key={id}
              onClick={() => onSelect(id)}
              className={cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-left transition-colors',
                selectedId === id
                  ? 'bg-gold/15 text-gold'
                  : 'text-parchment/80 hover:bg-stone-light/20'
              )}
            >
              <div className="flex size-10 items-center justify-center rounded-lg bg-stone-light/30 overflow-hidden shrink-0">
                <img
                  src={`/api/assets/thumbnail/${spritePath(id, 'battle')}?size=64`}
                  alt={creature.name}
                  className="size-8 object-contain"
                  onError={(e) => {
                    ;(e.target as HTMLImageElement).style.display = 'none'
                  }}
                />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{creature.name}</p>
                <div className="flex gap-1 mt-0.5">
                  {creature.types.map((t) => (
                    <Badge
                      key={t}
                      className="text-[10px] px-1.5 py-0 h-4 border-0"
                      style={{
                        backgroundColor: `${TYPE_COLORS[t] ?? '#666'}22`,
                        color: TYPE_COLORS[t] ?? '#999',
                      }}
                    >
                      {t}
                    </Badge>
                  ))}
                </div>
              </div>
            </button>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
```

**Step 2: Wire up onRefresh in DataEditor index**

In `web/frontend/src/pages/DataEditor/index.tsx`, update the creatures section (around line 93-94):

```tsx
{category === 'creatures' && (
  <CreatureList creatures={creatures} selectedId={selectedId} onSelect={setSelectedId} onRefresh={loadData} />
)}
```

**Step 3: Manually test**

1. Open http://127.0.0.1:8000/editor/creatures
2. Click "+ New Creature" button
3. Verify a new creature appears in the list and is auto-selected
4. Verify the detail form opens with default values

**Step 4: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureList.tsx web/frontend/src/pages/DataEditor/index.tsx
git commit -m "feat: add quick-create button to creatures list"
```

---

### Task 9: Add collapsible filter widget

This is the largest task. We add a collapsible "Filters" section below the search box with all 6 filter dimensions.

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureList.tsx`

**Step 1: Add filter state and logic**

Add filter state variables and update the `filtered` memo to apply all filters. The filters need to check sprite existence via image load (we can't know server-side from the list data alone), so for "missing sprites" we'll use a simpler approach: check if the sprite URL returns an error by tracking loaded sprites in state.

For missing sprites, we'll do a lightweight check: the list already renders `<img>` tags with `onError` handlers. We can track which sprites have errored. But this is complex for filtering. A simpler approach: add a backend endpoint or include sprite existence info in the creature list response.

Actually, the simplest approach: just check the image URL with a HEAD request at list load time, or add sprite existence to the API response. But the cleanest approach for now: add `has_overworld_sprite` and `has_battle_sprite` fields to the API response.

**Step 1a: Add sprite existence to backend creatures list**

In `web/backend/routers/creatures.py`, modify the `list_creatures` endpoint to include sprite existence:

```python
from pathlib import Path
from backend.config import settings

@router.get("/")
def list_creatures():
    creatures = data_svc.get_all_creatures()
    sprites_dir = settings.repo_path / "assets" / "sprites" / "creatures"
    for cid, cdata in creatures.items():
        cdata["has_overworld_sprite"] = (sprites_dir / f"{cid}.png").exists()
        cdata["has_battle_sprite"] = (sprites_dir / f"{cid}_battle.png").exists()
    return creatures
```

**Step 1b: Update TypeScript interface**

Add to the `Creature` interface in `web/frontend/src/api/creatures.ts`:

```typescript
  // Populated by list endpoint
  has_overworld_sprite?: boolean
  has_battle_sprite?: boolean
```

**Step 2: Implement the filter widget in CreatureList**

Replace `CreatureList.tsx` with the full implementation including filters:

```typescript
import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Search, Plus, ChevronDown, ChevronRight, X } from 'lucide-react'
import { TYPE_COLORS } from '@/theme/colors'
import { type Creature, spritePath, creaturesApi } from '@/api/creatures'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'

interface Filters {
  types: string[]
  classes: string[]
  category: 'all' | 'starter' | 'wild'
  missingOverworld: boolean
  missingBattle: boolean
  hasEvolution: 'all' | 'yes' | 'no'
  recruitable: 'all' | 'yes' | 'no'
}

const DEFAULT_FILTERS: Filters = {
  types: [],
  classes: [],
  category: 'all',
  missingOverworld: false,
  missingBattle: false,
  hasEvolution: 'all',
  recruitable: 'all',
}

function isFiltersActive(filters: Filters): boolean {
  return (
    filters.types.length > 0 ||
    filters.classes.length > 0 ||
    filters.category !== 'all' ||
    filters.missingOverworld ||
    filters.missingBattle ||
    filters.hasEvolution !== 'all' ||
    filters.recruitable !== 'all'
  )
}

interface Props {
  creatures: Record<string, Creature>
  selectedId: string | null
  onSelect: (id: string) => void
  onRefresh?: () => void
}

export default function CreatureList({ creatures, selectedId, onSelect, onRefresh }: Props) {
  const [search, setSearch] = useState('')
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [filters, setFilters] = useState<Filters>(DEFAULT_FILTERS)

  // Collect all unique types and classes from data
  const { allTypes, allClasses } = useMemo(() => {
    const types = new Set<string>()
    const classes = new Set<string>()
    for (const c of Object.values(creatures)) {
      c.types.forEach((t) => types.add(t))
      if (c.class) classes.add(c.class)
    }
    return {
      allTypes: [...types].sort(),
      allClasses: [...classes].sort(),
    }
  }, [creatures])

  const filtered = useMemo(() => {
    let entries = Object.entries(creatures)

    // Text search
    if (search) {
      const q = search.toLowerCase()
      entries = entries.filter(
        ([id, c]) =>
          c.name.toLowerCase().includes(q) ||
          id.toLowerCase().includes(q) ||
          c.types.some((t) => t.toLowerCase().includes(q))
      )
    }

    // Type filter
    if (filters.types.length > 0) {
      entries = entries.filter(([, c]) =>
        filters.types.some((t) => c.types.includes(t))
      )
    }

    // Class filter
    if (filters.classes.length > 0) {
      entries = entries.filter(([, c]) => filters.classes.includes(c.class))
    }

    // Category filter
    if (filters.category !== 'all') {
      entries = entries.filter(([, c]) => c.category === filters.category)
    }

    // Missing sprites
    if (filters.missingOverworld) {
      entries = entries.filter(([, c]) => c.has_overworld_sprite === false)
    }
    if (filters.missingBattle) {
      entries = entries.filter(([, c]) => c.has_battle_sprite === false)
    }

    // Has evolution
    if (filters.hasEvolution === 'yes') {
      entries = entries.filter(([, c]) => c.evolution != null)
    } else if (filters.hasEvolution === 'no') {
      entries = entries.filter(([, c]) => c.evolution == null)
    }

    // Recruitable
    if (filters.recruitable === 'yes') {
      entries = entries.filter(([, c]) => c.recruit_method != null)
    } else if (filters.recruitable === 'no') {
      entries = entries.filter(([, c]) => c.recruit_method == null)
    }

    return entries
  }, [creatures, search, filters])

  const toggleType = (t: string) => {
    setFilters((f) => ({
      ...f,
      types: f.types.includes(t) ? f.types.filter((x) => x !== t) : [...f.types, t],
    }))
  }

  const toggleClass = (c: string) => {
    setFilters((f) => ({
      ...f,
      classes: f.classes.includes(c) ? f.classes.filter((x) => x !== c) : [...f.classes, c],
    }))
  }

  const handleCreate = async () => {
    try {
      const result = await creaturesApi.create()
      toast.success('Creature created')
      await onRefresh?.()
      onSelect(result.creature_id)
    } catch (err) {
      toast.error(`Failed to create creature: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  const active = isFiltersActive(filters)

  return (
    <div className="flex flex-col h-full border-r border-stone-light/30">
      <div className="p-3 border-b border-stone-light/30 space-y-2">
        <Button
          variant="ghost"
          size="sm"
          onClick={handleCreate}
          className="w-full text-gold/70 hover:text-gold justify-start"
        >
          <Plus className="size-3.5" />
          New Creature
        </Button>

        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search creatures..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
        </div>

        {/* Collapsible filters */}
        <div>
          <button
            onClick={() => setFiltersOpen(!filtersOpen)}
            className="flex items-center gap-1 text-xs text-parchment/50 hover:text-parchment/70 transition-colors"
          >
            {filtersOpen ? <ChevronDown className="size-3" /> : <ChevronRight className="size-3" />}
            Filters
            {active && <span className="text-gold ml-1">(active)</span>}
          </button>

          {filtersOpen && (
            <div className="mt-2 space-y-3 p-2 rounded-md bg-stone/50 border border-stone-light/30">
              {/* Type chips */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Type</p>
                <div className="flex flex-wrap gap-1">
                  {allTypes.map((t) => (
                    <button
                      key={t}
                      onClick={() => toggleType(t)}
                      className={cn(
                        'text-[10px] px-1.5 py-0.5 rounded-full border transition-colors',
                        filters.types.includes(t)
                          ? 'border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                      style={
                        filters.types.includes(t)
                          ? { backgroundColor: `${TYPE_COLORS[t] ?? '#666'}33`, color: TYPE_COLORS[t] ?? '#999' }
                          : undefined
                      }
                    >
                      {t}
                    </button>
                  ))}
                </div>
              </div>

              {/* Class chips */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Class</p>
                <div className="flex flex-wrap gap-1">
                  {allClasses.map((c) => (
                    <button
                      key={c}
                      onClick={() => toggleClass(c)}
                      className={cn(
                        'text-[10px] px-1.5 py-0.5 rounded-full border transition-colors',
                        filters.classes.includes(c)
                          ? 'bg-gold/20 text-gold border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                    >
                      {c}
                    </button>
                  ))}
                </div>
              </div>

              {/* Category toggle */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Category</p>
                <div className="flex gap-1">
                  {(['all', 'starter', 'wild'] as const).map((opt) => (
                    <button
                      key={opt}
                      onClick={() => setFilters((f) => ({ ...f, category: opt }))}
                      className={cn(
                        'text-[10px] px-2 py-0.5 rounded-full border transition-colors capitalize',
                        filters.category === opt
                          ? 'bg-gold/20 text-gold border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              </div>

              {/* Missing sprites checkboxes */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Missing Sprites</p>
                <div className="space-y-1">
                  <label className="flex items-center gap-1.5 text-[11px] text-parchment/60 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={filters.missingOverworld}
                      onChange={(e) => setFilters((f) => ({ ...f, missingOverworld: e.target.checked }))}
                      className="rounded border-stone-light/30"
                    />
                    Missing overworld
                  </label>
                  <label className="flex items-center gap-1.5 text-[11px] text-parchment/60 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={filters.missingBattle}
                      onChange={(e) => setFilters((f) => ({ ...f, missingBattle: e.target.checked }))}
                      className="rounded border-stone-light/30"
                    />
                    Missing battle
                  </label>
                </div>
              </div>

              {/* Has Evolution toggle */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Has Evolution</p>
                <div className="flex gap-1">
                  {(['all', 'yes', 'no'] as const).map((opt) => (
                    <button
                      key={opt}
                      onClick={() => setFilters((f) => ({ ...f, hasEvolution: opt }))}
                      className={cn(
                        'text-[10px] px-2 py-0.5 rounded-full border transition-colors capitalize',
                        filters.hasEvolution === opt
                          ? 'bg-gold/20 text-gold border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              </div>

              {/* Recruitable toggle */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Recruitable</p>
                <div className="flex gap-1">
                  {(['all', 'yes', 'no'] as const).map((opt) => (
                    <button
                      key={opt}
                      onClick={() => setFilters((f) => ({ ...f, recruitable: opt }))}
                      className={cn(
                        'text-[10px] px-2 py-0.5 rounded-full border transition-colors capitalize',
                        filters.recruitable === opt
                          ? 'bg-gold/20 text-gold border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              </div>

              {/* Clear filters */}
              {active && (
                <button
                  onClick={() => setFilters(DEFAULT_FILTERS)}
                  className="flex items-center gap-1 text-[11px] text-gold/70 hover:text-gold transition-colors"
                >
                  <X className="size-3" />
                  Clear filters
                </button>
              )}
            </div>
          )}
        </div>

        <p className="text-xs text-parchment/40">
          {filtered.length} of {Object.keys(creatures).length} creatures
        </p>
      </div>

      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-0.5 p-1.5">
          {filtered.map(([id, creature]) => (
            <button
              key={id}
              onClick={() => onSelect(id)}
              className={cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-left transition-colors',
                selectedId === id
                  ? 'bg-gold/15 text-gold'
                  : 'text-parchment/80 hover:bg-stone-light/20'
              )}
            >
              <div className="flex size-10 items-center justify-center rounded-lg bg-stone-light/30 overflow-hidden shrink-0">
                <img
                  src={`/api/assets/thumbnail/${spritePath(id, 'battle')}?size=64`}
                  alt={creature.name}
                  className="size-8 object-contain"
                  onError={(e) => {
                    ;(e.target as HTMLImageElement).style.display = 'none'
                  }}
                />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{creature.name}</p>
                <div className="flex gap-1 mt-0.5">
                  {creature.types.map((t) => (
                    <Badge
                      key={t}
                      className="text-[10px] px-1.5 py-0 h-4 border-0"
                      style={{
                        backgroundColor: `${TYPE_COLORS[t] ?? '#666'}22`,
                        color: TYPE_COLORS[t] ?? '#999',
                      }}
                    >
                      {t}
                    </Badge>
                  ))}
                </div>
              </div>
            </button>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
```

**Step 3: Manually test all filters**

1. Open http://127.0.0.1:8000/editor/creatures
2. Click "Filters" to expand
3. Test each filter individually and in combination
4. Verify "Clear filters" resets everything
5. Verify creature count updates correctly

**Step 4: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureList.tsx web/backend/routers/creatures.py web/frontend/src/api/creatures.ts
git commit -m "feat: add collapsible filter widget to creatures list"
```

---

### Task 10: Update documentation references

**Files:**
- Modify: `docs/adding-assets.md`
- Modify: `docs/10-design-patterns.md`
- Modify: `docs/01-overview.md`

**Step 1: Update all doc references from starters.json/wild.json to creatures.json**

In `docs/adding-assets.md`, update references to use `data/creatures/creatures.json` and mention the `category` field.

In `docs/10-design-patterns.md`, update the instruction about where to add creatures.

In `docs/01-overview.md`, update the directory tree comment.

**Step 2: Commit**

```bash
git add docs/
git commit -m "docs: update references for consolidated creatures.json"
```

---

### Task 11: Final integration test

**Step 1: Run full test suite**

Run: `cd web && python -m pytest tests/ -v`
Expected: All pass

**Step 2: Manual smoke test**

1. Open http://127.0.0.1:8000/editor/creatures
2. Verify all creatures load with correct type badges
3. Click "+ New Creature" — verify it creates and selects
4. Open Filters — test type, class, category, sprites, evolution, recruitable
5. Combine filters — verify count updates
6. Clear filters — verify reset
7. Search text — verify it still works with filters active
