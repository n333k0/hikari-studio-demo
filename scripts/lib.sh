#!/usr/bin/env bash
# lib.sh — shared helpers for the website-change verification system.
# SUPPORT FILE (not a graph node). Sourced by every other script.
# Responsibilities: resolve repo root/run dir from the script location (not CWD),
# drive chrome-devtools-axi robustly, capture screenshots, emit structured JSON.
# No verification logic of its own.

set -uo pipefail

# --- paths (resolve from THIS file, never from CWD) -------------------------
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$LIB_DIR/.." && pwd)"
STATE_DIR="$ROOT/.agent-state"
RUNS_DIR="$STATE_DIR/runs"
CURRENT_RUN_PTR="$STATE_DIR/current-run"
# Overridable so the same harness can verify any page, not just the
# homepage — e.g. TARGET_URL="file://$ROOT/productos/ensui-d70/index.html".
# Defaults to the homepage for full backward compatibility.
SITE_URL="${TARGET_URL:-file://$ROOT/index.html}"

# Breakpoints we exercise (desktop, tablet edges, mobile edges, mobile).
BREAKPOINTS=(1440 1024 768 641 640 390)
# The three "beauty shot" widths used for baseline/after screenshots.
SHOT_WIDTHS=(1440 768 390)

# --- pretty printing --------------------------------------------------------
_c_green=$'\033[32m'; _c_red=$'\033[31m'; _c_yellow=$'\033[33m'; _c_dim=$'\033[2m'; _c_off=$'\033[0m'
log()  { printf '%s\n' "$*" >&2; }
pass() { printf '%s✓ %s%s\n' "$_c_green" "$*" "$_c_off" >&2; }
fail() { printf '%s✗ %s%s\n' "$_c_red" "$*" "$_c_off" >&2; }
warn() { printf '%s! %s%s\n' "$_c_yellow" "$*" "$_c_off" >&2; }
dim()  { printf '%s%s%s\n' "$_c_dim" "$*" "$_c_off" >&2; }

# --- run directory resolution ----------------------------------------------
# Uses $RUN_DIR if exported, else the current-run pointer. Never guesses.
resolve_run() {
  if [[ -n "${RUN_DIR:-}" ]]; then printf '%s\n' "$RUN_DIR"; return 0; fi
  if [[ -f "$CURRENT_RUN_PTR" ]]; then cat "$CURRENT_RUN_PTR"; return 0; fi
  fail "No active run. Run: scripts/run.sh start \"<request>\"" ; return 1
}

# --- chrome-devtools-axi wrappers ------------------------------------------
# Whether the browser CLI is available at all.
have_browser() { command -v chrome-devtools-axi >/dev/null 2>&1; }

# Evaluate JS in the page and return a CLEAN, double-decoded JSON string.
# CONTRACT: the JS you pass MUST `return JSON.stringify(value)`.
# Handles chrome-devtools-axi's escaped `result: "..."` output.
browser_eval() {
  local js="$1" out
  out="$(chrome-devtools-axi eval "$js" 2>/dev/null)" || return 1
  printf '%s' "$out" | python3 -c '
import sys, json, re
data = sys.stdin.read()
m = re.search(r"result:\s*(.*)", data)
if not m:
    print(""); sys.exit(0)
val = m.group(1).strip()
for _ in range(3):           # peel escaping layers until it stops being a JSON string
    if isinstance(val, str):
        try:
            val = json.loads(val); continue
        except Exception:
            break
    else:
        break
print(json.dumps(val))
'
}

# Read back the ACTUAL layout-viewport width from the live page. Never trust
# a resize/emulate call's own "ok" output — read the DOM back and compare.
_actual_viewport_w() {
  local out
  out="$(browser_eval '() => JSON.stringify(document.documentElement.clientWidth)')" || { printf 'ERR'; return; }
  out="${out//\"/}"
  [[ "$out" =~ ^[0-9]+$ ]] && printf '%s' "$out" || printf 'ERR'
}

# Set the layout viewport to <w>x<h> and ASSERT it actually took effect
# before returning — retrying, then reopening the page, before giving up.
#
# CONFIRMED BUG (2026-07-25, reproduced repeatedly): `chrome-devtools-axi
# resize <w> <h>` drives a REAL OS-level browser-window resize
# (Browser.setWindowBounds), which has a silent floor on this machine — any
# requested width below ~500px clamps to exactly 500px, while the CLI still
# prints "resized: width: <w>" as if the requested width had been applied.
# That silently hits this project's own 390px breakpoint: the "mobile" check
# could have been measuring ~500px, not 390px, with no error anywhere.
# Separately, a stale/disconnected page target was observed to not respond to
# ANY resize at all (every width read back as the same stuck value) while
# `eval` kept returning cached-looking results instead of erroring — so a
# resize call succeeding is not evidence the page is even listening.
# `chrome-devtools-axi emulate --viewport "<w>x<h>"` (CDP device-metrics
# override — the same mechanism DevTools' own responsive-design mode uses)
# does NOT have the real-window floor: verified reliable down to 390px and
# back up to 1440px repeatedly, including rapid up/down toggling, in the same
# session. So viewport changes go through `emulate`, never `resize`, and
# every change is read back and asserted before any measurement at that
# width is trusted. Callers must check the return value: 0 = verified at the
# requested width, 1 = could not get there even after reopening — the caller
# must NOT proceed to measure/trust anything at that breakpoint.
_set_viewport() {
  local w="$1" h="$2" attempt got
  for attempt in 1 2; do
    chrome-devtools-axi emulate --viewport "${w}x${h}" >/dev/null 2>&1 || true
    sleep 0.35
    got="$(_actual_viewport_w)"
    [[ "$got" == "$w" ]] && return 0
  done
  warn "viewport stuck at ${got}px (wanted ${w}px) after 2 attempts — reopening $SITE_URL and retrying once more"
  chrome-devtools-axi open "$SITE_URL" >/dev/null 2>&1 || true
  sleep 0.6
  chrome-devtools-axi emulate --viewport "${w}x${h}" >/dev/null 2>&1 || true
  sleep 0.35
  got="$(_actual_viewport_w)"
  [[ "$got" == "$w" ]] && return 0
  fail "viewport STUCK at ${got}px, cannot reach ${w}px even after reopening — browser session is unreliable, refusing to report a measurement taken at the wrong width"
  return 1
}

# Open the local site and set a viewport. Quiet. Small settle delay.
# Returns 1 (without exiting) if the viewport can't be verified — caller
# must treat that as fatal for this run, per the contract above.
browser_open() {
  local w="${1:-1440}" h="${2:-900}"
  chrome-devtools-axi open "$SITE_URL" >/dev/null 2>&1 || true
  sleep 0.3
  _set_viewport "$w" "$h"
}
# Returns 1 (without exiting) if the requested width can't be verified —
# caller must skip/flag that breakpoint rather than measuring at whatever
# width the page actually happens to be.
browser_resize() {
  local w="$1" h="${2:-900}"
  _set_viewport "$w" "$h"
}

# Screenshot via the dedicated Playwright module (screenshot/shoot.mjs).
# Playwright is the SCREENSHOT engine; chrome-devtools-axi is only the DOM engine.
# Writes DIRECTLY to the run dir (no sandbox, no scratchpad), then verifies bytes
# landed and FAILS LOUDLY if the image is missing.
#   shot <abspath> [width] [height] [preshot_eval_js]
SHOOTER="$LIB_DIR/screenshot/shoot.mjs"
shot() {
  local out="$1" w="${2:-1440}" h="${3:-900}" ev="${4:-}"
  mkdir -p "$(dirname "$out")"
  local a=(--url "$SITE_URL" --out "$out" --width "$w" --height "$h")
  [[ -n "$ev" ]] && a+=(--eval "$ev")
  local err
  if err="$(node "$SHOOTER" "${a[@]}" 2>&1)" && [[ -s "$out" ]]; then
    return 0
  fi
  fail "screenshot MISSING: $out"
  [[ -n "$err" ]] && printf '  %s\n' "$err" >&2
  return 1
}

# --- structured output for the orchestrator --------------------------------
# emit_result <run_dir> <check-name> <pass:0|1> <details-json>
# Writes verification/parts/<name>.json  →  {"pass":bool,"details":...}
emit_result() {
  local run="$1" name="$2" ok="$3" details="${4:-null}"
  local dir="$run/verification/parts"; mkdir -p "$dir"
  PASS_BOOL=$([[ "$ok" == "1" ]] && echo true || echo false) \
  DETAILS="$details" NAME="$name" \
  python3 -c '
import os, json, sys
try:
    details = json.loads(os.environ.get("DETAILS") or "null")
except Exception:
    details = os.environ.get("DETAILS")
out = {"pass": os.environ["PASS_BOOL"] == "true", "details": details}
print(json.dumps(out, indent=2))
' > "$dir/$name.json"
}

# ISO-ish timestamp helper.
now_iso() { date +"%Y-%m-%dT%H:%M:%S%z"; }

# --- risk heuristic — ADVISORY ONLY, not authoritative -----------------------
# Bash cannot understand a request's intent; this is a file-extension guess a
# caller (the /quick-site skill) may consult but should not defer to. Real risk
# classification is a Claude judgment call.
# Input: changed file paths (args). Output: low|medium|high.
classify_risk() {
  local -a files=("$@")
  local has_structural=0 has_style=0 has_other=0
  for f in "${files[@]}"; do
    case "$f" in
      index.html) has_structural=1 ;;
      styles.css) has_style=1 ;;
      *)          has_other=1 ;;
    esac
  done
  if (( has_other )); then echo "high"; return 0; fi
  if (( has_structural && has_style )); then echo "medium"; return 0; fi
  if (( has_structural )); then echo "high"; return 0; fi
  if (( has_style )); then echo "low"; return 0; fi
  echo "medium"
}

# Resolve changed files since baseline (for quick mode).
# Returns one file per line (repo-relative paths).
quick_changed_files() {
  git diff --name-only 2>/dev/null || echo "index.html"
}

# Run a subset of checks based on risk. Caller must have exported RUN_DIR
# (each verify-*.sh resolves it via resolve_run(), env var takes priority).
# Usage: run_risk_checks <risk-level>
run_risk_checks() {
  local risk="$1"
  case "$risk" in
    low)
      bash "$LIB_DIR/verify-overflow.sh" || true
      bash "$LIB_DIR/verify-copy.sh" || true
      ;;
    medium)
      bash "$LIB_DIR/verify-overflow.sh" || true
      bash "$LIB_DIR/verify-copy.sh" || true
      bash "$LIB_DIR/verify-header.sh" || true
      bash "$LIB_DIR/verify-layout.sh" || true
      ;;
    high|*)
      bash "$LIB_DIR/verify-overflow.sh" || true
      bash "$LIB_DIR/verify-header.sh" || true
      bash "$LIB_DIR/verify-hidden-sections.sh" || true
      bash "$LIB_DIR/verify-copy.sh" || true
      bash "$LIB_DIR/verify-footer.sh" || true
      bash "$LIB_DIR/verify-layout.sh" || true
      ;;
  esac
}
