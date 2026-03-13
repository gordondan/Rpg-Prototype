# Animation Upload & Image Type System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the hardcoded sprite upload with a reusable ImageUpload component that supports four image types (Character Image, Animation Sprite2D, Animation Player, Map), with Gemini-powered sprite sheet detection and Godot .tres resource generation.

**Architecture:** Backend gets a new `SpriteSheetService` for .tres generation and a `GeminiService` for vision-based grid detection. The upload endpoint branches by image type. Frontend gets a reusable `ImageUpload` component with type-dependent form fields, replacing the hardcoded sprite uploads in `CreatureForm`.

**Tech Stack:** Python/FastAPI, Pillow, Google Gemini API (vision), React/TypeScript, shadcn/ui components (Select, Dialog, Input, Label), Godot .tres text format

---

### Task 1: Add Gemini API key to config and .gitignore

**Files:**
- Modify: `web/backend/config.py`
- Modify: `.gitignore`

**Step 1: Add gemini_api_key to Settings**

In `web/backend/config.py`, add the field to the `Settings` class:

```python
class Settings(BaseSettings):
    repo_path: Path = Path("/repo")
    data_dir: str = "data"
    assets_dir: str = "assets"
    metadata_file: str = "web/asset_metadata.json"
    git_author_name: str = "RPG Asset Browser"
    git_author_email: str = "rpg-browser@dagordons.com"
    gemini_api_key: str = ""
```

**Step 2: Add .env to .gitignore**

Append to `.gitignore`:

```
# Environment secrets
.env
web/.env
```

**Step 3: Add google-genai to requirements.txt**

In `web/requirements.txt`, add:

```
google-genai>=1.0.0
```

**Step 4: Install the dependency**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web && .venv/bin/pip install google-genai`

**Step 5: Commit**

```bash
git add web/backend/config.py .gitignore web/requirements.txt
git commit -m "feat: add Gemini API key config and .env to gitignore"
```

---

### Task 2: Create SpriteSheetService for Godot .tres generation

**Files:**
- Create: `web/backend/services/spritesheet_service.py`

This service generates Godot-loadable `.tres` resource files from sprite sheet metadata.

**Step 1: Create the SpriteSheetService**

Create `web/backend/services/spritesheet_service.py`:

```python
from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path

from backend.config import settings


@dataclass
class SpriteSheetMeta:
    frame_width: int = 64
    frame_height: int = 64
    columns: int = 1
    rows: int = 1
    frame_count: int = 1
    fps: float = 8.0
    loop: bool = True
    animation_type: str = "sprite2d"  # "sprite2d" or "player"


class SpriteSheetService:
    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path

    def generate_resources(
        self,
        creature_id: str,
        animation_name: str,
        meta: SpriteSheetMeta,
    ) -> str:
        """Generate Godot .tres resource file for a sprite sheet animation.

        Returns the relative path to the generated .tres file.
        """
        anim_dir = (
            self.repo_path
            / "assets"
            / "sprites"
            / "creatures"
            / creature_id
            / animation_name
        )
        anim_dir.mkdir(parents=True, exist_ok=True)

        # Save metadata
        meta_path = anim_dir / "metadata.json"
        meta_path.write_text(json.dumps(asdict(meta), indent=2) + "\n")

        # Generate .tres
        tres_path = anim_dir / f"{animation_name}.tres"
        if meta.animation_type == "sprite2d":
            content = self._generate_sprite_frames(creature_id, animation_name, meta)
        else:
            content = self._generate_animation(creature_id, animation_name, meta)
        tres_path.write_text(content)

        return str(tres_path.relative_to(self.repo_path))

    def _generate_sprite_frames(
        self,
        creature_id: str,
        animation_name: str,
        meta: SpriteSheetMeta,
    ) -> str:
        """Generate a SpriteFrames .tres with AtlasTexture regions."""
        sheet_path = f"res://assets/sprites/creatures/{creature_id}/{animation_name}/spritesheet.png"

        # We need: 1 ExtResource (the texture), N SubResources (AtlasTextures), 1 Resource (SpriteFrames)
        # ExtResource IDs start at 1, SubResource IDs start at 1
        lines = []

        # Header — resource_count = 1 texture + frame_count atlas textures + 1 sprite_frames
        sub_resource_count = meta.frame_count
        lines.append(
            f'[gd_resource type="SpriteFrames" load_steps={2 + sub_resource_count} format=3]'
        )
        lines.append("")

        # ExtResource: the sprite sheet texture
        lines.append(f'[ext_resource type="Texture2D" path="{sheet_path}" id="1"]')
        lines.append("")

        # SubResources: one AtlasTexture per frame
        for i in range(meta.frame_count):
            col = i % meta.columns
            row = i // meta.columns
            x = col * meta.frame_width
            y = row * meta.frame_height
            lines.append(
                f'[sub_resource type="AtlasTexture" id="{i + 1}"]'
            )
            lines.append('atlas = ExtResource("1")')
            lines.append(
                f"region = Rect2({x}, {y}, {meta.frame_width}, {meta.frame_height})"
            )
            lines.append("")

        # Main resource: SpriteFrames
        lines.append("[resource]")

        # Build the animations array
        # SpriteFrames format: animations = [{ "name": ..., "speed": ..., "loop": ..., "frames": [...] }]
        frame_entries = []
        for i in range(meta.frame_count):
            frame_entries.append(
                '{ "texture": SubResource("'
                + str(i + 1)
                + '"), "duration": 1.0 }'
            )
        frames_str = "[" + ", ".join(frame_entries) + "]"

        loop_str = "true" if meta.loop else "false"
        lines.append(
            f'animations = [{{ "name": &"{animation_name}", "speed": {meta.fps:.1f}, "loop": {loop_str}, "frames": {frames_str} }}]'
        )

        return "\n".join(lines) + "\n"

    def _generate_animation(
        self,
        creature_id: str,
        animation_name: str,
        meta: SpriteSheetMeta,
    ) -> str:
        """Generate an Animation .tres with keyframed region_rect tracks."""
        sheet_path = f"res://assets/sprites/creatures/{creature_id}/{animation_name}/spritesheet.png"

        duration = meta.frame_count / meta.fps
        loop_mode = 1 if meta.loop else 0  # 0=none, 1=linear

        lines = []
        lines.append(
            f'[gd_resource type="Animation" load_steps=2 format=3]'
        )
        lines.append("")

        # ExtResource: the sprite sheet texture
        lines.append(f'[ext_resource type="Texture2D" path="{sheet_path}" id="1"]')
        lines.append("")

        lines.append("[resource]")
        lines.append(f'resource_name = "{animation_name}"')
        lines.append(f"length = {duration:.4f}")
        lines.append(f"loop_mode = {loop_mode}")

        # Track 0: texture track (sets the texture)
        lines.append("tracks/0/type = \"value\"")
        lines.append("tracks/0/imported = false")
        lines.append("tracks/0/enabled = true")
        lines.append('tracks/0/path = NodePath("Sprite2D:texture")')
        lines.append("tracks/0/interp = 1")
        lines.append("tracks/0/update_mode = 1")
        lines.append("tracks/0/keys = {")
        lines.append('"times": PackedFloat32Array(0),')
        lines.append('"transitions": PackedFloat32Array(1),')
        lines.append('"values": [ExtResource("1")]')
        lines.append("}")

        # Track 1: region_rect track (animates which frame to show)
        times = []
        rects = []
        for i in range(meta.frame_count):
            col = i % meta.columns
            row = i // meta.columns
            x = col * meta.frame_width
            y = row * meta.frame_height
            t = i / meta.fps
            times.append(f"{t:.4f}")
            rects.append(
                f"Rect2({x}, {y}, {meta.frame_width}, {meta.frame_height})"
            )

        lines.append("tracks/1/type = \"value\"")
        lines.append("tracks/1/imported = false")
        lines.append("tracks/1/enabled = true")
        lines.append('tracks/1/path = NodePath("Sprite2D:region_rect")')
        lines.append("tracks/1/interp = 1")
        lines.append("tracks/1/update_mode = 1")
        lines.append("tracks/1/keys = {")
        times_str = ", ".join(times)
        lines.append(f'"times": PackedFloat32Array({times_str}),')
        transitions_str = ", ".join(["1"] * meta.frame_count)
        lines.append(f'"transitions": PackedFloat32Array({transitions_str}),')
        values_str = ", ".join(rects)
        lines.append(f'"values": [{values_str}]')
        lines.append("}")

        return "\n".join(lines) + "\n"

    def list_animations(self, creature_id: str) -> list[dict]:
        """List all animations for a creature by scanning its folder."""
        creature_dir = (
            self.repo_path / "assets" / "sprites" / "creatures" / creature_id
        )
        if not creature_dir.is_dir():
            return []

        animations = []
        for sub in sorted(creature_dir.iterdir()):
            if not sub.is_dir():
                continue
            meta_path = sub / "metadata.json"
            if not meta_path.exists():
                continue
            meta = json.loads(meta_path.read_text())
            animations.append(
                {
                    "name": sub.name,
                    "meta": meta,
                    "has_tres": (sub / f"{sub.name}.tres").exists(),
                    "has_spritesheet": (sub / "spritesheet.png").exists(),
                }
            )
        return animations
```

**Step 2: Verify the file was created correctly**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game && python -c "from web.backend.services.spritesheet_service import SpriteSheetService, SpriteSheetMeta; print('OK')"`

If import path issues, try: `cd /Users/gordon/Documents/Tyrell/monster-game/web && PYTHONPATH=. python -c "from backend.services.spritesheet_service import SpriteSheetService, SpriteSheetMeta; print('OK')"`

**Step 3: Commit**

```bash
git add web/backend/services/spritesheet_service.py
git commit -m "feat: add SpriteSheetService for Godot .tres generation"
```

---

### Task 3: Create GeminiService for sprite sheet analysis

**Files:**
- Create: `web/backend/services/gemini_service.py`

**Step 1: Create the GeminiService**

Create `web/backend/services/gemini_service.py`:

```python
from __future__ import annotations

import json
import base64
from dataclasses import dataclass

from backend.config import settings


@dataclass
class GridDetection:
    frame_width: int
    frame_height: int
    columns: int
    rows: int
    frame_count: int
    confidence: float  # 0-1


class GeminiService:
    def __init__(self):
        self.api_key = settings.gemini_api_key

    @property
    def available(self) -> bool:
        return bool(self.api_key)

    def detect_sprite_grid(self, image_bytes: bytes, image_width: int, image_height: int) -> GridDetection | None:
        """Use Gemini vision to detect the sprite grid layout in a sprite sheet.

        Returns None if the API key is not configured or if detection fails.
        """
        if not self.available:
            return None

        try:
            from google import genai

            client = genai.Client(api_key=self.api_key)

            b64_image = base64.b64encode(image_bytes).decode("utf-8")

            prompt = f"""Analyze this sprite sheet image ({image_width}x{image_height} pixels).

This is a game sprite sheet containing animation frames arranged in a grid.

Determine:
1. The width and height of each individual frame in pixels
2. The number of columns and rows in the grid
3. The total number of frames (some grid cells at the end may be empty)

Respond with ONLY a JSON object, no other text:
{{"frame_width": <int>, "frame_height": <int>, "columns": <int>, "rows": <int>, "frame_count": <int>, "confidence": <float 0-1>}}"""

            response = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=[
                    {
                        "parts": [
                            {"text": prompt},
                            {
                                "inline_data": {
                                    "mime_type": "image/png",
                                    "data": b64_image,
                                }
                            },
                        ]
                    }
                ],
            )

            text = response.text.strip()
            # Strip markdown code fences if present
            if text.startswith("```"):
                text = text.split("\n", 1)[1]
                text = text.rsplit("```", 1)[0].strip()

            data = json.loads(text)
            return GridDetection(
                frame_width=int(data["frame_width"]),
                frame_height=int(data["frame_height"]),
                columns=int(data["columns"]),
                rows=int(data["rows"]),
                frame_count=int(data["frame_count"]),
                confidence=float(data.get("confidence", 0.5)),
            )
        except Exception as e:
            print(f"[gemini] sprite grid detection failed: {e}")
            return None
```

**Step 2: Verify import**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web && PYTHONPATH=. python -c "from backend.services.gemini_service import GeminiService; print('available:', GeminiService().available)"`

**Step 3: Commit**

```bash
git add web/backend/services/gemini_service.py
git commit -m "feat: add GeminiService for sprite sheet grid detection"
```

---

### Task 4: Update upload endpoint with image type routing

**Files:**
- Modify: `web/backend/routers/assets.py`
- Modify: `web/backend/services/asset_service.py`

**Step 1: Add image type enum and update the upload endpoint**

In `web/backend/routers/assets.py`, update the upload endpoint to accept an `image_type` query parameter and add new endpoints for animation analysis and resource generation:

```python
from fastapi import APIRouter, HTTPException, UploadFile, File, Query
from fastapi.responses import Response
from pydantic import BaseModel

from backend.services.asset_service import AssetService
from backend.services.git_service import GitService
from backend.services.spritesheet_service import SpriteSheetService, SpriteSheetMeta
from backend.services.gemini_service import GeminiService

router = APIRouter(prefix="/api/assets", tags=["assets"])
asset_svc = AssetService()
git_svc = GitService()
spritesheet_svc = SpriteSheetService()
gemini_svc = GeminiService()


# ... keep all existing endpoints unchanged ...


@router.post("/upload/{path:path}")
async def upload_asset(
    path: str,
    file: UploadFile = File(...),
    image_type: str = Query("character", description="character, sprite2d, player, or map"),
):
    content = await file.read()

    if image_type in ("sprite2d", "player"):
        # Animation upload: save sprite sheet without processing
        asset_svc.save_uploaded_file(path, content)
        return {"status": "uploaded", "path": path}
    elif image_type == "map":
        # Map: save as-is
        asset_svc.save_uploaded_file(path, content)
        return {"status": "uploaded", "path": path}
    elif path.startswith("assets/sprites/creatures/") and not path.startswith("assets/sprites/creatures/original/"):
        # Character image: existing sprite processing
        asset_svc.process_sprite(path, content)
    elif path.startswith("assets/audio/sfx/"):
        path = asset_svc.process_audio(path, content)
    else:
        asset_svc.save_uploaded_file(path, content)

    return {"status": "uploaded", "path": path}


class AnalyzeRequest(BaseModel):
    creature_id: str
    animation_name: str


@router.post("/analyze-spritesheet/{path:path}")
async def analyze_spritesheet(path: str):
    """Analyze a sprite sheet image to detect grid layout using Gemini vision."""
    from PIL import Image
    from io import BytesIO

    full_path = asset_svc.repo_path / path
    if not full_path.exists():
        raise HTTPException(404, "Sprite sheet not found")

    content = full_path.read_bytes()
    with Image.open(BytesIO(content)) as img:
        width, height = img.size

    # Try Gemini detection
    detection = gemini_svc.detect_sprite_grid(content, width, height)

    if detection:
        return {
            "detected": True,
            "frame_width": detection.frame_width,
            "frame_height": detection.frame_height,
            "columns": detection.columns,
            "rows": detection.rows,
            "frame_count": detection.frame_count,
            "confidence": detection.confidence,
            "image_width": width,
            "image_height": height,
        }
    else:
        # Fallback: assume square frames based on height
        frame_size = height
        cols = width // frame_size if frame_size > 0 else 1
        return {
            "detected": False,
            "frame_width": frame_size,
            "frame_height": frame_size,
            "columns": cols,
            "rows": 1,
            "frame_count": cols,
            "confidence": 0.0,
            "image_width": width,
            "image_height": height,
        }


class GenerateResourceRequest(BaseModel):
    creature_id: str
    animation_name: str
    frame_width: int = 64
    frame_height: int = 64
    columns: int = 1
    rows: int = 1
    frame_count: int = 1
    fps: float = 8.0
    loop: bool = True
    animation_type: str = "sprite2d"


@router.post("/generate-animation-resource")
def generate_animation_resource(body: GenerateResourceRequest):
    """Generate a Godot .tres resource file from sprite sheet metadata."""
    # Verify the sprite sheet exists
    sheet_path = (
        asset_svc.repo_path
        / "assets"
        / "sprites"
        / "creatures"
        / body.creature_id
        / body.animation_name
        / "spritesheet.png"
    )
    if not sheet_path.exists():
        raise HTTPException(404, f"Sprite sheet not found at {sheet_path.relative_to(asset_svc.repo_path)}")

    meta = SpriteSheetMeta(
        frame_width=body.frame_width,
        frame_height=body.frame_height,
        columns=body.columns,
        rows=body.rows,
        frame_count=body.frame_count,
        fps=body.fps,
        loop=body.loop,
        animation_type=body.animation_type,
    )

    tres_path = spritesheet_svc.generate_resources(
        body.creature_id, body.animation_name, meta
    )

    return {"status": "generated", "tres_path": tres_path}


@router.get("/animations/{creature_id}")
def list_animations(creature_id: str):
    """List all animations for a creature."""
    return spritesheet_svc.list_animations(creature_id)
```

**Step 2: Verify the server starts**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web && PYTHONPATH=. .venv/bin/python -c "from backend.routers.assets import router; print('Routes:', [r.path for r in router.routes])"`

**Step 3: Commit**

```bash
git add web/backend/routers/assets.py
git commit -m "feat: add image type routing, sprite sheet analysis, and resource generation endpoints"
```

---

### Task 5: Add frontend API functions for new endpoints

**Files:**
- Modify: `web/frontend/src/api/assets.ts`

**Step 1: Add new API types and functions**

Add to `web/frontend/src/api/assets.ts`:

```typescript
import { get, post, httpDelete, BASE } from './client'

export type ImageType = 'character' | 'sprite2d' | 'player' | 'map'

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

export interface GridDetection {
  detected: boolean
  frame_width: number
  frame_height: number
  columns: number
  rows: number
  frame_count: number
  confidence: number
  image_width: number
  image_height: number
}

export interface AnimationInfo {
  name: string
  meta: {
    frame_width: number
    frame_height: number
    columns: number
    rows: number
    frame_count: number
    fps: number
    loop: boolean
    animation_type: string
  }
  has_tres: boolean
  has_spritesheet: boolean
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
  upload: (path: string, file: File, imageType: ImageType = 'character') => {
    const fd = new FormData()
    fd.append('file', file)
    return fetch(`${BASE}/assets/upload/${path}?image_type=${imageType}`, { method: 'POST', body: fd })
  },
  delete: (path: string) => httpDelete(`/assets/${path}`),
  rename: (oldPath: string, newPath: string) =>
    post('/assets/rename', { old_path: oldPath, new_path: newPath }),
  analyzeSpriteSheet: (path: string) =>
    get<GridDetection>(`/assets/analyze-spritesheet/${path}`),
  generateAnimationResource: (params: {
    creature_id: string
    animation_name: string
    frame_width: number
    frame_height: number
    columns: number
    rows: number
    frame_count: number
    fps: number
    loop: boolean
    animation_type: string
  }) => post<{ status: string; tres_path: string }>('/assets/generate-animation-resource', params),
  listAnimations: (creatureId: string) =>
    get<AnimationInfo[]>(`/assets/animations/${creatureId}`),
}
```

**Step 2: Verify TypeScript compiles**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend && npx tsc --noEmit 2>&1 | head -20`

**Step 3: Commit**

```bash
git add web/frontend/src/api/assets.ts
git commit -m "feat: add frontend API functions for animation upload and resource generation"
```

---

### Task 6: Create reusable ImageUpload component

**Files:**
- Create: `web/frontend/src/components/ImageUpload.tsx`

**Step 1: Create the ImageUpload component**

Create `web/frontend/src/components/ImageUpload.tsx`:

```tsx
import { useState, useRef } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Upload, Loader2 } from 'lucide-react'
import { toast } from 'sonner'
import { type ImageType, type GridDetection, assetsApi } from '@/api/assets'
import { BASE } from '@/api/client'

interface Props {
  /** Which image types to offer in the selector */
  allowedTypes?: ImageType[]
  /** Entity this upload is for (e.g., creature ID) */
  entityId: string
  /** Called after a successful upload */
  onUpload?: (result: { path: string; imageType: ImageType }) => void
  /** For character images: overworld or battle */
  variant?: 'overworld' | 'battle'
}

const TYPE_LABELS: Record<ImageType, string> = {
  character: 'Character Image',
  sprite2d: 'Animation (Sprite 2D)',
  player: 'Animation (Player)',
  map: 'Map',
}

export default function ImageUpload({
  allowedTypes = ['character', 'sprite2d', 'player'],
  entityId,
  onUpload,
  variant = 'overworld',
}: Props) {
  const [imageType, setImageType] = useState<ImageType>(allowedTypes[0])
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [analyzing, setAnalyzing] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  // Animation-specific fields
  const [animName, setAnimName] = useState('')
  const [frameWidth, setFrameWidth] = useState(64)
  const [frameHeight, setFrameHeight] = useState(64)
  const [columns, setColumns] = useState(1)
  const [rows, setRows] = useState(1)
  const [frameCount, setFrameCount] = useState(1)
  const [fps, setFps] = useState(8)
  const [loop, setLoop] = useState(true)
  const [detection, setDetection] = useState<GridDetection | null>(null)

  const isAnimation = imageType === 'sprite2d' || imageType === 'player'

  const handleFileSelect = (f: File) => {
    setFile(f)
    setDetection(null)

    // Generate preview
    const url = URL.createObjectURL(f)
    setPreview(url)

    // If animation type, get image dimensions for default grid calc
    if (isAnimation) {
      const img = new Image()
      img.onload = () => {
        // Default: assume square frames based on height
        const h = img.height
        const w = img.width
        const cols = Math.max(1, Math.round(w / h))
        setFrameWidth(Math.round(w / cols))
        setFrameHeight(h)
        setColumns(cols)
        setRows(1)
        setFrameCount(cols)
      }
      img.src = url
    }
  }

  const handleAnalyze = async () => {
    if (!file) return

    // First upload the sprite sheet to a temp-ish location
    const path = `assets/sprites/creatures/${entityId}/${animName || 'unnamed'}/spritesheet.png`
    setAnalyzing(true)
    try {
      const uploadRes = await assetsApi.upload(path, file, imageType)
      if (!uploadRes.ok) throw new Error('Upload failed')

      const result = await assetsApi.analyzeSpriteSheet(path)
      setDetection(result)
      setFrameWidth(result.frame_width)
      setFrameHeight(result.frame_height)
      setColumns(result.columns)
      setRows(result.rows)
      setFrameCount(result.frame_count)

      if (result.detected) {
        toast.success(`Grid detected: ${result.columns}x${result.rows}, ${result.frame_width}x${result.frame_height}px frames`)
      } else {
        toast.info('Could not auto-detect grid. Using fallback dimensions.')
      }
    } catch (err) {
      toast.error(`Analysis failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setAnalyzing(false)
    }
  }

  const handleUpload = async () => {
    if (!file) return
    setUploading(true)

    try {
      if (isAnimation) {
        if (!animName.trim()) {
          toast.error('Animation name is required')
          setUploading(false)
          return
        }

        // Upload sprite sheet
        const path = `assets/sprites/creatures/${entityId}/${animName}/spritesheet.png`
        const uploadRes = await assetsApi.upload(path, file, imageType)
        if (!uploadRes.ok) throw new Error('Upload failed')

        // Generate Godot resource
        await assetsApi.generateAnimationResource({
          creature_id: entityId,
          animation_name: animName,
          frame_width: frameWidth,
          frame_height: frameHeight,
          columns,
          rows,
          frame_count: frameCount,
          fps,
          loop,
          animation_type: imageType,
        })

        toast.success(`Animation "${animName}" created with .tres resource`)
        onUpload?.({ path, imageType })
      } else if (imageType === 'character') {
        const suffix = variant === 'battle' ? `_battle.png` : `.png`
        const path = `assets/sprites/creatures/${entityId}${suffix}`
        const res = await assetsApi.upload(path, file, 'character')
        if (!res.ok) throw new Error('Upload failed')
        toast.success(`${variant} sprite uploaded`)
        onUpload?.({ path, imageType })
      } else {
        // Map type — save as-is
        const path = `assets/sprites/creatures/${entityId}/${file.name}`
        const res = await assetsApi.upload(path, file, 'map')
        if (!res.ok) throw new Error('Upload failed')
        toast.success('File uploaded')
        onUpload?.({ path, imageType })
      }
    } catch (err) {
      toast.error(`Upload failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setUploading(false)
      setFile(null)
      setPreview(null)
    }
  }

  return (
    <div className="space-y-3">
      {/* Type selector — only show if multiple types allowed */}
      {allowedTypes.length > 1 && (
        <div>
          <Label className="text-parchment/60 text-xs">Image Type</Label>
          <select
            value={imageType}
            onChange={(e) => {
              setImageType(e.target.value as ImageType)
              setFile(null)
              setPreview(null)
              setDetection(null)
            }}
            className="w-full bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2 mt-1"
          >
            {allowedTypes.map((t) => (
              <option key={t} value={t} className="bg-stone text-parchment">
                {TYPE_LABELS[t]}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* File picker */}
      <div>
        <input
          ref={fileRef}
          type="file"
          accept="image/png"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0]
            if (f) handleFileSelect(f)
            e.target.value = ''
          }}
        />
        <Button
          variant="outline"
          size="sm"
          onClick={() => fileRef.current?.click()}
          className="w-full border-stone-light/30 text-parchment/70 hover:text-gold"
        >
          <Upload className="size-3.5 mr-1.5" />
          {file ? file.name : 'Choose file...'}
        </Button>
      </div>

      {/* Preview */}
      {preview && (
        <div className="rounded-lg bg-stone-light/10 border border-stone-light/20 p-2 flex items-center justify-center">
          <img
            src={preview}
            alt="Preview"
            className="max-h-40 object-contain"
            style={{ imageRendering: 'pixelated' }}
          />
        </div>
      )}

      {/* Animation fields */}
      {isAnimation && file && (
        <div className="space-y-2 border border-stone-light/20 rounded-lg p-3 bg-stone/20">
          <div>
            <Label className="text-parchment/60 text-xs">Animation Name</Label>
            <Input
              value={animName}
              onChange={(e) => setAnimName(e.target.value.replace(/[^a-z0-9_-]/gi, '_').toLowerCase())}
              placeholder="e.g. idle, walk, attack"
              className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
            />
          </div>

          <div className="flex gap-2">
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Frame W</Label>
              <Input
                type="number"
                value={frameWidth}
                onChange={(e) => setFrameWidth(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Frame H</Label>
              <Input
                type="number"
                value={frameHeight}
                onChange={(e) => setFrameHeight(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
          </div>

          <div className="flex gap-2">
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Columns</Label>
              <Input
                type="number"
                value={columns}
                onChange={(e) => setColumns(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Rows</Label>
              <Input
                type="number"
                value={rows}
                onChange={(e) => setRows(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Frames</Label>
              <Input
                type="number"
                value={frameCount}
                onChange={(e) => setFrameCount(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
          </div>

          <div className="flex gap-2 items-end">
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">FPS</Label>
              <Input
                type="number"
                value={fps}
                onChange={(e) => setFps(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <label className="flex items-center gap-1.5 pb-1 cursor-pointer">
              <input
                type="checkbox"
                checked={loop}
                onChange={(e) => setLoop(e.target.checked)}
                className="rounded border-stone-light/30"
              />
              <span className="text-xs text-parchment/60">Loop</span>
            </label>
          </div>

          {/* Auto-detect button */}
          <Button
            variant="outline"
            size="sm"
            onClick={handleAnalyze}
            disabled={analyzing || !animName.trim()}
            className="w-full border-stone-light/30 text-parchment/70 hover:text-gold"
          >
            {analyzing ? (
              <><Loader2 className="size-3.5 mr-1.5 animate-spin" />Analyzing...</>
            ) : (
              'Auto-detect grid (Gemini)'
            )}
          </Button>

          {detection && (
            <p className="text-xs text-parchment/40">
              {detection.detected
                ? `Gemini detected grid with ${(detection.confidence * 100).toFixed(0)}% confidence`
                : 'Auto-detection unavailable. Using dimension-based fallback.'}
            </p>
          )}
        </div>
      )}

      {/* Upload button */}
      {file && (
        <Button
          onClick={handleUpload}
          disabled={uploading || (isAnimation && !animName.trim())}
          className="w-full bg-gold/20 text-gold hover:bg-gold/30 border border-gold/30"
        >
          {uploading ? (
            <><Loader2 className="size-3.5 mr-1.5 animate-spin" />Uploading...</>
          ) : (
            <><Upload className="size-3.5 mr-1.5" />{isAnimation ? 'Upload & Generate .tres' : 'Upload'}</>
          )}
        </Button>
      )}
    </div>
  )
}
```

**Step 2: Verify TypeScript compiles**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend && npx tsc --noEmit 2>&1 | head -20`

**Step 3: Commit**

```bash
git add web/frontend/src/components/ImageUpload.tsx
git commit -m "feat: add reusable ImageUpload component with animation support"
```

---

### Task 7: Integrate ImageUpload into CreatureForm

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureForm.tsx`

**Step 1: Replace hardcoded sprite uploads with ImageUpload**

Replace the sprite upload section in `CreatureForm.tsx` (lines 92-153, the `{form.npc_sprite ? ... : ...}` block). The existing `uploadSprite` function (lines 54-67), `downloadSprite` function (lines 69-76), and upload refs (lines 31-32) can be removed and replaced with the `ImageUpload` component.

Key changes:
1. Import `ImageUpload` from `@/components/ImageUpload`
2. Remove `owUploadRef`, `btUploadRef`, `uploadSprite`, `downloadSprite`
3. Replace the sprite preview section with:
   - For NPCs: keep the existing NPC sprite display
   - For creatures: show overworld and battle image thumbnails with download buttons, plus an `ImageUpload` component for uploading new sprites
4. Add an "Animations" card section below the existing cards that shows:
   - List of existing animations (from `assetsApi.listAnimations`)
   - An `ImageUpload` component for adding new animations

The sprite preview thumbnails at the top should remain (showing current overworld/battle sprites), but the upload mechanism changes to use `ImageUpload` in a dialog or inline section.

Replace the header sprite section (the `<div className="flex items-start gap-6">` block, lines 92-175) with:

```tsx
{/* Header with sprites */}
<div className="flex items-start gap-6">
  {form.npc_sprite ? (
    /* NPC sprite — unchanged */
    <div className="flex flex-col items-center gap-1">
      <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
        <img
          key={`npc-${spriteRev}`}
          src={`${BASE}/assets/thumbnail/${form.npc_sprite.replace('res://', '')}?size=128&v=${spriteRev}`}
          alt={form.name}
          className="size-20 object-contain"
          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
        />
      </div>
      <span className="text-[10px] text-parchment/40">Sprite</span>
    </div>
  ) : (
    <>
      {/* Overworld sprite */}
      <div className="flex flex-col items-center gap-1">
        <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
          <img
            key={`ow-${spriteRev}`}
            src={`${BASE}/assets/thumbnail/${spritePath(id)}?size=128&v=${spriteRev}`}
            alt={`${form.name} overworld`}
            className="size-20 object-contain"
            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
          />
        </div>
        <span className="text-[10px] text-parchment/40">Overworld</span>
      </div>

      {/* Battle sprite */}
      <div className="flex flex-col items-center gap-1">
        <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
          <img
            key={`bt-${spriteRev}`}
            src={`${BASE}/assets/thumbnail/${spritePath(id, 'battle')}?size=128&v=${spriteRev}`}
            alt={`${form.name} battle`}
            className="size-20 object-contain"
            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
          />
        </div>
        <span className="text-[10px] text-parchment/40">Battle</span>
      </div>
    </>
  )}

  <span className="text-xs text-parchment/40 font-mono mt-auto">{id}</span>
  <div className="flex-1 space-y-3">
    <div>
      <Label className="text-parchment/60">Name</Label>
      <Input
        value={form.name}
        onChange={(e) => update({ name: e.target.value })}
        className="bg-stone/50 border-stone-light/30 text-parchment font-heading text-lg"
      />
    </div>
    <div>
      <Label className="text-parchment/60">Description</Label>
      <Textarea
        value={form.description}
        onChange={(e) => update({ description: e.target.value })}
        rows={2}
        className="bg-stone/50 border-stone-light/30 text-parchment resize-none"
      />
    </div>
  </div>
</div>
```

Then add a new Sprites & Animations card after the "Types & class" section:

```tsx
{/* Sprites & Animations */}
<Card className="bg-stone/30 border-stone-light/30">
  <CardHeader className="pb-2">
    <CardTitle className="text-gold font-heading text-base">Sprites & Animations</CardTitle>
  </CardHeader>
  <CardContent>
    <div className="space-y-4">
      {/* Character sprite uploads */}
      {!form.npc_sprite && (
        <div className="grid grid-cols-2 gap-4">
          <div>
            <Label className="text-parchment/60 text-xs mb-2 block">Overworld Sprite</Label>
            <ImageUpload
              allowedTypes={['character']}
              entityId={id}
              variant="overworld"
              onUpload={() => setSpriteRev((r) => r + 1)}
            />
          </div>
          <div>
            <Label className="text-parchment/60 text-xs mb-2 block">Battle Sprite</Label>
            <ImageUpload
              allowedTypes={['character']}
              entityId={id}
              variant="battle"
              onUpload={() => setSpriteRev((r) => r + 1)}
            />
          </div>
        </div>
      )}

      <Separator className="bg-stone-light/30" />

      {/* Animation uploads */}
      <div>
        <Label className="text-parchment/60 text-xs mb-2 block">Add Animation</Label>
        <ImageUpload
          allowedTypes={['sprite2d', 'player']}
          entityId={id}
          onUpload={() => setSpriteRev((r) => r + 1)}
        />
      </div>

      {/* List existing animations */}
      <AnimationList creatureId={id} rev={spriteRev} />
    </div>
  </CardContent>
</Card>
```

Add an `AnimationList` component at the bottom of the file:

```tsx
function AnimationList({ creatureId, rev }: { creatureId: string; rev: number }) {
  const [animations, setAnimations] = useState<AnimationInfo[]>([])

  useEffect(() => {
    assetsApi.listAnimations(creatureId).then(setAnimations).catch(() => setAnimations([]))
  }, [creatureId, rev])

  if (animations.length === 0) return null

  return (
    <div className="space-y-2">
      <Label className="text-parchment/60 text-xs">Existing Animations</Label>
      {animations.map((anim) => (
        <div
          key={anim.name}
          className="flex items-center gap-3 rounded-md border border-stone-light/20 bg-stone/20 px-3 py-2"
        >
          <div className="size-10 rounded bg-stone-light/10 border border-stone-light/20 flex items-center justify-center overflow-hidden">
            <img
              src={assetsApi.thumbnailUrl(
                `assets/sprites/creatures/${creatureId}/${anim.name}/spritesheet.png`,
                64,
              )}
              alt={anim.name}
              className="size-8 object-contain"
              style={{ imageRendering: 'pixelated' }}
              onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
            />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm text-parchment font-mono">{anim.name}</p>
            <p className="text-xs text-parchment/40">
              {anim.meta.frame_count} frames, {anim.meta.fps} FPS, {anim.meta.frame_width}x{anim.meta.frame_height}px
              {anim.meta.loop ? ', loop' : ''}
            </p>
          </div>
          <span className={`text-xs ${anim.has_tres ? 'text-green-400' : 'text-amber-400'}`}>
            {anim.has_tres ? '.tres' : 'no .tres'}
          </span>
        </div>
      ))}
    </div>
  )
}
```

**Step 2: Update imports at top of CreatureForm.tsx**

Add:
```typescript
import ImageUpload from '@/components/ImageUpload'
import { type AnimationInfo, assetsApi } from '@/api/assets'
```

Remove unused imports: `Upload`, `Download` (from lucide-react) — only if no longer used elsewhere in the file.

Remove the `owUploadRef` and `btUploadRef` refs, the `uploadSprite` function, and the `downloadSprite` function since they're replaced by `ImageUpload`.

**Step 3: Verify TypeScript compiles**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend && npx tsc --noEmit 2>&1 | head -20`

**Step 4: Verify the app renders**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend && npm run build 2>&1 | tail -5`

**Step 5: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureForm.tsx
git commit -m "feat: integrate ImageUpload component into CreatureForm"
```

---

### Task 8: Manual testing and verification

**Step 1: Start the backend**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web && PYTHONPATH=. .venv/bin/uvicorn backend.app:app --reload --port 8000`

**Step 2: Start the frontend**

Run: `cd /Users/gordon/Documents/Tyrell/monster-game/web/frontend && npm run dev`

**Step 3: Test character image upload**

1. Open the web editor and select a creature
2. In the "Sprites & Animations" card, upload a character image for overworld
3. Verify it gets resized and background-removed as before

**Step 4: Test animation upload**

1. Select "Animation (Sprite 2D)" from the type dropdown
2. Upload a sprite sheet PNG
3. Enter an animation name (e.g., "idle")
4. Click "Auto-detect grid (Gemini)" if Gemini key is configured
5. Adjust frame dimensions if needed
6. Click "Upload & Generate .tres"
7. Verify the folder structure was created:
   ```
   assets/sprites/creatures/{creature_id}/idle/
   ├── spritesheet.png
   ├── metadata.json
   └── idle.tres
   ```

**Step 5: Verify .tres file is valid Godot format**

Open the generated `.tres` file and check:
- Has proper `[gd_resource]` header
- ExtResource references the sprite sheet
- SubResources have correct Rect2 regions
- Animation data has correct frame count, FPS, loop settings

**Step 6: Test the animation list**

After uploading, verify the animation appears in the "Existing Animations" section with correct metadata.

**Step 7: Commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```
