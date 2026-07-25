#!/usr/bin/env bash
# Launch WebsiteOS — the live worktree/agent-dispatch board. The project name in
# the panel title is derived from the repo directory at runtime, so this script
# is portable as-is (override with $WEBSITEOS_PROJECT or project-name.txt).
# Usage: .claude/dashboard/serve.sh [port]   (default 8765; auto-tries the next
# few ports if that one's busy — server.py prints whichever URL it actually bound.)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-8765}"
exec python3 "$DIR/server.py" "$PORT"
