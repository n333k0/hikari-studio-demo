#!/usr/bin/env bash
# capture-baseline.sh — BASELINE step.
# Responsibility (ONLY): record the pre-change state of the repo and the page.
# Records git commit, branch, porcelain status, and a hashed file inventory so
# capture-after.sh can tell PRE-EXISTING changes apart from RUN-INTRODUCED ones.
# Cites: docs/change-workflow.md (Baseline), docs/verification-policy.md.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN_DIR="$(resolve_run)" || exit 2
bl="$RUN_DIR/baseline"; mkdir -p "$bl"

cd "$ROOT"

# --- git baseline (strengthened per spec) ----------------------------------
git rev-parse HEAD                         > "$bl/git-head.txt"   2>/dev/null || echo "UNKNOWN" > "$bl/git-head.txt"
git rev-parse --abbrev-ref HEAD            > "$bl/git-branch.txt" 2>/dev/null || echo "UNKNOWN" > "$bl/git-branch.txt"
git status --porcelain                     > "$bl/git-status.txt" 2>/dev/null || true

# Hashed inventory of every tracked + untracked (non-ignored) file: "sha  path".
# Excludes .agent-state and .DS_Store (they are gitignored).
: > "$bl/files-present-before.txt"
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  printf '%s  %s\n' "$(git hash-object "$f" 2>/dev/null)" "$f"
done < <(git ls-files -oc --exclude-standard 2>/dev/null | sort) >> "$bl/files-present-before.txt"

# Human-friendly split of what was already dirty before we started.
git diff --name-only                       > "$bl/tracked-modified-before.txt" 2>/dev/null || true
git ls-files -o --exclude-standard         > "$bl/untracked-before.txt"        2>/dev/null || true

# --- baseline screenshots (Playwright engine) ------------------------------
for w in "${SHOT_WIDTHS[@]}"; do
  shot "$bl/baseline-${w}.png" "$w" 900 || warn "baseline screenshot ${w}px failed"
done

pass "Baseline captured for run: ${RUN_DIR##*/}"
dim  "  head=$(cat "$bl/git-head.txt" | cut -c1-12)  branch=$(cat "$bl/git-branch.txt")  files=$(wc -l < "$bl/files-present-before.txt" | tr -d ' ')  dirty=$(wc -l < "$bl/git-status.txt" | tr -d ' ')"
exit 0
