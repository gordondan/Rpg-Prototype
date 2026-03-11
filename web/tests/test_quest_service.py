import shutil
from pathlib import Path

import pytest

from backend.services.data_service import DataService

REPO = Path(__file__).parent.parent.parent

SAMPLE_QUEST = {
    "name": "Clear the Road",
    "description": "Help the guard clear goblins.",
    "map_id": "route_1",
    "prerequisite_quest_id": None,
    "reward": {"gold": 500, "items": ["healing_potion"], "exp": 200},
    "stages": [
        {
            "id": "talk_guard",
            "type": "talk_to_npc",
            "description": "Talk to the guard",
            "npc_id": "village_guard",
            "dialogue_id": "quest_start",
        },
        {
            "id": "kill_goblins",
            "type": "defeat_creatures",
            "description": "Defeat 3 goblins",
            "creature_id": "goblin",
            "count": 3,
            "map_id": "route_1",
        },
    ],
}


@pytest.fixture
def data_service(tmp_path):
    shutil.copytree(REPO / "data", tmp_path / "data")
    return DataService(repo_path=tmp_path)


def test_create_quest(data_service):
    assert data_service.create_quest("clear_road", SAMPLE_QUEST) is True
    quest = data_service.get_quest("clear_road")
    assert quest is not None
    assert quest["name"] == "Clear the Road"


def test_create_quest_duplicate(data_service):
    data_service.create_quest("dup", SAMPLE_QUEST)
    assert data_service.create_quest("dup", SAMPLE_QUEST) is False


def test_get_all_quests(data_service):
    data_service.create_quest("q1", SAMPLE_QUEST)
    data_service.create_quest("q2", {**SAMPLE_QUEST, "name": "Quest 2"})
    quests = data_service.get_all_quests()
    assert len(quests) == 2


def test_update_quest(data_service):
    data_service.create_quest("q1", SAMPLE_QUEST)
    updated = {**SAMPLE_QUEST, "name": "Updated Quest"}
    assert data_service.update_quest("q1", updated) is True
    quest = data_service.get_quest("q1")
    assert quest["name"] == "Updated Quest"


def test_update_quest_not_found(data_service):
    assert data_service.update_quest("nonexistent", SAMPLE_QUEST) is False


def test_delete_quest(data_service):
    data_service.create_quest("to_delete", SAMPLE_QUEST)
    assert data_service.delete_quest("to_delete") is True
    assert data_service.get_quest("to_delete") is None


def test_delete_quest_not_found(data_service):
    assert data_service.delete_quest("nonexistent") is False


def test_quest_stages_structure(data_service):
    data_service.create_quest("q1", SAMPLE_QUEST)
    quest = data_service.get_quest("q1")
    assert len(quest["stages"]) == 2
    assert quest["stages"][0]["type"] == "talk_to_npc"
    assert quest["stages"][1]["type"] == "defeat_creatures"
    assert quest["stages"][1]["count"] == 3
