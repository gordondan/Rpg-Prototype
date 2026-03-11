from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService

router = APIRouter(prefix="/api/moves", tags=["moves"])
data_svc = DataService()


@router.get("/")
def list_moves():
    return data_svc.get_all_moves()


@router.get("/{move_id}")
def get_move(move_id: str):
    move = data_svc.get_move(move_id)
    if not move:
        raise HTTPException(404, f"Move '{move_id}' not found")
    return move


@router.put("/{move_id}")
def update_move(move_id: str, body: dict):
    data_svc.update_move(move_id, body)
    return {"status": "updated", "move_id": move_id}
