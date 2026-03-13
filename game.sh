#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find Godot executable
if command -v godot &>/dev/null; then
    GODOT=godot
elif [ -d "/Applications/Godot.app" ]; then
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
    echo "Error: Godot not found. Install Godot or add it to your PATH." >&2
    exit 1
fi

exec "$GODOT" --path "$PROJECT_DIR"
