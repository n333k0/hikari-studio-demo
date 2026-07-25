#!/usr/bin/env bash
# Refresh THIS Claude Code session's heartbeat file, so the WebsiteOS panel can
# honestly answer "how many sessions are working right now".
#
# Why this exists: a session that works in the foreground creates no git
# worktree, takes no lock and files no claim. Before this hook the panel could
# only report the sessions that happened to have written a captain file by
# hand - so it kept saying "0 sesiones con senal" while two windows were
# actively editing. There is no API for "list open chat windows"; the only
# honest way to count them is for each session to leave a trace, which is
# exactly what this does.
#
# Wired to two events in .claude/settings.json:
#   SessionStart - creates the file (and prunes long-dead ones)
#   PostToolUse  - touches it, so "active" means "did something recently"
#                  rather than "was started at some point today". A session
#                  that goes quiet ages out on its own after
#                  CAPTAIN_HEARTBEAT_STALE_AFTER_SECS (20 min, server.py).
#
# Hard rule: this must NEVER fail a tool call. Every step is best-effort and
# the script always exits 0. It only ever writes inside .agent-state/captains/
# (gitignored) and never touches tracked files.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 0
DIR="$ROOT/.agent-state/captains"

# Hook payload arrives as JSON on stdin. Parse with sed, not python3: this runs
# after every single tool call, so an interpreter start-up per call is a real
# tax for reading one string.
payload=""
if [ ! -t 0 ]; then
  payload="$(cat 2>/dev/null)" || payload=""
fi
sid="$(printf '%s' "$payload" \
  | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -1)"

# No id, no guess. A heartbeat we can't attribute is worse than none.
[ -n "$sid" ] || exit 0
# Reject anything that isn't a plain id - this becomes a filename.
case "$sid" in
  *[!a-zA-Z0-9_-]*) exit 0 ;;
esac

mkdir -p "$DIR" 2>/dev/null || exit 0
file="$DIR/$sid.md"

if [ -f "$file" ]; then
  touch "$file" 2>/dev/null
else
  # First sighting of this session. The body is written once; freshness always
  # comes from the file's mtime (see server.py read_captains), never from text
  # in here, which would go stale without the file being touched.
  {
    echo "# Session: $sid"
    echo
    echo "- **Label:** Claude Code session (heartbeat written automatically by"
    echo "  scripts/session-heartbeat.sh). Rename this label by hand if this"
    echo "  session is doing something worth naming on the board."
    echo "- **First seen:** $(date +%Y-%m-%dT%H:%M:%S%z)"
    echo "- **How to read freshness:** this file's mtime IS the signal. A"
    echo "  PostToolUse hook touches it on every tool call, so a session that"
    echo "  stops working ages out by itself."
  } > "$file" 2>/dev/null
fi

# Prune heartbeats nobody has touched in over a day, so the panel's session
# count can't drift upward forever across weeks of sessions. Only runs on
# SessionStart (passed explicitly), never on the per-tool-call path.
if [ "${1:-}" = "--prune" ]; then
  find "$DIR" -name '*.md' -type f -mtime +1 -delete 2>/dev/null
fi

exit 0
