from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService

router = APIRouter(prefix="/api/shops", tags=["shops"])
data_svc = DataService()


@router.get("/")
def list_shops():
    return data_svc.get_all_shops()


@router.put("/{shop_id}")
def update_shop(shop_id: str, body: dict):
    data_svc.update_shop(shop_id, body)
    return {"status": "updated", "shop_id": shop_id}
