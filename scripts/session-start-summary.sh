#!/usr/bin/env bash
# session-start-summary.sh — deterministic SessionStart print, three parts:
#   1. active git worktrees (parallel agent dispatch may be in flight)
#   2. pending shared-file edits flagged but not yet applied
#   3. ready-to-review links: one per section with finished work, collapsed
#      ("+N more") for sections with several pages of the same type — never
#      an exhaustive per-page list.
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
