from pathlib import Path

import pytest
from git import Repo

from backend.services.git_service import GitService


@pytest.fixture
def git_service(tmp_path):
    repo = Repo.init(tmp_path)
    readme = tmp_path / "README.md"
    readme.write_text("test repo")
    repo.index.add(["README.md"])
    repo.index.commit("initial commit")
    return GitService(repo_path=tmp_path)


def test_has_no_changes(git_service):
    assert not git_service.has_changes()


def test_has_changes_after_edit(git_service):
    (git_service.repo_path / "README.md").write_text("modified")
    assert git_service.has_changes()


def test_stage_and_commit(git_service):
    new_file = git_service.repo_path / "test.txt"
    new_file.write_text("hello")
    sha = git_service.stage_and_commit(["test.txt"], "add test file")
    assert len(sha) == 40
    assert not git_service.has_changes()


def test_get_history(git_service):
    history = git_service.get_history()
    assert len(history) == 1
    assert history[0].message == "initial commit"


def test_get_diff(git_service):
    (git_service.repo_path / "README.md").write_text("changed")
    diff = git_service.get_diff()
    assert "changed" in diff
