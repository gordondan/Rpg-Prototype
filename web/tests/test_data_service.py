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
