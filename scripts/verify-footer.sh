#!/usr/bin/env bash
# verify-footer.sh — VERIFY (one responsibility: footer wordmark protected region).
# The giant "HIKARI STUDIO" SVG must have EQUAL gaps to the footer edges on
# left / right / bottom (== the gutter) and must not be clipped.
# Cites: docs/protected-regions.md → Footer wordmark.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2
sdir="$RUN_DIR/screenshots"; mkdir -p "$sdir"

if ! have_browser; then fail "footer: chrome-devtools-axi missing"; emit_result "$RUN_DIR" footer 0 '{"error":"no browser"}'; exit 1; fi

browser_open 1440 900
res="{}"; ok=1
for w in 1440 390; do
  browser_resize "$w" 900
  m="$(browser_eval '() => { const svg=document.querySelector(".footer__wordmark-svg"); const f=document.querySelector(".footer"); if(!svg||!f) return JSON.stringify({error:"missing"}); svg.scrollIntoView({block:"end"}); const s=svg.getBoundingClientRect(), fr=f.getBoundingClientRect(); const g=parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--gutter")); return JSON.stringify({L:Math.round(s.left-fr.left), R:Math.round(fr.right-s.right), B:Math.round(fr.bottom-s.bottom), gutter:Math.round(g)}); }')"
  [[ "$w" == 1440 ]] && { shot "$sdir/footer-wordmark.png" 1440 900 "document.querySelector('.footer__wordmark-svg').scrollIntoView({block:'end'})" || true; }
  pw="$(M="$m" python3 -c '
import os,json
try: d=json.loads(os.environ["M"])
except Exception: d={}
g=d.get("gutter"); tol=2
ok = all(k in d for k in ("L","R","B")) and g is not None and all(abs(d[k]-g)<=tol for k in ("L","R","B"))
print("1" if ok else "0")
')"
  res="$(RES="$res" W="$w" M="$m" python3 -c 'import os,json;r=json.loads(os.environ["RES"]);r[os.environ["W"]]=json.loads(os.environ["M"]);print(json.dumps(r))')"
  if [[ "$pw" == 1 ]]; then dim "  ${w}px  gaps equal gutter"; else fail "  ${w}px  gaps NOT equal: $m"; ok=0; fi
done

emit_result "$RUN_DIR" footer "$ok" "$res"
if [[ "$ok" == 1 ]]; then pass "footer: wordmark gaps equal on L/R/B (no clip)"; exit 0
else fail "footer: wordmark gaps unequal / clipped — see screenshots/footer-wordmark.png"; exit 1; fi
