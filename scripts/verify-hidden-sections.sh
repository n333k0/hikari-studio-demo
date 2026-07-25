#!/usr/bin/env bash
# verify-hidden-sections.sh — VERIFY (one responsibility: hidden sections stay hidden).
# #historia (mission) and #acabado (finish rail) must not render.
# Cites: docs/protected-regions.md → Content/structure; docs/verification-policy.md.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2

if ! have_browser; then fail "hidden-sections: chrome-devtools-axi missing"; emit_result "$RUN_DIR" hidden_sections 0 '{"error":"no browser"}'; exit 1; fi

browser_open 1440 900
res="$(browser_eval '() => { const q=id=>{const e=document.getElementById(id);return {present:!!e, hidden: e? (e.offsetParent===null):null};}; return JSON.stringify({historia:q("historia"), acabado:q("acabado")}); }')"

ok="$(RES="$res" python3 -c '
import os,json
r=json.loads(os.environ["RES"])
def hidden(x): return x.get("hidden") is True
print("1" if hidden(r["historia"]) and hidden(r["acabado"]) else "0")
')"

emit_result "$RUN_DIR" hidden_sections "$ok" "$res"
if [[ "$ok" == 1 ]]; then pass "hidden-sections: #historia and #acabado are hidden"; exit 0
else fail "hidden-sections: a section is VISIBLE — $res"; exit 1; fi
