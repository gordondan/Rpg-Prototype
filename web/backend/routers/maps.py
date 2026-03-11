from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService

router = APIRouter(prefix="/api/maps", tags=["maps"])
data_svc = DataService()


@router.get("/")
def list_maps():
    return data_svc.get_all_maps()


@router.put("/{map_id}")
def update_map(map_id: str, body: dict):
    if not data_svc.update_map(map_id, body):
        raise HTTPException(404, f"Map '{map_id}' not found")
    return {"status": "updated", "map_id": map_id}
