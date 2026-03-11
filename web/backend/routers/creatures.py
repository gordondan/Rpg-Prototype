from fastapi import APIRouter, HTTPException

from backend.services.data_service import DataService
from backend.services.git_service import GitService

router = APIRouter(prefix="/api/creatures", tags=["creatures"])
data_svc = DataService()
git_svc = GitService()


@router.get("/")
def list_creatures():
    return data_svc.get_all_creatures()


@router.get("/auto-match-sprites")
def auto_match_sprites():
    return data_svc.auto_match_sprites()


@router.post("/apply-sprite-matches")
def apply_sprite_matches(body: dict):
    count = data_svc.apply_sprite_matches(body.get("matches", {}))
    return {"status": "applied", "updated_count": count}


@router.get("/{creature_id}")
def get_creature(creature_id: str):
    creature = data_svc.get_creature(creature_id)
    if not creature:
        raise HTTPException(404, f"Creature '{creature_id}' not found")
    return creature


@router.put("/{creature_id}")
def update_creature(creature_id: str, body: dict):
    if not data_svc.get_creature(creature_id):
        raise HTTPException(404, f"Creature '{creature_id}' not found")
    data_svc.update_creature(creature_id, body)
    return {"status": "updated", "creature_id": creature_id}
