#!/usr/bin/env bash
# generate-report.sh — DONE step (one responsibility: assemble final-report.md).
# Pulls together request, acceptance criteria, expected vs changed files, the
# latest verification results, review state, and screenshot pointers. Computes
# the DETERMINISTIC verdict and the final_status (DONE requires deterministic +
# visual + acceptance + scope review). Cites docs/change-workflow.md → Definition of Done.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
RUN_DIR="$(resolve_run)" || exit 2

latest="$RUN_DIR/verification/latest.json"
review="$RUN_DIR/review.json"
state="$RUN_DIR/run-state.json"
report="$RUN_DIR/final-report.md"

# Compute final_status and write it back into review.json.
final_status="$(LATEST="$latest" REVIEW="$review" python3 -c '
import os,json
def load(p,d):
    try: return json.load(open(p))
    except Exception: return d
lat=load(os.environ["LATEST"],{}); rev=load(os.environ["REVIEW"],{})
det=bool(lat.get("deterministic_pass"))
vis=rev.get("visual_review"); acc=rev.get("acceptance_criteria_pass"); sco=rev.get("scope_review")
if det and vis=="pass" and acc=="pass" and sco=="pass":
    fs="done"
else:
    fs="pending"
rev["deterministic_pass"]=det; rev["final_status"]=fs
json.dump(rev, open(os.environ["REVIEW"],"w"), indent=2)
print(fs)
')"

# Assemble the human-readable report.
{
  echo "# Final report — run ${RUN_DIR##*/}"
  echo
  echo "_Generated: $(now_iso)_"
  echo
  echo "## Request"; echo
  [[ -f "$RUN_DIR/request.md" ]] && sed 's/^/> /' "$RUN_DIR/request.md" || echo "_(none)_"
  echo
  echo "## Acceptance criteria"; echo
  [[ -s "$RUN_DIR/acceptance-criteria.md" ]] && cat "$RUN_DIR/acceptance-criteria.md" || echo "_(not written)_"
  echo
  echo "## Scope"; echo
  echo '**Expected files:**'
  [[ -s "$RUN_DIR/expected-files.txt" ]] && sed 's/^/- /' "$RUN_DIR/expected-files.txt" || echo "_(none declared)_"
  echo; echo '**Run-introduced changes (`changed-files.txt`):**'
  [[ -s "$RUN_DIR/changed-files.txt" ]] && sed 's/^/- /' "$RUN_DIR/changed-files.txt" || echo "_(none)_"
  echo
  echo "## Deterministic verification (latest)"; echo
  if [[ -f "$latest" ]]; then
    LATEST="$latest" python3 -c '
import os,json
d=json.load(open(os.environ["LATEST"]))
print("Attempt {} ({}) - deterministic_pass = **{}**".format(d.get("attempt"), d.get("kind"), d.get("deterministic_pass")))
print()
print("| check | pass |")
print("|---|---|")
for k,v in (d.get("checks") or {}).items():
    mark = "PASS" if v.get("pass") else "FAIL"
    print("| " + k + " | " + mark + " |")
'
  else echo "_(no verification yet)_"; fi
  echo
  echo "## Attempt history"; echo
  for a in "$RUN_DIR"/verification/attempt-*.json; do
    [[ -e "$a" ]] || continue
    A="$a" python3 -c '
import os,json
d=json.load(open(os.environ["A"]))
ch=d.get("checks") or {}
fails=[k for k,v in ch.items() if not v.get("pass")]
line="- attempt-{} ({}): deterministic_pass={}".format(d.get("attempt"), d.get("kind"), d.get("deterministic_pass"))
if fails: line += " - failed: " + ", ".join(fails)
print(line)
'
  done
  echo
  echo "## Review state (\`review.json\`)"; echo
  [[ -f "$review" ]] && { echo '```json'; cat "$review"; echo; echo '```'; }
  echo
  echo "## Screenshots"; echo
  echo "- Baseline: \`baseline/baseline-1440.png\`, \`-768.png\`, \`-390.png\`"
  echo "- After: \`after/after-1440.png\`, \`-768.png\`, \`-390.png\`"
  echo "- Evidence: \`screenshots/\` (header-over, header-solid, footer-wordmark)"
  echo
  echo "## Verdict"; echo
  echo "- **final_status: \`$final_status\`**"
  if [[ "$final_status" == "done" ]]; then
    echo "- ✅ Deterministic + visual + acceptance + scope review all passed."
  else
    echo "- ⏳ Not DONE. DONE requires deterministic_pass AND visual_review=pass AND acceptance_criteria_pass=pass AND scope_review=pass."
    echo "  Fill these via: \`scripts/run.sh review <field> pass|fail\`"
  fi
} > "$report"

if [[ "$final_status" == "done" ]]; then pass "report written — final_status=DONE  ($report)"; exit 0
else warn "report written — final_status=$final_status (review pending)  ($report)"; exit 1; fi
