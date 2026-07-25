#!/usr/bin/env bash
# verify-copy.sh — VERIFY (one responsibility: forbidden copy guardrail).
# The lamps are NOT made in Argentina; never claim it. Static check, no browser.
# Cites: docs/protected-regions.md → Content/structure; docs/website-spec.md → Copy rules.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2

pattern='hecho a mano en argentina|hechas a mano en argentina|hecho a mano en buenos aires|hechas a mano en buenos aires|taller de buenos aires|hecho en buenos aires'

matches="$(grep -inE "$pattern" "$ROOT/index.html" 2>/dev/null || true)"

if [[ -z "$matches" ]]; then
  emit_result "$RUN_DIR" copy 1 '{"forbidden_matches":[]}'
  pass "copy: no made-in-Argentina claims"; exit 0
else
  json="$(printf '%s' "$matches" | python3 -c 'import sys,json;print(json.dumps({"forbidden_matches":[l for l in sys.stdin.read().splitlines() if l]}))')"
  emit_result "$RUN_DIR" copy 0 "$json"
  fail "copy: forbidden phrase(s) present:"; printf '%s\n' "$matches" >&2
  exit 1
fi
