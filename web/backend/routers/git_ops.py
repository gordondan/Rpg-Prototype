from fastapi import APIRouter, HTTPException

from backend.services.git_service import GitService

router = APIRouter(prefix="/api/git", tags=["git"])
git_svc = GitService()


@router.get("/status")
def get_status():
    return {
        "has_changes": git_svc.has_changes(),
        "changed_files": git_svc.get_changed_files(),
    }


@router.post("/commit")
def commit_changes(body: dict):
    message = body.get("message", "Update via asset browser")
    if not git_svc.has_changes():
        raise HTTPException(400, "No changes to commit")
    sha = git_svc.stage_all_and_commit(message)
    return {"status": "committed", "sha": sha}


@router.get("/history")
def get_history(limit: int = 50):
    commits = git_svc.get_history(max_count=limit)
    return [c.__dict__ for c in commits]


@router.get("/diff")
def get_diff(sha: str | None = None):
    return {"diff": git_svc.get_diff(sha)}


@router.post("/revert/{sha}")
def revert_commit(sha: str):
    try:
        new_sha = git_svc.revert_commit(sha)
        return {"status": "reverted", "new_sha": new_sha}
    except Exception as e:
        raise HTTPException(400, f"Revert failed: {e}")
