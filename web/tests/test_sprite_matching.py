import shutil
from pathlib import Path

import pytest

from backend.services.data_service import DataService

REPO = Path(__file__).parent.parent.parent


@pytest.fixture
def data_service(tmp_path):
    shutil.copytree(REPO / "data", tmp_path / "data")
    sprites_dir = tmp_path / "assets" / "sprites" / "creatures"
    sprites_dir.mkdir(parents=True)
    src = REPO / "assets" / "sprites" / "creatures"
    for name in ["Flame_Squire.png", "flame_squire_battle.png", "Goblin_Basic.png", "goblin_battle.png"]:
        src_file = src / name
        if src_file.exists():
            shutil.copy2(src_file, sprites_dir / name)
    return DataService(repo_path=tmp_path)


def test_auto_match_finds_sprites(data_service):
    matches = data_service.auto_match_sprites()
    assert "flame_squire" in matches
    assert matches["flame_squire"]["battle"] is not None
    assert "battle" in matches["flame_squire"]["battle"]
    assert matches["flame_squire"]["overworld"] is not None


def test_auto_match_goblin(data_service):
    matches = data_service.auto_match_sprites()
    assert "goblin" in matches
    assert matches["goblin"]["battle"] is not None


def test_apply_sprite_matches(data_service):
    matches = data_service.auto_match_sprites()
    count = data_service.apply_sprite_matches(matches)
    assert count >= 2
    creature = data_service.get_creature("flame_squire")
    assert creature["sprite_battle"] is not None
