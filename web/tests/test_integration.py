"""End-to-end integration tests for the MonsterQuest Asset Browser API."""

import json
import os
import shutil
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from git import Repo

# Set REPO_PATH before importing app
REPO = Path(__file__).parent.parent.parent  # monster-game root


@pytest.fixture
def test_repo(tmp_path):
    """Create a temporary git repo with real game data for integration testing."""
    # Copy data directory
    shutil.copytree(REPO / "data", tmp_path / "data")

    # Copy a few asset sprites for testing
    creatures_src = REPO / "assets" / "sprites" / "creatures"
    creatures_dest = tmp_path / "assets" / "sprites" / "creatures"
    creatures_dest.mkdir(parents=True)
    for f in list(creatures_src.glob("*.png"))[:5]:
        shutil.copy2(f, creatures_dest / f.name)

    # Create web dir for metadata
    (tmp_path / "web").mkdir()

    # Init git repo
    repo = Repo.init(tmp_path)
    repo.index.add([str(p.relative_to(tmp_path)) for p in tmp_path.rglob("*") if p.is_file()])
    repo.index.commit("initial commit")

    return tmp_path


@pytest.fixture
def client(test_repo, monkeypatch):
    """Create a FastAPI test client pointing at the temp repo."""
    monkeypatch.setenv("REPO_PATH", str(test_repo))

    # Re-import to pick up the new REPO_PATH
    from backend.config import Settings
    test_settings = Settings(repo_path=test_repo)

    # Patch the services to use test settings
    from backend.services import data_service, git_service, asset_service
    from backend import config
    monkeypatch.setattr(config, "settings", test_settings)

    # Recreate services with the test repo path
    from backend.routers import creatures, moves, items, maps, shops, assets, git_ops
    creatures.data_svc = data_service.DataService(repo_path=test_repo)
    moves.data_svc = data_service.DataService(repo_path=test_repo)
    items.data_svc = data_service.DataService(repo_path=test_repo)
    maps.data_svc = data_service.DataService(repo_path=test_repo)
    shops.data_svc = data_service.DataService(repo_path=test_repo)
    assets.asset_svc = asset_service.AssetService(repo_path=test_repo)
    assets.git_svc = git_service.GitService(repo_path=test_repo)
    git_ops.git_svc = git_service.GitService(repo_path=test_repo)
    creatures.git_svc = git_service.GitService(repo_path=test_repo)

    from backend.app import app
    return TestClient(app)


def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_list_creatures(client):
    r = client.get("/api/creatures/")
    assert r.status_code == 200
    data = r.json()
    assert "flame_squire" in data
    assert len(data) > 10


def test_get_creature(client):
    r = client.get("/api/creatures/flame_squire")
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Flame Squire"
    assert "fire" in data["types"]


def test_get_creature_not_found(client):
    r = client.get("/api/creatures/nonexistent")
    assert r.status_code == 404


def test_update_creature(client):
    # Get original
    r = client.get("/api/creatures/flame_squire")
    creature = r.json()
    original_hp = creature["base_hp"]

    # Update
    creature["base_hp"] = 999
    r = client.put("/api/creatures/flame_squire", json=creature)
    assert r.status_code == 200

    # Verify update persisted
    r = client.get("/api/creatures/flame_squire")
    assert r.json()["base_hp"] == 999


def test_list_moves(client):
    r = client.get("/api/moves/")
    assert r.status_code == 200
    data = r.json()
    assert len(data) > 0


def test_list_items(client):
    r = client.get("/api/items/")
    assert r.status_code == 200
    data = r.json()
    assert len(data) > 0


def test_list_maps(client):
    r = client.get("/api/maps/")
    assert r.status_code == 200
    data = r.json()
    assert "route_1" in data


def test_list_shops(client):
    r = client.get("/api/shops/")
    assert r.status_code == 200
    data = r.json()
    assert len(data) > 0


def test_list_assets(client):
    r = client.get("/api/assets/?category=creatures")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


def test_git_status(client):
    r = client.get("/api/git/status")
    assert r.status_code == 200
    data = r.json()
    assert "has_changes" in data
    assert "changed_files" in data


def test_git_history(client):
    r = client.get("/api/git/history")
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    assert data[0]["message"] == "initial commit"


def test_full_edit_and_commit_flow(client):
    """Test the complete edit → save → commit flow."""
    # 1. Verify no changes initially
    r = client.get("/api/git/status")
    assert r.json()["has_changes"] is False

    # 2. Edit a creature
    r = client.get("/api/creatures/flame_squire")
    creature = r.json()
    creature["base_hp"] = 777
    r = client.put("/api/creatures/flame_squire", json=creature)
    assert r.status_code == 200

    # 3. There should be changes now
    r = client.get("/api/git/status")
    assert r.json()["has_changes"] is True

    # 4. Commit
    r = client.post("/api/git/commit", json={"message": "Update Flame Squire HP"})
    assert r.status_code == 200
    assert "sha" in r.json()

    # 5. No changes after commit
    r = client.get("/api/git/status")
    assert r.json()["has_changes"] is False

    # 6. History should have the new commit
    r = client.get("/api/git/history")
    history = r.json()
    assert history[0]["message"] == "Update Flame Squire HP"
