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


@router.post("/")
def create_move():
    all_moves = data_svc.get_all_moves()
    n = 1
    while f"new_move_{n}" in all_moves:
        n += 1
    move_id = f"new_move_{n}"

    move_data = {
        "name": "New Move",
        "type": "normal",
        "category": "physical",
        "power": 40,
        "accuracy": 100,
        "pp": 20,
        "description": "",
    }
    data_svc.create_move(move_id, move_data)
    return {"status": "created", "move_id": move_id}


@router.delete("/{move_id}")
def delete_move(move_id: str):
    if not data_svc.delete_move(move_id):
        raise HTTPException(404, f"Move '{move_id}' not found")
    return {"status": "deleted", "move_id": move_id}
