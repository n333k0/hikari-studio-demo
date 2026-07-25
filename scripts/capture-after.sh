#!/usr/bin/env bash
# capture-after.sh — VERIFY support (one responsibility: post-change state + scope).
# Screenshots the current page, then diffs the CURRENT hashed file inventory
# against the BASELINE inventory to distinguish:
#   - pre-existing changes (already dirty before the run), vs
#   - run-introduced changes (added/modified/removed during the run).
# Then compares run-introduced files against expected-files.txt → scope check.
# Cites: docs/change-workflow.md → Scope Protection.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2
bl="$RUN_DIR/baseline"; af="$RUN_DIR/after"; mkdir -p "$af"
cd "$ROOT"

# --- after screenshots (Playwright engine) ---------------------------------
for w in "${SHOT_WIDTHS[@]}"; do
  shot "$af/after-${w}.png" "$w" 900 || warn "after screenshot ${w}px failed"
done

# --- current hashed inventory ----------------------------------------------
after_inv="$af/files-present-after.txt"; : > "$after_inv"
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  printf '%s  %s\n' "$(git hash-object "$f" 2>/dev/null)" "$f"
done < <(git ls-files -oc --exclude-standard 2>/dev/null | sort) >> "$after_inv"

# --- diff baseline vs after (pre-existing vs run-introduced) ----------------
# Writes: changed-files.txt (run-introduced, prefixed A/M/D) and
#         verification/parts/scope.json (scope result vs expected-files.txt).
BEFORE="$bl/files-present-before.txt" AFTER="$after_inv" \
BASELINE_STATUS="$bl/git-status.txt" \
EXPECTED="$RUN_DIR/expected-files.txt" \
CHANGED="$RUN_DIR/changed-files.txt" \
SCOPE_OUT="$RUN_DIR/verification/parts/scope.json" \
python3 <<'PY'
import os, json

def load_inv(p):
    d={}
    if os.path.exists(p):
        for line in open(p):
            line=line.rstrip("\n")
            if not line.strip(): continue
            h,_,path=line.partition("  ")
            d[path]=h
    return d

before=load_inv(os.environ["BEFORE"])
after =load_inv(os.environ["AFTER"])

added   =sorted(p for p in after  if p not in before)
removed =sorted(p for p in before if p not in after)
modified=sorted(p for p in after  if p in before and after[p]!=before[p])

run_introduced=[("A",p) for p in added]+[("M",p) for p in modified]+[("D",p) for p in removed]
run_introduced.sort(key=lambda t:t[1])

# pre-existing dirtiness recorded at baseline (informational)
pre_existing=[]
if os.path.exists(os.environ["BASELINE_STATUS"]):
    for line in open(os.environ["BASELINE_STATUS"]):
        line=line.rstrip("\n")
        if line.strip(): pre_existing.append(line[3:] if len(line)>3 else line)

# write changed-files.txt (run-introduced only)
with open(os.environ["CHANGED"],"w") as fh:
    for st,p in run_introduced:
        fh.write(f"{st}  {p}\n")

# scope: run-introduced vs expected-files.txt
exp_path=os.environ["EXPECTED"]; expected=[]
if os.path.exists(exp_path):
    for line in open(exp_path):
        s=line.strip()
        if s and not s.startswith("#"): expected.append(s)
changed_paths=[p for _,p in run_introduced]
unexpected=[p for p in changed_paths if p not in expected]
expected_untouched=[p for p in expected if p not in changed_paths]

if not os.path.exists(exp_path):
    scope_pass = (len(changed_paths)==0)   # no declared scope: only OK if nothing changed
    note="no expected-files.txt present"
else:
    scope_pass = (len(unexpected)==0)
    note="ok" if scope_pass else "unexpected files changed"

scope={
  "pass": scope_pass,
  "details":{
    "run_introduced": changed_paths,
    "unexpected": unexpected,
    "expected_untouched": expected_untouched,
    "pre_existing_before_run": pre_existing,
    "note": note,
  }
}
os.makedirs(os.path.dirname(os.environ["SCOPE_OUT"]),exist_ok=True)
json.dump(scope, open(os.environ["SCOPE_OUT"],"w"), indent=2)
print(json.dumps({"run_introduced":changed_paths,"unexpected":unexpected,"pre_existing":pre_existing}))
PY

n_changed=$(wc -l < "$RUN_DIR/changed-files.txt" | tr -d ' ')
scope_pass=$(S="$RUN_DIR/verification/parts/scope.json" python3 -c 'import json,os;print(json.load(open(os.environ["S"]))["pass"])')
if [[ "$scope_pass" == "True" ]]; then pass "after: captured — ${n_changed} run-introduced file(s), scope OK"; exit 0
else fail "after: SCOPE issue — unexpected run-introduced file(s). See changed-files.txt / scope.json"; exit 1; fi
