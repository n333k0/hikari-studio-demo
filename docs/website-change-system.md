# Website Change System (V1)

A lightweight, local, no-framework orchestration of the workflow in
`docs/change-workflow.md`. It runs the **deterministic** phases as small focused
scripts and hands the **reasoning** phases back to Claude.

```
REQUEST → ACCEPTANCE CRITERIA → BASELINE → IMPLEMENT → VERIFY
        → REVIEW → REPAIR → VERIFY → DONE
```

- **Deterministic (scripts):** BASELINE, VERIFY (overflow/header/hidden/copy/footer/layout + scope), report.
- **Claude reasoning:** ACCEPTANCE CRITERIA, IMPLEMENT, REVIEW, REPAIR, final DONE sign-off.
- No installs. Uses `bash`, `python3` (stdlib), `git`, and `chrome-devtools-axi`.
- Verifies the **local** working copy (`file://…/index.html`). No live/deploy check in V1.

## Scripts (`scripts/`)
| Script | Responsibility |
|---|---|
| `lib.sh` | Shared helpers (paths from repo root, `chrome-devtools-axi` wrappers, JSON). Support only. |
| `run.sh` | Orchestrator: `start · baseline · verify · review · report · status`. |
| `capture-baseline.sh` | Record git head/branch/status + hashed file inventory + baseline screenshots. |
| `verify-overflow.sh` | `scrollWidth==clientWidth` at every breakpoint. |
| `verify-header.sh` | Header `--over` at top → `--solid` after the marquee (logo inverts). |
| `verify-hidden-sections.sh` | `#historia` and `#acabado` stay hidden. |
| `verify-copy.sh` | No "made-in-Argentina" copy (static grep). |
| `verify-footer.sh` | Footer wordmark equal gaps L/R/B, no clip. |
| `verify-layout.sh` | Responsive contract (gutter/CTA-direction/value-cols/h1) — only reliably measurable props. |
| `capture-after.sh` | After screenshots; diff vs baseline (pre-existing vs run-introduced); scope check. |
| `generate-report.sh` | Assemble `final-report.md`, compute `final_status`. |

## Run artifacts (`.agent-state/runs/<timestamp>/`, gitignored)
```
request.md                 acceptance-criteria.md     expected-files.txt
baseline/  (git-head.txt, git-branch.txt, git-status.txt,
            files-present-before.txt, baseline-*.png)
after/     (after-*.png, files-present-after.txt)
screenshots/  (header-over.png, header-solid.png, footer-wordmark.png)
changed-files.txt          (run-introduced changes only)
verification/  (attempt-0.json … attempt-3.json, latest.json, parts/)
run-state.json             (phase + attempt counters — SEPARATE from results)
review.json                (deterministic/visual/acceptance/scope/final)
final-report.md
```

## Repair-cycle rules
- `attempt-0` = verification **after the initial implementation** (not a repair).
- `attempt-1..3` = verification after repairs #1–#3. **Max 3 repairs.**
- If the 3rd repair passes, the run may finish. Escalate only if verification
  still fails after the 3rd repair. `run.sh verify` refuses a 4th repair.

## DONE gate
`final_status` becomes `done` **only** when:
`deterministic_pass == true` AND `visual_review == pass` AND
`acceptance_criteria_pass == pass` AND `scope_review == pass`.
Passing deterministic checks alone is **not** DONE.

---

## Exact commands — one complete example

Task: *"Make the hero subtitle slightly dimmer."*

```bash
cd hikari-site   # (any CWD works; scripts resolve the repo root themselves)

# 1) REQUEST
scripts/run.sh start "Make the hero subtitle slightly dimmer (rgba white ~0.72)."

# 2) ACCEPTANCE CRITERIA  (Claude edits the run's files)
#    .agent-state/runs/<ts>/acceptance-criteria.md   → the pass/fail checklist
#    .agent-state/runs/<ts>/expected-files.txt        → e.g. a single line: styles.css

# 3) BASELINE
scripts/run.sh baseline

# 4) IMPLEMENT  (Claude makes the minimal edit to styles.css)

# 5) VERIFY  → writes verification/attempt-0.json
scripts/run.sh verify

# 6) REVIEW  (Claude looks at after/ vs baseline/ screenshots + verification.json,
#             confirms scope from changed-files.txt vs expected-files.txt)
scripts/run.sh review visual_review pass
scripts/run.sh review acceptance_criteria_pass pass
scripts/run.sh review scope_review pass

# 7) REPAIR (only if VERIFY failed): Claude fixes ONE cause, then:
# scripts/run.sh verify      # → attempt-1.json (repair #1), etc. (max 3)

# 8) DONE
scripts/run.sh report        # → final-report.md, final_status=done (or pending)

# anytime:
scripts/run.sh status
```

Exit codes: `0` success, non-zero on verification/scope failure or when the run
is not yet DONE — so the orchestrator (or CI later) can branch on them.

## Screenshot engine (Playwright)
Two-engine split: **chrome-devtools-axi = DOM inspection**, **Playwright = screenshots**.
`chrome-devtools-axi`'s screenshot is sandboxed by `chrome-devtools-mcp` (it only
writes inside its allowed roots and reports success even when nothing is written),
so it is NOT used for capture. Instead `lib.sh` `shot()` delegates to the dedicated
module `scripts/screenshot/shoot.mjs`, which uses Playwright to write PNGs directly
into the run dir — any path, any machine, no scratchpad — and **fails loudly** if the
image is missing.

One-time setup (per machine):
```bash
cd scripts/screenshot
npm install               # installs playwright
npx playwright install chromium
```
`scripts/screenshot/node_modules/` is gitignored. The CLI:
```bash
node scripts/screenshot/shoot.mjs --url <url> --out <ABS.png> \
     [--width 1440] [--height 900] [--eval "<js before capture>"] [--full-page]
```

## Environment notes
- **Requires bash 3.2+** (macOS default 3.2 is supported — no associative arrays used).
