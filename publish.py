#!/usr/bin/env python3
"""
publish.py - Build and deploy MonstaQuest via Docker Compose.

Usage:
    python publish.py              # Export game, build and run (default)
    python publish.py export       # Export Godot game for web only
    python publish.py build        # Build images only
    python publish.py run          # Start existing images
    python publish.py stop         # Stop all containers
    python publish.py logs         # Tail container logs
    python publish.py status       # Show container status
"""

import os
import sys
import subprocess
from pathlib import Path

# Resolve paths
SCRIPT_DIR = Path(__file__).resolve().parent
COMPOSE_FILE = SCRIPT_DIR / "web" / "docker-compose.yml"
REPO_PATH = SCRIPT_DIR

# Colors
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
RED = "\033[0;31m"
RESET = "\033[0m"


def log(msg):
    print(f"{CYAN}[publish]{RESET} {msg}")


def ok(msg):
    print(f"{GREEN}[publish]{RESET} {msg}")


def err(msg):
    print(f"{RED}[publish]{RESET} {msg}", file=sys.stderr)


GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"
GAME_OUTPUT = SCRIPT_DIR / "web" / "game"


def export_game():
    """Export Godot project to web format."""
    if not Path(GODOT_BIN).exists():
        err(f"Godot not found at {GODOT_BIN}")
        err("Install Godot 4.6+ or update GODOT_BIN path.")
        sys.exit(1)

    log("Exporting game for web...")
    GAME_OUTPUT.mkdir(parents=True, exist_ok=True)
    output_file = GAME_OUTPUT / "index.html"
    result = subprocess.run(
        [GODOT_BIN, "--headless", "--export-release", "Web", str(output_file)],
        cwd=str(SCRIPT_DIR),
    )
    if result.returncode != 0:
        err("Game export failed.")
        sys.exit(result.returncode)
    ok("Game exported successfully.")


def compose(*args):
    """Run docker compose with the project compose file and resolved REPO_PATH."""
    env = os.environ.copy()
    env["REPO_PATH"] = str(REPO_PATH)
    cmd = ["docker", "compose", "-f", str(COMPOSE_FILE), *args]
    return subprocess.run(cmd, env=env)


def build_images():
    log("Building images...")
    result = compose("build")
    if result.returncode != 0:
        err("Build failed.")
        sys.exit(result.returncode)
    ok("Images built successfully.")


def run_services():
    log("Starting services...")
    result = compose("up", "-d")
    if result.returncode != 0:
        err("Failed to start services.")
        sys.exit(result.returncode)
    ok("Services running.")
    ok("  App:      http://localhost:8080/monsta-quest")
    ok("  Game:     http://localhost:8080/monsta-quest/game/")
    ok("  API docs: http://localhost:8080/monsta-quest/docs")


def stop_services():
    log("Stopping services...")
    result = compose("down")
    if result.returncode != 0:
        err("Failed to stop services.")
        sys.exit(result.returncode)
    ok("Services stopped.")


def show_status():
    compose("ps")


def show_logs():
    try:
        compose("logs", "-f")
    except KeyboardInterrupt:
        pass


ACTIONS = {
    "export": export_game,
    "build": build_images,
    "run": run_services,
    "stop": stop_services,
    "logs": show_logs,
    "status": show_status,
}


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "default"

    if action == "default":
        export_game()
        build_images()
        run_services()
    elif action in ACTIONS:
        ACTIONS[action]()
    else:
        err(f"Unknown action: {action}")
        print(f"Usage: {sys.argv[0]} {{export|build|run|stop|logs|status}}")
        sys.exit(1)


if __name__ == "__main__":
    main()
