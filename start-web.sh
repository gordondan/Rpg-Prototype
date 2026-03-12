#!/usr/bin/env bash
# Start the MonsterQuest web editor and open it in Chrome.
# Works on macOS, Linux, and Windows (Git Bash / WSL).

set -e

# On Windows, add Node.js and Python to PATH if not already present
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    export PATH="/c/Program Files/nodejs:$PATH"
      # Add real Python installs before WindowsApps stubs (which open the Store)
    # Prefer newer versions first
    for _pydir in \
      "/c/Users/$USERNAME/AppData/Local/Programs/Python/Python313" \
      "/c/Users/$USERNAME/AppData/Local/Programs/Python/Python312" \
      "/c/Users/$USERNAME/AppData/Local/Programs/Python/Python311" \
      "/c/Users/$USERNAME/AppData/Local/Programs/Python/Python310" \
      "/c/Users/$USERNAME/AppData/Local/Programs/Python/Python39" \
      "/c/Users/$USERNAME/AppData/Local/Programs/Python/Python38-32" \
      "/c/Python313" "/c/Python312" "/c/Python311" "/c/Python310" "/c/Python39"; do
      if [ -f "$_pydir/python.exe" ]; then
        export PATH="$_pydir:$PATH"
        break
      fi
    done
    ;;
esac

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
      # Git Bash / MSYS2 on Windows — open with default browser via cmd
      cmd.exe /c start "" "$URL" 2>/dev/null || true
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

# On Windows (Git Bash) venv uses Scripts/, on Unix it uses bin/
if [ -d "$VENV/Scripts" ]; then
  VENV_BIN="$VENV/Scripts"
else
  VENV_BIN="$VENV/bin"
fi

if [ ! -d "$VENV" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv "$VENV" 2>/dev/null || python -m venv "$VENV"
  # Recheck bin path after creation
  if [ -d "$VENV/Scripts" ]; then VENV_BIN="$VENV/Scripts"; else VENV_BIN="$VENV/bin"; fi
  "$VENV_BIN/pip" install -r "$SCRIPT_DIR/web/requirements.txt"
fi

# ---------- kill existing server on this port ----------

# lsof is not available on Windows; use PowerShell fallback
PID=""
if command -v lsof &>/dev/null; then
  PID=$(lsof -ti :"$PORT" 2>/dev/null || true)
else
  PID=$(powershell.exe -NoProfile -Command \
    "(Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue).OwningProcess" \
    2>/dev/null | tr -d '\r' || true)
fi
if [ -n "$PID" ]; then
  echo "Killing existing process on port $PORT (PID $PID)"
  kill "$PID" 2>/dev/null || taskkill.exe /PID "$PID" /F 2>/dev/null || true
  sleep 1
fi

# ---------- start server ----------

echo "Starting MonsterQuest editor at $URL"

open_browser &

cd "$SCRIPT_DIR/web"
export PYTHONPATH="$SCRIPT_DIR/web"
"$VENV_BIN/python" backend/app.py --host 127.0.0.1 --port "$PORT"
