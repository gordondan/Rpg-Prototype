import shutil
from io import BytesIO
from pathlib import Path

import pytest
from PIL import Image

from backend.services.asset_service import AssetService

REPO = Path(__file__).parent.parent.parent


@pytest.fixture
def asset_service(tmp_path):
    assets_dest = tmp_path / "assets" / "sprites" / "creatures"
    assets_dest.mkdir(parents=True)
    src = REPO / "assets" / "sprites" / "creatures"
    for f in list(src.glob("*_battle.png"))[:3]:
        shutil.copy2(f, assets_dest / f.name)
    (tmp_path / "web").mkdir()
    return AssetService(repo_path=tmp_path)


def test_list_assets(asset_service):
    assets = asset_service.list_assets("creatures")
    assert len(assets) >= 1
    assert all(a.category == "creatures" for a in assets)


def test_set_and_get_status(asset_service):
    asset_service.set_asset_status("assets/sprites/creatures/test.png", "deprecated", "old art")
    meta = asset_service.get_asset_status("assets/sprites/creatures/test.png")
    assert meta["status"] == "deprecated"
    assert meta["notes"] == "old art"


def _make_png(width: int, height: int) -> bytes:
    img = Image.new("RGBA", (width, height), (255, 0, 0, 255))
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _make_jpeg(width: int, height: int) -> bytes:
    img = Image.new("RGB", (width, height), (0, 255, 0))
    buf = BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_process_sprite_resizes_large_image(asset_service):
    content = _make_png(1024, 1024)
    rel_path = "assets/sprites/creatures/test_creature.png"
    asset_service.process_sprite(rel_path, content)

    game_path = asset_service.repo_path / rel_path
    assert game_path.exists()
    with Image.open(game_path) as img:
        assert img.width <= 128
        assert img.height <= 128

    original_path = asset_service.repo_path / "assets/sprites/creatures/original/test_creature.png"
    assert original_path.exists()
    with Image.open(original_path) as img:
        assert img.width == 1024


def test_process_sprite_converts_jpeg_to_png(asset_service):
    content = _make_jpeg(512, 256)
    rel_path = "assets/sprites/creatures/test_creature.png"
    asset_service.process_sprite(rel_path, content)

    game_path = asset_service.repo_path / rel_path
    assert game_path.exists()
    with Image.open(game_path) as img:
        assert img.format == "PNG"
        assert img.width <= 128

    original_path = asset_service.repo_path / "assets/sprites/creatures/original/test_creature.png"
    assert original_path.exists()


def test_process_sprite_small_image_unchanged(asset_service):
    content = _make_png(64, 64)
    rel_path = "assets/sprites/creatures/tiny.png"
    asset_service.process_sprite(rel_path, content)

    game_path = asset_service.repo_path / rel_path
    with Image.open(game_path) as img:
        assert img.width == 64
        assert img.height == 64

    original_path = asset_service.repo_path / "assets/sprites/creatures/original/tiny.png"
    assert original_path.exists()
