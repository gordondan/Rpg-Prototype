import argparse
from pathlib import Path

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from backend.routers import creatures, moves, items, maps, shops, assets, git_ops

app = FastAPI(title="MonsterQuest Asset Browser", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(creatures.router)
app.include_router(moves.router)
app.include_router(items.router)
app.include_router(maps.router)
app.include_router(shops.router)
app.include_router(assets.router)
app.include_router(git_ops.router)


@app.get("/api/health")
def health():
    return {"status": "ok"}


# Serve React build if it exists
frontend_build = Path(__file__).parent.parent / "frontend" / "dist"
if frontend_build.exists():
    app.mount("/", StaticFiles(directory=str(frontend_build), html=True), name="frontend")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    uvicorn.run("backend.app:app", host=args.host, port=args.port, reload=True)
