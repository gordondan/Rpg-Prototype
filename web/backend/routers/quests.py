from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService

router = APIRouter(prefix="/api/quests", tags=["quests"])
data_svc = DataService()


@router.get("/")
def list_quests():
    return data_svc.get_all_quests()


@router.get("/{quest_id}")
def get_quest(quest_id: str):
    quest = data_svc.get_quest(quest_id)
    if not quest:
        raise HTTPException(404, f"Quest '{quest_id}' not found")
    return quest


@router.post("/")
def create_quest(body: dict):
    quest_id = body.pop("id", None)
    if not quest_id:
        raise HTTPException(400, "Missing 'id' field")
    if not data_svc.create_quest(quest_id, body):
        raise HTTPException(409, f"Quest '{quest_id}' already exists")
    return {"status": "created", "quest_id": quest_id}


@router.put("/{quest_id}")
def update_quest(quest_id: str, body: dict):
    if not data_svc.update_quest(quest_id, body):
        raise HTTPException(404, f"Quest '{quest_id}' not found")
    return {"status": "updated", "quest_id": quest_id}


@router.delete("/{quest_id}")
def delete_quest(quest_id: str):
    if not data_svc.delete_quest(quest_id):
        raise HTTPException(404, f"Quest '{quest_id}' not found")
    return {"status": "deleted", "quest_id": quest_id}
