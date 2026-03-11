from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService

router = APIRouter(prefix="/api/items", tags=["items"])
data_svc = DataService()


@router.get("/")
def list_items():
    return data_svc.get_all_items()


@router.put("/{item_id}")
def update_item(item_id: str, body: dict):
    data_svc.update_item(item_id, body)
    return {"status": "updated", "item_id": item_id}
