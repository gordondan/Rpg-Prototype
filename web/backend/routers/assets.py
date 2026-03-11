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
