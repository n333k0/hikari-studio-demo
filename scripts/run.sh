#!/usr/bin/env bash
# run.sh — ORCHESTRATOR for the website-change verification loop.
# Runs the DETERMINISTIC phases and hands control back to Claude for the
# REASONING phases (acceptance criteria, implement, review, repair).
# Graph:  REQUEST → ACCEPTANCE CRITERIA → BASELINE → IMPLEMENT → VERIFY
#         → REVIEW → REPAIR → VERIFY → DONE
# Subcommands: start | baseline | verify | review | report | status | help
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MAX_REPAIRS=3

usage() {
  cat >&2 <<EOF
website-change-system — orchestrator

FULL WORKFLOW (multi-contributor, high-risk changes):
  scripts/run.sh start "<request>"   REQUEST: create a run, write request.md
  scripts/run.sh baseline            BASELINE: capture git + screenshots
  scripts/run.sh verify              VERIFY: run all checks → verification/attempt-N.json
  scripts/run.sh review <f> <v>      REVIEW: set a review.json field
  scripts/run.sh report              DONE: assemble final-report.md + final_status

QUICK (deterministic primitives for the /quick-site skill — normally not called by hand):
  scripts/run.sh quick --baseline --risk <low|medium|high>
                                     Screenshot the CURRENT page at the widths for that
                                     risk tier, into /tmp/hikari-quick/baseline/.
  scripts/run.sh quick --verify --risk <low|medium|high>
                                     Screenshot the current page (after/), run the checks
                                     for that risk tier, print pass/fail.
  scripts/run.sh quick --suggest-risk
                                     ADVISORY file-extension guess from git diff. Not
                                     authoritative — risk is a Claude judgment call.

UTILITY:
  scripts/run.sh status              show current run state
EOF
}

cmd="${1:-help}"; shift || true

case "$cmd" in
# --------------------------------------------------------------------- QUICK ----
# Deterministic primitives ONLY. No request text, no NLU, no risk judgment here —
# that's the /quick-site skill's job (see .claude/skills/quick-site/SKILL.md).
# This subcommand just takes a risk LEVEL the caller already decided and executes
# the matching screenshots + checks. Fixed, non-timestamped dir: this is scratch
# space for one quick-site run, not part of the .agent-state ledger.
quick)
  QDIR="/tmp/hikari-quick"
  sub="${1:-}"; shift || true

  # NOTE: no `exit` inside this — it can be called via $(...), where exit only
  # kills the subshell. Callers validate the (possibly empty) result themselves.
  widths_for() { case "$1" in
    low)    echo "1440" ;;
    medium) echo "1440 390" ;;
    high)   echo "1440 768 390" ;;
  esac; }

  case "$sub" in
    --suggest-risk)
      changed=(); while IFS= read -r f; do [[ -n "$f" ]] && changed+=("$f"); done < <(quick_changed_files)
      if (( ${#changed[@]} == 0 )); then echo "none"; exit 0; fi
      classify_risk "${changed[@]}"
      ;;

    --baseline)
      risk=""
      while [[ $# -gt 0 ]]; do case "$1" in --risk) risk="$2"; shift 2 ;; *) shift ;; esac; done
      [[ -n "$risk" ]] || { fail "usage: run.sh quick --baseline --risk <low|medium|high>"; exit 2; }
      read -r -a widths <<< "$(widths_for "$risk")"
      (( ${#widths[@]} > 0 )) || { fail "risk must be low|medium|high (got: $risk)"; exit 2; }
      rm -rf "$QDIR"; mkdir -p "$QDIR/baseline"
      for w in "${widths[@]}"; do shot "$QDIR/baseline/${w}.png" "$w" 900 || warn "baseline ${w}px failed"; done
      echo "$risk" > "$QDIR/.risk"
      pass "baseline ($risk, ${widths[*]}px) → $QDIR/baseline/"
      ;;

    --verify)
      risk="$(cat "$QDIR/.risk" 2>/dev/null || echo "")"
      while [[ $# -gt 0 ]]; do case "$1" in --risk) risk="$2"; shift 2 ;; *) shift ;; esac; done
      [[ -n "$risk" ]] || { fail "usage: run.sh quick --verify --risk <low|medium|high> (or run --baseline first)"; exit 2; }
      read -r -a widths <<< "$(widths_for "$risk")"
      (( ${#widths[@]} > 0 )) || { fail "risk must be low|medium|high (got: $risk)"; exit 2; }

      export RUN_DIR="$QDIR"
      mkdir -p "$QDIR"/{after,verification/parts}
      rm -f "$QDIR"/verification/parts/*.json
      for w in "${widths[@]}"; do shot "$QDIR/after/${w}.png" "$w" 900 || warn "after ${w}px failed"; done
      run_risk_checks "$risk"

      RD="$QDIR" python3 <<'PY'
import os, json, glob
rd = os.environ["RD"]
checks = {}
for p in sorted(glob.glob(f"{rd}/verification/parts/*.json")):
    name = os.path.splitext(os.path.basename(p))[0]
    try: checks[name] = json.load(open(p))
    except Exception: checks[name] = {"pass": False, "details": "unreadable"}
ok = all(v.get("pass") for v in checks.values()) and len(checks) > 0
json.dump({"pass": ok, "checks": {k: v.get("pass") for k, v in checks.items()},
           "details": {k: v.get("details") for k, v in checks.items() if not v.get("pass")}},
          open(f"{rd}/result.json", "w"), indent=2)
PY
      ok="$(python3 -c 'import json;print(json.load(open("'"$QDIR"'/result.json"))["pass"])')"
      if [[ "$ok" == "True" ]]; then
        pass "verify ($risk): all checks PASS"
      else
        fail "verify ($risk): FAILED"
        python3 -c 'import json;d=json.load(open("'"$QDIR"'/result.json"));[print("  ✗ "+k) for k,v in d["checks"].items() if not v]' >&2
      fi
      dim "screenshots: $QDIR/{baseline,after}/*.png  result: $QDIR/result.json"
      [[ "$ok" == "True" ]] && exit 0 || exit 1
      ;;

    *)
      fail "usage: run.sh quick --baseline --risk <level> | --verify --risk <level> | --suggest-risk"
      exit 2
      ;;
  esac
  ;;

# ---------------------------------------------------------------- REQUEST ----
start)
  req="${1:-}"; [[ -n "$req" ]] || { fail "usage: run.sh start \"<request>\""; exit 2; }
  ts="$(date +%Y%m%d-%H%M%S)"; rd="$RUNS_DIR/$ts"
  mkdir -p "$rd"/{baseline,after,screenshots,verification/parts}
  printf '%s\n\n_captured: %s_\n' "$req" "$(now_iso)" > "$rd/request.md"
  cat > "$rd/acceptance-criteria.md" <<'EOF'
# Acceptance criteria
<!-- Claude writes this before IMPLEMENT. One checklist line per criterion,
     including the change itself AND the invariants it must not break. -->
- [ ] ...
EOF
  cat > "$rd/expected-files.txt" <<'EOF'
# Files Claude expects to modify for this task (one repo-relative path per line).
# Being listed here only PERMITS a change; it does not make the change correct.
EOF
  head="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
  BH="$head" TS="$ts" MR="$MAX_REPAIRS" python3 -c 'import os,json;json.dump({"run_id":os.environ["TS"],"created":__import__("datetime").datetime.now().isoformat(),"baseline_head":os.environ["BH"],"phase":"request","verify_count":0,"repair_attempts":0,"max_repair_attempts":int(os.environ["MR"])},open(os.sys.argv[1],"w"),indent=2)' "$rd/run-state.json"
  python3 -c 'import json,sys;json.dump({"deterministic_pass":False,"visual_review":"pending","acceptance_criteria_pass":"pending","scope_review":"pending","final_status":"pending"},open(sys.argv[1],"w"),indent=2)' "$rd/review.json"
  printf '%s' "$rd" > "$CURRENT_RUN_PTR"
  pass "run started: $rd"
  dim  "next → Claude writes acceptance-criteria.md + expected-files.txt, then: scripts/run.sh baseline"
  ;;

# --------------------------------------------------------------- BASELINE ----
baseline)
  rd="$(resolve_run)" || exit 2
  "$LIB_DIR/capture-baseline.sh" || { fail "baseline failed"; exit 1; }
  python3 -c 'import json,sys;p=sys.argv[1];d=json.load(open(p));d["phase"]="baseline";json.dump(d,open(p,"w"),indent=2)' "$rd/run-state.json"
  dim "next → Claude IMPLEMENTS the change, then: scripts/run.sh verify"
  ;;

# ----------------------------------------------------------------- VERIFY ----
verify)
  rd="$(resolve_run)" || exit 2
  # attempt index = number of existing attempt files (0 = initial).
  idx=$(ls "$rd"/verification/attempt-*.json 2>/dev/null | wc -l | tr -d ' ')
  if (( idx > MAX_REPAIRS )); then
    fail "escalate: already ran initial + $MAX_REPAIRS repair attempts. Stop and explain (per change-workflow.md)."
    exit 3
  fi
  kind="initial"; (( idx > 0 )) && kind="repair"
  log ""; dim "── VERIFY: attempt-$idx ($kind) ──"

  # capture-after first (screenshots + changed-files + scope part)
  bash "$LIB_DIR/capture-after.sh" || true
  # deterministic checks (each writes verification/parts/<name>.json)
  for s in verify-overflow verify-header verify-hidden-sections verify-copy verify-footer verify-layout; do
    bash "$LIB_DIR/$s.sh" || true
  done

  # merge parts → attempt-N.json + latest.json
  RD="$rd" IDX="$idx" KIND="$kind" TS="$(now_iso)" python3 <<'PY'
import os,json,glob
rd=os.environ["RD"]; idx=int(os.environ["IDX"])
checks={}
for p in sorted(glob.glob(f"{rd}/verification/parts/*.json")):
    name=os.path.splitext(os.path.basename(p))[0]
    try: checks[name]=json.load(open(p))
    except Exception: checks[name]={"pass":False,"details":"unreadable"}
det=all(bool(v.get("pass")) for v in checks.values()) and len(checks)>0
attempt={"attempt":idx,"kind":os.environ["KIND"],"timestamp":os.environ["TS"],
         "deterministic_pass":det,"checks":checks}
json.dump(attempt, open(f"{rd}/verification/attempt-{idx}.json","w"), indent=2)
json.dump(attempt, open(f"{rd}/verification/latest.json","w"), indent=2)
# update run-state (attempt count kept SEPARATE from verification results)
sp=f"{rd}/run-state.json"; st=json.load(open(sp))
st["phase"]="verify"; st["verify_count"]=idx+1; st["repair_attempts"]=idx
json.dump(st, open(sp,"w"), indent=2)
# update review.json deterministic flag only
rp=f"{rd}/review.json"; rv=json.load(open(rp)); rv["deterministic_pass"]=det
json.dump(rv, open(rp,"w"), indent=2)
print("PASS" if det else "FAIL")
PY
  det=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["deterministic_pass"])' "$rd/verification/latest.json")
  log ""
  if [[ "$det" == "True" ]]; then
    pass "attempt-$idx ($kind): deterministic checks PASS"
    dim  "next → Claude REVIEW (visual + acceptance + scope), set review.json, then: scripts/run.sh report"
    exit 0
  else
    fail "attempt-$idx ($kind): deterministic checks FAIL"
    if (( idx >= MAX_REPAIRS )); then
      warn "reached $MAX_REPAIRS repair attempts — ESCALATE (stop and explain), do not attempt a 4th."
    else
      dim "next → Claude diagnoses ONE cause, REPAIRS only that, then: scripts/run.sh verify"
    fi
    exit 1
  fi
  ;;

# ----------------------------------------------------------------- REVIEW ----
review)
  rd="$(resolve_run)" || exit 2
  field="${1:-}"; value="${2:-}"
  case "$field" in visual_review|acceptance_criteria_pass|scope_review) ;; *) fail "field must be visual_review|acceptance_criteria_pass|scope_review"; exit 2;; esac
  case "$value" in pass|fail|pending) ;; *) fail "value must be pass|fail|pending"; exit 2;; esac
  python3 -c 'import json,sys;p=sys.argv[1];d=json.load(open(p));d[sys.argv[2]]=sys.argv[3];json.dump(d,open(p,"w"),indent=2)' "$rd/review.json" "$field" "$value"
  pass "review.$field = $value"
  ;;

# ------------------------------------------------------------------- DONE ----
report)
  rd="$(resolve_run)" || exit 2
  "$LIB_DIR/generate-report.sh"; rc=$?
  python3 -c 'import json,sys;p=sys.argv[1];d=json.load(open(p));d["phase"]="done";json.dump(d,open(p,"w"),indent=2)' "$rd/run-state.json" 2>/dev/null || true
  exit $rc
  ;;

# ----------------------------------------------------------------- STATUS ----
status)
  rd="$(resolve_run)" || exit 2
  echo "run: $rd"
  [[ -f "$rd/run-state.json" ]] && { echo "--- run-state.json ---"; cat "$rd/run-state.json"; echo; }
  [[ -f "$rd/review.json" ]] && { echo "--- review.json ---"; cat "$rd/review.json"; echo; }
  [[ -f "$rd/verification/latest.json" ]] && { echo "--- latest deterministic ---"; python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print("attempt",d["attempt"],d["kind"],"pass=",d["deterministic_pass"]);[print("  ",k,v["pass"]) for k,v in d["checks"].items()]' "$rd/verification/latest.json"; }
  ;;

help|-h|--help) usage ;;
*) fail "unknown command: $cmd"; usage; exit 2 ;;
esac
