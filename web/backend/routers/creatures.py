from fastapi import APIRouter, HTTPException

from backend.config import settings
from backend.services.data_service import DataService
from backend.services.git_service import GitService

router = APIRouter(prefix="/api/creatures", tags=["creatures"])
data_svc = DataService()
git_svc = GitService()


@router.get("/")
def list_creatures():
    creatures = data_svc.get_all_creatures()
    sprites_dir = settings.repo_path / "assets" / "sprites" / "creatures"
    for cid, cdata in creatures.items():
        cdata["has_overworld_sprite"] = (sprites_dir / f"{cid}.png").exists()
        cdata["has_battle_sprite"] = (sprites_dir / f"{cid}_battle.png").exists()
    return creatures


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


@router.post("/")
def create_creature():
    all_creatures = data_svc.get_all_creatures()
    n = 1
    while f"new_creature_{n}" in all_creatures:
        n += 1
    creature_id = f"new_creature_{n}"

    creature_data = {
        "name": "New Creature",
        "description": "",
        "types": ["normal"],
        "base_hp": 50,
        "base_attack": 50,
        "base_defense": 50,
        "base_sp_attack": 50,
        "base_sp_defense": 50,
        "base_speed": 50,
        "base_exp": 50,
        "class": "monster",
        "category": "wild",
        "learnset": [],
    }
    data_svc.create_creature(creature_id, creature_data)
    return {"status": "created", "creature_id": creature_id}


@router.delete("/{creature_id}")
def delete_creature(creature_id: str):
    if not data_svc.delete_creature(creature_id):
        raise HTTPException(404, f"Creature '{creature_id}' not found")
    return {"status": "deleted", "creature_id": creature_id}
