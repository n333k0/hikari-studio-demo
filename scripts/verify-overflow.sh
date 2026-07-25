#!/usr/bin/env bash
# verify-overflow.sh — VERIFY (one responsibility: horizontal overflow).
# Asserts scrollWidth - clientWidth === 0 at every breakpoint, both at the
# top of the page AND after scrolling to the bottom — checking only scroll
# position 0 misses overflow from elements that only appear/change on
# scroll (e.g. a sticky bar that reveals more content than fits on narrow
# viewports — this bit the Ensui D70 product page in practice).
# Cites: docs/verification-policy.md → "Always" #1.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2

if ! have_browser; then fail "overflow: chrome-devtools-axi missing"; emit_result "$RUN_DIR" overflow 0 '{"error":"no browser"}'; exit 1; fi

if ! browser_open 1440 900; then
  fail "overflow: could not establish a trustworthy initial viewport — aborting rather than measuring blind"
  emit_result "$RUN_DIR" overflow 0 '{"error":"viewport unverified at open"}'
  exit 1
fi
results="{}"; ok=1
for w in "${BREAKPOINTS[@]}"; do
  if ! browser_resize "$w" 900; then
    fail "  ${w}px  SKIPPED — viewport could not be verified at this width (see warning above)"
    results="$(RES="$results" W="$w" python3 -c 'import os,json;r=json.loads(os.environ["RES"]);r[os.environ["W"]]={"top":"VIEWPORT_MISMATCH","bottom":"VIEWPORT_MISMATCH"};print(json.dumps(r))')"
    ok=0
    continue
  fi
  val_top="$(browser_eval '() => { window.scrollTo(0,0); return JSON.stringify(document.documentElement.scrollWidth - document.documentElement.clientWidth); }')"
  val_top="${val_top//\"/}"; [[ "$val_top" =~ ^-?[0-9]+$ ]] || val_top="ERR"
  val_bottom="$(browser_eval '() => { window.scrollTo(0, document.body.scrollHeight); return JSON.stringify(document.documentElement.scrollWidth - document.documentElement.clientWidth); }')"
  val_bottom="${val_bottom//\"/}"; [[ "$val_bottom" =~ ^-?[0-9]+$ ]] || val_bottom="ERR"
  results="$(RES="$results" W="$w" VT="$val_top" VB="$val_bottom" python3 -c 'import os,json;r=json.loads(os.environ["RES"]);vt=os.environ["VT"];vb=os.environ["VB"];r[os.environ["W"]]={"top":(int(vt) if vt.lstrip("-").isdigit() else vt),"bottom":(int(vb) if vb.lstrip("-").isdigit() else vb)};print(json.dumps(r))')"
  if [[ "$val_top" == "0" && "$val_bottom" == "0" ]]; then
    dim "  ${w}px  overflow(top)=0 overflow(bottom)=0"
  else
    fail "  ${w}px  overflow(top)=${val_top} overflow(bottom)=${val_bottom}"; ok=0
  fi
done

emit_result "$RUN_DIR" overflow "$ok" "{\"byWidth\":$results}"
if [[ "$ok" == 1 ]]; then pass "overflow: 0px at all breakpoints"; exit 0; else fail "overflow: FAILED"; exit 1; fi
