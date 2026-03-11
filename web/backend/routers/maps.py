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
