# Sprite Processing Pipeline — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Auto-resize uploaded creature sprites to 128x128 game-ready PNGs, convert GIF/JPEG to PNG, preserve originals, and provide a batch reprocess endpoint with a UI button.

**Architecture:** Add a `process_sprite` method to `AssetService` that saves the original to `original/` and writes a resized 128x128 PNG to the game path. The upload endpoint calls this for creature sprites. A new batch endpoint reprocesses all existing sprites. The download button serves from `original/`.

**Tech Stack:** Python/PIL (already a dependency), FastAPI, React/TypeScript

---

### Task 1: Add `process_sprite` method to AssetService

**Files:**
- Modify: `web/backend/services/asset_service.py:108-111`
- Test: `web/tests/test_asset_service.py`

**Step 1: Write failing tests**

Add to `web/tests/test_asset_service.py`:

```python
from PIL import Image
from io import BytesIO


def _make_png(width: int, height: int) -> bytes:
    """Create a test PNG image of given dimensions."""
    img = Image.new("RGBA", (width, height), (255, 0, 0, 255))
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _make_jpeg(width: int, height: int) -> bytes:
    """Create a test JPEG image of given dimensions."""
    img = Image.new("RGB", (width, height), (0, 255, 0))
    buf = BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_process_sprite_resizes_large_image(asset_service):
    content = _make_png(1024, 1024)
    rel_path = "assets/sprites/creatures/test_creature.png"
    asset_service.process_sprite(rel_path, content)

    # Game-ready file should exist and be ≤128px
    game_path = asset_service.repo_path / rel_path
    assert game_path.exists()
    with Image.open(game_path) as img:
        assert img.width <= 128
        assert img.height <= 128

    # Original should be preserved at full resolution
    original_path = asset_service.repo_path / "assets/sprites/creatures/original/test_creature.png"
    assert original_path.exists()
    with Image.open(original_path) as img:
        assert img.width == 1024


def test_process_sprite_converts_jpeg_to_png(asset_service):
    content = _make_jpeg(512, 256)
    rel_path = "assets/sprites/creatures/test_creature.png"
    asset_service.process_sprite(rel_path, content)

    game_path = asset_service.repo_path / rel_path
    assert game_path.exists()
    with Image.open(game_path) as img:
        assert img.format == "PNG"
        assert img.width <= 128
        assert img.height <= 128

    original_path = asset_service.repo_path / "assets/sprites/creatures/original/test_creature.png"
    assert original_path.exists()


def test_process_sprite_small_image_unchanged(asset_service):
    content = _make_png(64, 64)
    rel_path = "assets/sprites/creatures/tiny.png"
    asset_service.process_sprite(rel_path, content)

    game_path = asset_service.repo_path / rel_path
    with Image.open(game_path) as img:
        assert img.width == 64
        assert img.height == 64

    # Original still saved
    original_path = asset_service.repo_path / "assets/sprites/creatures/original/tiny.png"
    assert original_path.exists()
```

**Step 2: Run tests to verify they fail**

Run: `cd web && .venv/bin/python -m pytest tests/test_asset_service.py -v`
Expected: FAIL — `AttributeError: 'AssetService' object has no attribute 'process_sprite'`

**Step 3: Implement `process_sprite`**

In `web/backend/services/asset_service.py`, add this method to the `AssetService` class (after `save_uploaded_file`):

```python
GAME_SPRITE_SIZE = 128

def process_sprite(self, rel_path: str, content: bytes) -> None:
    """Save original to original/ subdir, write resized game-ready PNG to rel_path."""
    from io import BytesIO

    full_path = self.repo_path / rel_path
    full_path.parent.mkdir(parents=True, exist_ok=True)

    # Save original
    original_dir = full_path.parent / "original"
    original_dir.mkdir(parents=True, exist_ok=True)
    original_path = original_dir / full_path.name
    original_path.write_bytes(content)

    # Open, convert to RGBA PNG, resize if needed
    with Image.open(BytesIO(content)) as img:
        img = img.convert("RGBA")
        img.thumbnail((self.GAME_SPRITE_SIZE, self.GAME_SPRITE_SIZE), Image.Resampling.LANCZOS)
        buf = BytesIO()
        img.save(buf, format="PNG")
        full_path.write_bytes(buf.getvalue())
```

**Step 4: Run tests to verify they pass**

Run: `cd web && .venv/bin/python -m pytest tests/test_asset_service.py -v`
Expected: All PASS

**Step 5: Commit**

```bash
git add web/backend/services/asset_service.py web/tests/test_asset_service.py
git commit -m "feat: add process_sprite method for resize and format conversion"
```

---

### Task 2: Wire upload endpoint to use `process_sprite` for creature sprites

**Files:**
- Modify: `web/backend/routers/assets.py:47-51`

**Step 1: Write failing integration test**

Add to `web/tests/test_integration.py`:

```python
from PIL import Image
from io import BytesIO


def test_upload_creature_sprite_is_processed(client, test_repo):
    """Uploading a large creature sprite should produce a ≤128px game-ready version."""
    # Create a large test image
    img = Image.new("RGBA", (512, 512), (255, 0, 0, 255))
    buf = BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)

    r = client.post(
        "/api/assets/upload/assets/sprites/creatures/test_upload.png",
        files={"file": ("test_upload.png", buf, "image/png")},
    )
    assert r.status_code == 200

    # Game-ready file should be ≤128px
    game_path = test_repo / "assets/sprites/creatures/test_upload.png"
    assert game_path.exists()
    with Image.open(game_path) as result_img:
        assert result_img.width <= 128
        assert result_img.height <= 128

    # Original should be preserved
    original_path = test_repo / "assets/sprites/creatures/original/test_upload.png"
    assert original_path.exists()
    with Image.open(original_path) as orig_img:
        assert orig_img.width == 512
```

**Step 2: Run test to verify it fails**

Run: `cd web && .venv/bin/python -m pytest tests/test_integration.py::test_upload_creature_sprite_is_processed -v`
Expected: FAIL — the uploaded image will be 512x512 (no processing)

**Step 3: Update upload endpoint**

In `web/backend/routers/assets.py`, modify the upload endpoint to process creature sprites:

```python
@router.post("/upload/{path:path}")
async def upload_asset(path: str, file: UploadFile = File(...)):
    content = await file.read()
    if path.startswith("assets/sprites/creatures/") and not path.startswith("assets/sprites/creatures/original/"):
        asset_svc.process_sprite(path, content)
    else:
        asset_svc.save_uploaded_file(path, content)
    return {"status": "uploaded", "path": path}
```

**Step 4: Run test to verify it passes**

Run: `cd web && .venv/bin/python -m pytest tests/test_integration.py::test_upload_creature_sprite_is_processed -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd web && .venv/bin/python -m pytest tests/ -v`
Expected: All pass

**Step 6: Commit**

```bash
git add web/backend/routers/assets.py web/tests/test_integration.py
git commit -m "feat: auto-process creature sprites on upload"
```

---

### Task 3: Add batch reprocess endpoint

**Files:**
- Modify: `web/backend/services/asset_service.py`
- Modify: `web/backend/routers/assets.py`

**Step 1: Write failing test**

Add to `web/tests/test_asset_service.py`:

```python
def test_reprocess_all_sprites(asset_service):
    # Place a large image directly (simulating pre-existing unprocessed sprite)
    creatures_dir = asset_service.repo_path / "assets" / "sprites" / "creatures"
    large_img = Image.new("RGBA", (1024, 1024), (255, 0, 0, 255))
    large_img.save(creatures_dir / "big_creature.png")

    count = asset_service.reprocess_all_sprites()
    assert count >= 1

    # Game-ready should be ≤128px
    with Image.open(creatures_dir / "big_creature.png") as img:
        assert img.width <= 128

    # Original should exist
    assert (creatures_dir / "original" / "big_creature.png").exists()
```

**Step 2: Run test to verify it fails**

Run: `cd web && .venv/bin/python -m pytest tests/test_asset_service.py::test_reprocess_all_sprites -v`
Expected: FAIL — `AttributeError: 'AssetService' object has no attribute 'reprocess_all_sprites'`

**Step 3: Implement `reprocess_all_sprites`**

Add to `AssetService` class in `web/backend/services/asset_service.py`:

```python
def reprocess_all_sprites(self) -> int:
    """Reprocess all creature sprites: move to original/, generate game-ready versions."""
    creatures_dir = self.repo_path / "assets" / "sprites" / "creatures"
    if not creatures_dir.exists():
        return 0
    count = 0
    for f in sorted(creatures_dir.glob("*.png")):
        if f.is_dir():
            continue
        content = f.read_bytes()
        rel_path = str(f.relative_to(self.repo_path))
        self.process_sprite(rel_path, content)
        count += 1
    # Also process .jpg, .jpeg, .gif files
    for ext in ("*.jpg", "*.jpeg", "*.gif"):
        for f in sorted(creatures_dir.glob(ext)):
            if f.is_dir():
                continue
            content = f.read_bytes()
            # Output path is always .png
            png_name = f.stem + ".png"
            rel_path = str((f.parent / png_name).relative_to(self.repo_path))
            self.process_sprite(rel_path, content)
            # Remove the original non-PNG file from the game directory
            f.unlink()
            count += 1
    return count
```

**Step 4: Add the route**

Add to `web/backend/routers/assets.py`:

```python
@router.post("/reprocess-sprites")
def reprocess_sprites():
    count = asset_svc.reprocess_all_sprites()
    return {"status": "reprocessed", "count": count}
```

**Step 5: Run tests**

Run: `cd web && .venv/bin/python -m pytest tests/test_asset_service.py -v`
Expected: All pass

**Step 6: Commit**

```bash
git add web/backend/services/asset_service.py web/backend/routers/assets.py
git commit -m "feat: add batch reprocess endpoint for creature sprites"
```

---

### Task 4: Update download to serve from original/

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureForm.tsx:59-65`

**Step 1: Update downloadSprite to use original/ path**

In `CreatureForm.tsx`, change the `downloadSprite` function:

```typescript
const downloadSprite = (variant: 'overworld' | 'battle') => {
  const path = spritePath(id, variant)
  // Download full-resolution original
  const originalPath = path.replace('assets/sprites/creatures/', 'assets/sprites/creatures/original/')
  const a = document.createElement('a')
  a.href = `/api/assets/file/${originalPath}`
  a.download = path.split('/').pop() ?? `${id}.png`
  a.click()
}
```

**Step 2: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureForm.tsx
git commit -m "feat: download full-resolution originals instead of game-ready sprites"
```

---

### Task 5: Update file upload accept attribute to include JPEG/GIF

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureForm.tsx:92,112`

**Step 1: Update accept attribute on file inputs**

The hidden file inputs currently have `accept="image/png"`. Change both to accept all image formats that will be converted:

```typescript
accept="image/png,image/jpeg,image/gif"
```

There are two instances — one for overworld (line ~94) and one for battle (line ~115).

**Step 2: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureForm.tsx
git commit -m "feat: accept JPEG and GIF uploads for creature sprites"
```

---

### Task 6: Add "Reprocess All Sprites" button to the web UI

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureList.tsx`

**Step 1: Add reprocess button**

Add a "Reprocess Sprites" button below the "New Creature" button in the sidebar header. When clicked, it calls `POST /api/assets/reprocess-sprites` and shows a toast with the count.

Add the handler inside the component:

```typescript
const handleReprocess = async () => {
  try {
    const res = await fetch('/api/assets/reprocess-sprites', { method: 'POST' })
    if (!res.ok) throw new Error(`Reprocess failed: ${res.status}`)
    const data = await res.json()
    toast.success(`Reprocessed ${data.count} sprites`)
    onRefresh?.()
  } catch (err) {
    toast.error(`Failed to reprocess: ${err instanceof Error ? err.message : 'Unknown error'}`)
  }
}
```

Add the button JSX after the "New Creature" button:

```tsx
<Button
  variant="ghost"
  size="sm"
  onClick={handleReprocess}
  className="w-full text-parchment/50 hover:text-parchment/70 justify-start text-xs"
>
  <RefreshCw className="size-3.5" />
  Reprocess Sprites
</Button>
```

Add `RefreshCw` to the lucide-react import.

**Step 2: Verify frontend builds**

Run: `cd web/frontend && npx vite build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureList.tsx
git commit -m "feat: add reprocess sprites button to creatures list"
```

---

### Task 7: Exclude original/ from asset listing

The `list_assets` method uses `rglob("*")` which will pick up files in `original/`. These shouldn't appear in the main asset list.

**Files:**
- Modify: `web/backend/services/asset_service.py:69-91`

**Step 1: Add exclusion for original/ directory**

In the `list_assets` method, add a check to skip files in `original/` subdirectories. After line 73 (`if f.is_dir() or f.suffix == ".import":`), the check should also skip files whose path contains `/original/`:

```python
if f.is_dir() or f.suffix == ".import":
    continue
if "/original/" in str(f) or "\\original\\" in str(f):
    continue
```

**Step 2: Run tests**

Run: `cd web && .venv/bin/python -m pytest tests/ -v`
Expected: All pass

**Step 3: Commit**

```bash
git add web/backend/services/asset_service.py
git commit -m "fix: exclude original/ directory from asset listing"
```

---

### Task 8: Final verification

**Step 1: Run full test suite**

Run: `cd web && .venv/bin/python -m pytest tests/ -v`
Expected: All pass

**Step 2: Verify frontend build**

Run: `cd web/frontend && npx vite build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Manual smoke test**

1. Open http://127.0.0.1:8000/editor/creatures
2. Click "Reprocess Sprites" — should show toast with count of processed sprites
3. Upload a large PNG for a creature — should display at game-ready size
4. Upload a JPEG — should be converted and displayed as PNG
5. Click download — should download the full-resolution original
