#!/usr/bin/env bash
# verify-layout.sh — VERIFY (one responsibility: responsive contract, ONLY the
# parts that are reliably measurable). Deliberately NOT brittle: aesthetic
# density (exact visible card count, "balance") is captured as evidence for the
# human/agent reviewer, never asserted here.
# Asserted (from docs/website-spec.md → Responsive contract):
#   desktop 1440: gutter 32, hero__cta row,    values 3 cols
#   tablet  768 : gutter 24, hero__cta row,    values 3 cols
#   mobile  390 : gutter 16, hero__cta column, values 1 col
#   hero h1 scales monotonically down (1440 >= 768 >= 390) and fits its column.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2

if ! have_browser; then fail "layout: chrome-devtools-axi missing"; emit_result "$RUN_DIR" layout 0 '{"error":"no browser"}'; exit 1; fi

# expected contract per width = "gutter|cta|valuecols" (portable, no assoc arrays)
exp_for() { case "$1" in
  1440) echo "32|row|3" ;;
  768)  echo "24|row|3" ;;
  390)  echo "16|column|1" ;;
esac; }

browser_open 1440 900
measured="{}"; ok=1
for w in 1440 768 390; do
  browser_resize "$w" 900
  m="$(browser_eval '() => {
    window.scrollTo(0,0);
    const cs=n=>getComputedStyle(n);
    const gutter=Math.round(parseFloat(cs(document.documentElement).getPropertyValue("--gutter")));
    const cta=cs(document.querySelector(".hero__cta")).flexDirection;
    const valueCols=cs(document.querySelector(".values")).gridTemplateColumns.split(" ").length;
    const h1=document.querySelector(".hero h1"); const copy=document.querySelector(".hero__copy");
    const h1w=Math.round(h1.getBoundingClientRect().width);
    const copyw=Math.round(copy.getBoundingClientRect().width);
    const h1size=Math.round(parseFloat(cs(h1).fontSize));
    // evidence-only (not asserted): carousel track sizing
    const prod=cs(document.querySelector(".track--products")).gridAutoColumns;
    return JSON.stringify({gutter,cta,valueCols,h1size,h1w,copyw,productsTrack:prod});
  }')"
  measured="$(MEAS="$measured" W="$w" M="$m" python3 -c 'import os,json;r=json.loads(os.environ["MEAS"]);r[os.environ["W"]]=json.loads(os.environ["M"]);print(json.dumps(r))')"
  IFS='|' read -r eg ec ev <<< "$(exp_for "$w")"
  cw="$(RES="$m" python3 -c 'import os,json;print(json.loads(os.environ["RES"]).get("gutter"))')"
  cc="$(RES="$m" python3 -c 'import os,json;print(json.loads(os.environ["RES"]).get("cta"))')"
  cv="$(RES="$m" python3 -c 'import os,json;print(json.loads(os.environ["RES"]).get("valueCols"))')"
  cfit="$(RES="$m" python3 -c 'import os,json;d=json.loads(os.environ["RES"]);print("1" if d.get("h1w",1e9)<=d.get("copyw",0)+1 else "0")')"
  bad=""
  [[ "$cw" == "$eg" ]] || bad+=" gutter=$cw(want $eg)"
  [[ "$cc" == "$ec" ]] || bad+=" cta=$cc(want $ec)"
  [[ "$cv" == "$ev" ]] || bad+=" valueCols=$cv(want $ev)"
  [[ "$cfit" == "1" ]] || bad+=" h1-overflows-column"
  if [[ -z "$bad" ]]; then dim "  ${w}px  gutter=$cw cta=$cc values=$cv h1-fits"; else fail "  ${w}px $bad"; ok=0; fi
done

# h1 monotonic non-increasing as viewport shrinks (evidence-derived assertion).
mono="$(MEAS="$measured" python3 -c '
import os,json
m=json.loads(os.environ["MEAS"])
try: a,b,c=m["1440"]["h1size"],m["768"]["h1size"],m["390"]["h1size"]
except Exception: print("0"); raise SystemExit
print("1" if a>=b>=c else "0")
')"
[[ "$mono" == "1" ]] || { fail "  h1 not monotonic across widths"; ok=0; }

emit_result "$RUN_DIR" layout "$ok" "{\"measured\":$measured,\"h1_monotonic\":$([[ $mono == 1 ]] && echo true || echo false)}"
if [[ "$ok" == 1 ]]; then pass "layout: gutter/cta/value-cols/h1 match contract at 1440/768/390"; exit 0
else fail "layout: contract mismatch (see details)"; exit 1; fi
