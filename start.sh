#!/usr/bin/env bash
# Start the MonsterQuest web editor and open it in Chrome.
# Works on macOS, Linux, and Windows (Git Bash / WSL).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8000}"
URL="http://127.0.0.1:${PORT}/editor/creatures"

export REPO_PATH="$SCRIPT_DIR"

# ---------- helpers ----------

open_browser() {
  # Give the server a moment to start
  sleep 2
  case "$(uname -s)" in
    Darwin)
      open -a "Google Chrome" "$URL" 2>/dev/null || open "$URL"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      # Git Bash / MSYS2 on Windows
      cmd.exe /c start chrome "$URL" 2>/dev/null || start "$URL" 2>/dev/null || true
      ;;
    *)
      # Linux
      google-chrome "$URL" 2>/dev/null \
        || google-chrome-stable "$URL" 2>/dev/null \
        || xdg-open "$URL" 2>/dev/null \
        || true
      ;;
  esac
}

# ---------- build frontend if needed ----------

if [ ! -f "$SCRIPT_DIR/web/frontend/dist/index.html" ]; then
  echo "Building frontend..."
  cd "$SCRIPT_DIR/web/frontend"
  npm install
  npm run build
fi

# ---------- set up Python venv if needed ----------

VENV="$SCRIPT_DIR/web/.venv"

if [ ! -d "$VENV" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -r "$SCRIPT_DIR/web/requirements.txt"
fi

# ---------- kill existing server on this port ----------

PID=$(lsof -ti :"$PORT" 2>/dev/null || true)
if [ -n "$PID" ]; then
  echo "Killing existing process on port $PORT (PID $PID)"
  kill "$PID" 2>/dev/null || true
  sleep 1
fi

# ---------- start server ----------

echo "Starting MonsterQuest editor at $URL"

open_browser &

cd "$SCRIPT_DIR/web"
export PYTHONPATH="$SCRIPT_DIR/web"
"$VENV/bin/python" backend/app.py --host 127.0.0.1 --port "$PORT"
