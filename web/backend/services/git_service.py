from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from git import Repo, Actor

from backend.config import settings


@dataclass
class CommitInfo:
    sha: str
    message: str
    author: str
    date: str
    files: list[str]


class GitService:
    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path
        self._repo: Repo | None = None

    @property
    def repo(self) -> Repo:
        if self._repo is None:
            self._repo = Repo(self.repo_path)
        return self._repo

    @property
    def author(self) -> Actor:
        return Actor(settings.git_author_name, settings.git_author_email)

    def has_changes(self) -> bool:
        return self.repo.is_dirty(untracked_files=True)

    def get_changed_files(self) -> list[str]:
        changed = []
        diff = self.repo.index.diff(None)
        for d in diff:
            changed.append(d.a_path)
        for f in self.repo.untracked_files:
            changed.append(f)
        if self.repo.head.is_valid():
            staged = self.repo.index.diff("HEAD")
            for d in staged:
                if d.a_path not in changed:
                    changed.append(d.a_path)
        return changed

    def stage_and_commit(self, files: list[str], message: str) -> str:
        for f in files:
            self.repo.index.add([f])
        commit = self.repo.index.commit(message, author=self.author, committer=self.author)
        return commit.hexsha

    def stage_all_and_commit(self, message: str) -> str:
        self.repo.git.add(A=True)
        commit = self.repo.index.commit(message, author=self.author, committer=self.author)
        return commit.hexsha

    def get_history(self, max_count: int = 50) -> list[CommitInfo]:
        commits = []
        for c in self.repo.iter_commits(max_count=max_count):
            files = list(c.stats.files.keys()) if c.stats.files else []
            commits.append(CommitInfo(
                sha=c.hexsha,
                message=c.message.strip(),
                author=str(c.author),
                date=datetime.fromtimestamp(c.committed_date).isoformat(),
                files=files,
            ))
        return commits

    def get_diff(self, sha: str | None = None) -> str:
        if sha:
            commit = self.repo.commit(sha)
            if commit.parents:
                return self.repo.git.diff(commit.parents[0].hexsha, sha)
            return self.repo.git.diff(sha, "--root")
        return self.repo.git.diff()

    def revert_commit(self, sha: str) -> str:
        self.repo.git.revert(sha, no_edit=True)
        return self.repo.head.commit.hexsha
