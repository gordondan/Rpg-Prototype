import argparse
from pathlib import Path

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
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
    # Serve static assets (JS, CSS, images) directly
    app.mount("/assets", StaticFiles(directory=str(frontend_build / "assets")), name="static-assets")

    # SPA catch-all: serve index.html for all non-API routes
    @app.get("/{path:path}")
    async def serve_spa(request: Request, path: str):
        # If path points to an actual file in dist, serve it
        file_path = frontend_build / path
        if file_path.is_file():
            return FileResponse(file_path)
        # Otherwise serve index.html for SPA routing
        return FileResponse(frontend_build / "index.html")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    uvicorn.run("backend.app:app", host=args.host, port=args.port, reload=True)
