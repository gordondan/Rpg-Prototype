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
        ".webp": "image/webp", ".mp3": "audio/mpeg", ".ogg": "audio/ogg", ".wav": "audio/wav",
    }
    return Response(
        content=full_path.read_bytes(),
        media_type=media_types.get(suffix, "application/octet-stream"),
    )


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


@router.post("/reprocess-sprites")
def reprocess_sprites():
    count = asset_svc.reprocess_all_sprites()
    return {"status": "reprocessed", "count": count}


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
