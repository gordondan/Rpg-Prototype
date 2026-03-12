import json
import shutil
from pathlib import Path

import pytest

from backend.services.data_service import DataService

REPO = Path(__file__).parent.parent.parent


@pytest.fixture
def data_service(tmp_path):
    """Copy real data to temp dir for isolated testing."""
    data_dest = tmp_path / "data"
    shutil.copytree(REPO / "data", data_dest)
    return DataService(repo_path=tmp_path)


def test_get_all_creatures(data_service):
    creatures = data_service.get_all_creatures()
    assert "flame_squire" in creatures
    assert "spark_thief" in creatures
    assert len(creatures) > 10


def test_get_creature(data_service):
    c = data_service.get_creature("flame_squire")
    assert c is not None
    assert c["name"] == "Flame Squire"


def test_update_creature(data_service):
    c = data_service.get_creature("flame_squire")
    c["base_hp"] = 999
    data_service.update_creature("flame_squire", c)
    updated = data_service.get_creature("flame_squire")
    assert updated["base_hp"] == 999


def test_get_all_moves(data_service):
    moves = data_service.get_all_moves()
    assert "sword_strike" in moves


def test_get_all_items(data_service):
    items = data_service.get_all_items()
    assert "healing_potion" in items


def test_get_all_maps(data_service):
    maps = data_service.get_all_maps()
    assert "route_1" in maps
    assert maps["route_1"]["name"] == "The King's Road"


def test_get_all_shops(data_service):
    shops = data_service.get_all_shops()
    assert "village_merchant" in shops


def test_create_map(data_service):
    result = data_service.create_map("test_map", {"name": "Test", "description": "A test map", "encounters": []})
    assert result is True
    maps = data_service.get_all_maps()
    assert "test_map" in maps


def test_create_map_duplicate(data_service):
    assert data_service.create_map("route_1", {"name": "Dup"}) is False


def test_delete_map(data_service):
    data_service.create_map("to_delete", {"name": "Del", "description": "", "encounters": []})
    assert data_service.delete_map("to_delete") is True
    assert "to_delete" not in data_service.get_all_maps()


def test_delete_map_not_found(data_service):
    assert data_service.delete_map("nonexistent") is False


def test_create_creature(data_service):
    result = data_service.create_creature("test_creature", {
        "name": "Test", "description": "", "types": ["normal"],
        "base_hp": 1, "base_attack": 1, "base_defense": 1,
        "base_sp_attack": 1, "base_sp_defense": 1, "base_speed": 1,
        "base_exp": 1, "class": "monster", "category": "wild", "learnset": [],
    })
    assert result is True
    assert "test_creature" in data_service.get_all_creatures()


def test_create_creature_duplicate(data_service):
    assert data_service.create_creature("flame_squire", {"name": "Dup"}) is False


def test_delete_creature(data_service):
    data_service.create_creature("to_delete", {
        "name": "Del", "description": "", "types": ["normal"],
        "base_hp": 1, "base_attack": 1, "base_defense": 1,
        "base_sp_attack": 1, "base_sp_defense": 1, "base_speed": 1,
        "base_exp": 1, "class": "monster", "category": "wild", "learnset": [],
    })
    assert data_service.delete_creature("to_delete") is True
    assert "to_delete" not in data_service.get_all_creatures()


def test_delete_creature_not_found(data_service):
    assert data_service.delete_creature("nonexistent") is False
