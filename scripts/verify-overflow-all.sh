#!/usr/bin/env bash
# verify-overflow-all.sh — SWEEP (one responsibility: run the existing
# per-page overflow check across EVERY page in the site, not just whichever
# single URL a human happened to point it at).
#
# Why this exists: verify-overflow.sh only ever checks one SITE_URL/
# TARGET_URL at a time. As productos/<slug>/index.html pages get added
# (~30 planned, more arrive over time), a bug on any page that isn't the one
# URL someone manually chose goes completely undetected — which is exactly
# how the homepage's own horizontal-overflow bug went unnoticed.
#
# This script does NOT reimplement the overflow check. It only:
#   1. discovers every page that currently exists (glob the filesystem —
#      never a hardcoded list, so new products are picked up automatically),
#   2. calls verify-overflow.sh once per page with TARGET_URL/RUN_DIR set,
#   3. aggregates a plain pass/fail summary.
# Fails loudly: any page failing (or erroring) fails the whole sweep's exit
# code. A "mostly passing" sweep must never look like a clean pass.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if ! have_browser; then
  fail "verify-overflow-all: chrome-devtools-axi missing — cannot check any page"
  exit 1
fi

# --- discover pages -----------------------------------------------------
# Homepage + every productos/<slug>/index.html that exists right now.
pages=("$ROOT/index.html")
shopt -s nullglob
for f in "$ROOT"/productos/*/index.html; do
  pages+=("$f")
done
shopt -u nullglob

if [[ ! -f "$ROOT/index.html" ]]; then
  fail "verify-overflow-all: $ROOT/index.html not found — something is very wrong"
  exit 2
fi

log "verify-overflow-all: discovered ${#pages[@]} page(s):"
for p in "${pages[@]}"; do dim "  - ${p#"$ROOT"/}"; done

# --- run the existing per-page check, once per page ----------------------
# Own sweep-scoped run dirs, isolated from any active interactive /quick-site
# run (never touches .agent-state/current-run) so this can be invoked any
# time without disturbing an in-progress session.
SWEEP_TS="$(date +%Y%m%d-%H%M%S)"
SWEEP_DIR="$STATE_DIR/runs/sweep-overflow-all-$SWEEP_TS"
mkdir -p "$SWEEP_DIR"

page_names=(); page_statuses=()
overall_ok=1

for p in "${pages[@]}"; do
  rel="${p#"$ROOT"/}"
  slug="$(printf '%s' "$rel" | tr '/' '__')"
  page_run_dir="$SWEEP_DIR/$slug"
  mkdir -p "$page_run_dir"

  log ""
  log "== $rel =="
  if RUN_DIR="$page_run_dir" TARGET_URL="file://$p" bash "$SCRIPT_DIR/verify-overflow.sh"; then
    page_names+=("$rel"); page_statuses+=("PASS")
  else
    page_names+=("$rel"); page_statuses+=("FAIL")
    overall_ok=0
  fi
done

# --- summary ---------------------------------------------------------------
log ""
log "== verify-overflow-all summary =="
n_fail=0
for i in "${!page_names[@]}"; do
  if [[ "${page_statuses[$i]}" == "PASS" ]]; then
    pass "${page_names[$i]}"
  else
    fail "${page_names[$i]}"
    n_fail=$((n_fail + 1))
  fi
done
n_total=${#page_names[@]}
n_pass=$((n_total - n_fail))

log ""
log "per-page detail: $SWEEP_DIR/<page>/verification/parts/overflow.json"
if [[ "$overall_ok" == 1 ]]; then
  pass "verify-overflow-all: $n_pass/$n_total pages passed"
  exit 0
else
  fail "verify-overflow-all: $n_fail/$n_total page(s) FAILED"
  exit 1
fi
