#!/usr/bin/env bash
# verify-header.sh — VERIFY (one responsibility: header over→solid state machine).
# At top of hero: header is --over (transparent). After the marquee scrolls into
# the lower viewport: header is --solid (white bg) and the logo inverts to black.
# Cites: docs/protected-regions.md → Header; docs/verification-policy.md.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2
sdir="$RUN_DIR/screenshots"; mkdir -p "$sdir"

if ! have_browser; then fail "header: chrome-devtools-axi missing"; emit_result "$RUN_DIR" header 0 '{"error":"no browser"}'; exit 1; fi

browser_open 1440 900

# State at top: expect header--over present, header--solid absent.
# DOM checks via chrome-devtools-axi (the DOM engine); screenshots via Playwright.
top="$(browser_eval '() => { window.scrollTo(0,0); const h=document.getElementById("header"); return JSON.stringify({over:h.classList.contains("header--over"), solid:h.classList.contains("header--solid")}); }')"
shot "$sdir/header-over.png" 1440 900 || true

# Scroll until the marquee is well into view (past the ~0.7*innerHeight trigger).
browser_eval '() => { const m=document.querySelector(".marquee"); window.scrollTo(0, Math.max(0, Math.round(m.offsetTop - window.innerHeight*0.5))); return JSON.stringify("scrolled"); }' >/dev/null
sleep 0.5
scrolled="$(browser_eval '() => { const h=document.getElementById("header"); const lf=getComputedStyle(document.querySelector(".brand__logo")).filter; return JSON.stringify({over:h.classList.contains("header--over"), solid:h.classList.contains("header--solid"), logoFilter:lf}); }')"
shot "$sdir/header-solid.png" 1440 900 "window.scrollTo(0, Math.max(0, Math.round(document.querySelector('.marquee').offsetTop - window.innerHeight*0.5)))" || true

ok="$(TOP="$top" SCR="$scrolled" python3 -c '
import os,json
t=json.loads(os.environ["TOP"]); s=json.loads(os.environ["SCR"])
top_ok   = (t.get("over") is True)  and (t.get("solid") is False)
solid_ok = (s.get("solid") is True) and (s.get("over") is False)
print("1" if (top_ok and solid_ok) else "0")
')"
details="$(TOP="$top" SCR="$scrolled" python3 -c 'import os,json;print(json.dumps({"atTop":json.loads(os.environ["TOP"]),"scrolled":json.loads(os.environ["SCR"])}))')"

emit_result "$RUN_DIR" header "$ok" "$details"
if [[ "$ok" == 1 ]]; then pass "header: over at top, solid after marquee (logo inverts)"; exit 0
else fail "header: state machine INCORRECT — see screenshots/header-*.png"; exit 1; fi
