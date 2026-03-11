import shutil
from pathlib import Path

import pytest

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
