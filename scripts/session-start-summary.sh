#!/usr/bin/env bash
# session-start-summary.sh — deterministic SessionStart print, six parts:
#   1. active git worktrees (parallel agent dispatch may be in flight)
#   2. active agent claims: locked worktrees' declared scope, so a new
#      session knows what NOT to touch and can suggest non-overlapping work
#   3. uncommitted work in THIS checkout, with recency — catches foreground
#      work by another session, which has no worktree and so files no claim
#   4. pending shared-file edits flagged but not yet applied
#   5. ready-to-review links: one per section with finished work, collapsed
#      ("+N more") for sections with several pages of the same type — never
#      an exhaustive per-page list.
#   6. the dashboard ("General y sus Soldados"): its live localhost URL when
#      the server is already up, otherwise the command to start it. It's part
#      of the system, so it belongs in the opening status next to the site
#      links, not something the user has to remember exists.
# Pure filesystem glob + git, no reasoning: the model's job is to render this
# into a status line, not to rediscover what exists. See docs/ARCHITECTURE.md
# §13 for the "why a hook, not a doc-read convention" rationale.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT" || exit 0
PAGES_BASE="https://n333k0.github.io/hikari-studio-demo"

echo "--- Active git worktrees (parallel agent dispatch may be in flight - see docs/ARCHITECTURE.md sec 13) ---"
git worktree list 2>/dev/null || echo "(git worktree list unavailable)"
echo

echo "--- Active agent claims (locked worktrees' declared scope - soft signal, not enforced) ---"
found_locked=0
if [ -d .git/worktrees ]; then
  for lockfile in .git/worktrees/*/locked; do
    [ -f "$lockfile" ] || continue
    found_locked=1
    wt_name="$(basename "$(dirname "$lockfile")")"
    claim=".agent-state/claims/$wt_name.md"
    echo "Locked worktree: $wt_name ($(cat "$lockfile"))"
    if [ -f "$claim" ]; then
      sed 's/^/  /' "$claim"
    else
      echo "  NO CLAIM FILED - unknown scope. Ask before assuming what's safe to edit,"
      echo "  or treat every shared file as potentially in use until this agent files"
      echo "  one at .agent-state/claims/$wt_name.md."
    fi
    echo
  done
fi
if [ "$found_locked" -eq 0 ]; then
  echo "(no locked worktrees - no other agent has declared itself active)"
  echo
fi

echo "--- Uncommitted work in this checkout (may be another session's foreground work - it has no worktree, so no claim) ---"
# The claims section above only sees *locked worktrees*. A session editing this
# checkout directly is invisible there, which once led a session to report "no
# trace of that work" when it was live in scripts/3d/. Recency is the tell:
# something touched minutes ago is in flight, not leftover.
file_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }
newest_mtime() {  # newest file under a path (dirs: git reports untracked dirs, not files)
  local p="$1" newest=0 m f
  if [ -d "$p" ]; then
    while IFS= read -r f; do
      m="$(file_mtime "$f")"; [ "$m" -gt "$newest" ] && newest="$m"
    done < <(find "$p" -type f 2>/dev/null)
  elif [ -e "$p" ]; then
    newest="$(file_mtime "$p")"
  fi
  echo "$newest"
}
porcelain="$(git status --porcelain 2>/dev/null)"
git_rc=$?
if [ "$git_rc" -ne 0 ]; then
  echo "WARNING: 'git status' failed here - cannot tell whether another session is mid-edit. Check by hand."
elif [ -z "$porcelain" ]; then
  echo "(clean - nothing uncommitted)"
else
  now="$(date +%s)"
  shown=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    status_code="${line:0:2}"; path="${line:3}"
    path="${path#\"}"; path="${path%\"}"        # git quotes paths with odd chars
    path="${path##* -> }"                        # renames: report the destination
    if [ "$shown" -ge 20 ]; then
      echo "  ... (more - run 'git status' for the full list)"
      break
    fi
    mt="$(newest_mtime "$path")"
    age_note=""
    if [ "$mt" -gt 0 ]; then
      age_min=$(( (now - mt) / 60 ))
      if [ "$age_min" -lt 0 ]; then age_min=0; fi
      if [ "$age_min" -le 90 ]; then
        age_note="   <-- touched ${age_min}m ago, LIKELY ACTIVE"
      else
        age_note="   (touched ${age_min}m ago)"
      fi
    fi
    echo "  $status_code $path$age_note"
    shown=$((shown + 1))
  done <<< "$porcelain"
  echo "  Treat anything marked LIKELY ACTIVE as another session's in-flight work unless you know it's yours."
fi
echo

echo "--- Pending shared-file edits, flagged but not yet applied (docs/site-structure.md) ---"
if [ -f docs/site-structure.md ] && grep -q '<!-- PENDING-SHARED-EDITS:START -->' docs/site-structure.md; then
  awk '/<!-- PENDING-SHARED-EDITS:START -->/,/<!-- PENDING-SHARED-EDITS:END -->/' docs/site-structure.md
else
  echo "WARNING: could not find the pending-shared-edits markers in docs/site-structure.md - check that file by hand."
fi
echo

echo "--- Ready to review (one link per section; see docs/site-structure.md for full status/Validated?) ---"
if [ -f index.html ]; then
  echo "Home: $PAGES_BASE/"
else
  echo "Home: MISSING index.html"
fi

shopt -s nullglob
products=(productos/*/index.html)
shopt -u nullglob
n_products=${#products[@]}
if [ "$n_products" -eq 0 ]; then
  echo "Productos: none yet"
else
  # Prefer ensui-d70 as the example (the canonical/most-referenced template
  # instance) when present; otherwise fall back to the first found.
  first_slug=""
  for p in "${products[@]}"; do
    [ "$(basename "$(dirname "$p")")" = "ensui-d70" ] && first_slug="ensui-d70" && break
  done
  [ -z "$first_slug" ] && first_slug="$(basename "$(dirname "${products[0]}")")"
  if [ "$n_products" -eq 1 ]; then
    echo "Productos: $PAGES_BASE/productos/$first_slug/"
  else
    echo "Productos: $PAGES_BASE/productos/$first_slug/ (+$((n_products - 1)) more — see docs/site-structure.md)"
  fi
fi

# Category pages: check real literal candidate paths (nullglob only drops
# unmatched *globs*, not literal non-existent paths, so test each by hand).
categorias=()
shopt -s nullglob
for p in categorias/*/index.html; do categorias+=("$p"); done
shopt -u nullglob
for p in de-pie/index.html colgantes/index.html; do
  [ -f "$p" ] && categorias+=("$p")
done
if [ "${#categorias[@]}" -eq 0 ]; then
  echo "Categorías: none yet (Phase 2 not started)"
else
  first="${categorias[0]%index.html}"
  n_rest=$((${#categorias[@]} - 1))
  if [ "$n_rest" -eq 0 ]; then
    echo "Categorías: $PAGES_BASE/$first"
  else
    echo "Categorías: $PAGES_BASE/$first (+$n_rest more)"
  fi
fi

if [ -f blog/index.html ]; then
  echo "Blog/Tutoriales: $PAGES_BASE/blog/"
else
  echo "Blog/Tutoriales: none yet (Phase 3 not started)"
fi

if [ -f contacto/index.html ]; then
  echo "Contacto: $PAGES_BASE/contacto/"
else
  echo "Contacto / Política de Devolución: none yet (Phase 4 not started)"
fi
echo

echo "--- Dashboard: \"General y sus Soldados\" (local panel: worktrees, agent claims, kanban) ---"
# Probe the port range server.py actually walks (DEFAULT_PORT 8765, +9). Check
# the socket first with bash /dev/tcp - instant on a closed local port - and
# only spend a curl on ports that are genuinely open, so a hung service on one
# of them can't eat the hook's timeout. The grep for the panel's own name keeps
# us from announcing somebody else's server as the dashboard.
port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; }
if [ -x .claude/dashboard/serve.sh ]; then
  dash_url=""
  for p in $(seq 8765 8774); do
    port_open "$p" || continue
    if curl -fsS -m 2 "http://localhost:$p/" 2>/dev/null | grep -q "Soldados"; then
      dash_url="http://localhost:$p/"
      break
    fi
  done
  if [ -n "$dash_url" ]; then
    echo "Running now: $dash_url"
  else
    echo "Not running. Start it:  .claude/dashboard/serve.sh   -> then open http://localhost:8765/"
    echo "  (serve.sh auto-tries 8765-8774 and prints whichever port it bound.)"
  fi
else
  echo "(no .claude/dashboard/serve.sh in this checkout - dashboard not installed here)"
fi
