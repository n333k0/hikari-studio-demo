---
name: quick-site
description: Daily one-shot workflow for Hikari Studio site edits — classify risk, implement the smallest change, verify with Playwright, repair only what failed, done. Use for copy/color/spacing/component/responsive edits. Trigger — "/quick-site <request>". Escalates to the full run.sh workflow for genuinely high-risk or ambiguous-scope changes.
---

# /quick-site — one-shot implement + verify + repair

You are the ONE builder/verifier for this task. No sub-agents, no handoffs.
This project also has a full governed workflow (`docs/change-workflow.md`,
`scripts/run.sh start…report`) for high-risk or multi-invariant changes — this
skill is the fast path for everything else, which is most days.

**Working directory:** all commands below assume CWD is the `hikari-site/`
project root (three levels above this file: `.claude/skills/quick-site/` →
`hikari-site/`). `cd` there first if you're not already.

**Deterministic tools available** (`scripts/run.sh quick …`) — you decide
risk and scope; the scripts only screenshot and check:
```
scripts/run.sh quick --baseline --risk <low|medium|high>   # screenshot BEFORE
scripts/run.sh quick --verify   --risk <low|medium|high>   # screenshot AFTER + run checks
scripts/run.sh quick --suggest-risk                          # advisory guess, non-authoritative
```
`--verify` prints pass/fail per check to stderr and writes
`/tmp/hikari-quick/result.json` with `{"pass": bool, "checks": {...}, "details": {...}}`
(details populated only for failed checks — that's your repair evidence).

---

## Workflow

```
REQUEST → CLASSIFY RISK → INSPECT MINIMUM FILES → BASELINE →
IMPLEMENT SMALLEST CHANGE → VERIFY → (REPAIR ONLY FAILURES → VERIFY)×≤3 →
DONE or ESCALATE
```

### 1. Classify risk (your judgment — the only authoritative call)

- **low** — isolated copy edit, color value, one CSS property/spacing tweak.
  Confined to `styles.css`, no layout/behavior implication.
- **medium** — component or responsive adjustment (carousel, CTA layout,
  spacing across breakpoints) — touches `styles.css` and maybe `index.html`
  structure, but scope is still one component.
- **high** — hero image, header behavior, navigation, global typography, or
  broad/structural layout change. Also: **if you're not confident about scope
  after reading the request, treat it as high** rather than guessing low.

You may run `scripts/run.sh quick --suggest-risk` as one advisory data point
(it's a file-extension heuristic from `git diff`, nothing more) — it does not
override your own read of the request. If the request's blast radius is
genuinely ambiguous or clearly matches the full workflow's high-risk examples
in `docs/protected-regions.md`, **stop and escalate now**:
```
scripts/run.sh start "<the original request>"
```
then follow `docs/change-workflow.md` instead of continuing this skill.

### 2. Inspect minimum relevant context

Read only what the change touches — the relevant CSS rule(s) or HTML section,
not the whole file. Check `docs/protected-regions.md` and
`docs/known-regressions.md` only for the specific area you're editing (e.g.
editing the footer wordmark → read the Footer section of both, not the rest).
Do not re-read `ARCHITECTURE.md` or the full docs set for a quick task — that
context does not change between runs.

### 3. Baseline

```
scripts/run.sh quick --baseline --risk <level>
```
Screenshots land in `/tmp/hikari-quick/baseline/`. This is scratch space —
it's overwritten by the next quick-site run, on purpose.

### 4. Implement the smallest change

Edit only what the request requires. One property over a refactor. Do not
touch unrelated rules, do not "improve while you're here" — see
`docs/change-workflow.md` → Protected Invariants.

### 5. Verify

```
scripts/run.sh quick --verify --risk <level>
```
- **All pass →** go to DONE (step 7).
- **Any fail →** go to REPAIR (step 6).

### 6. Repair (only if verify failed)

Build your repair context from **only**:
- the original request,
- which check(s) failed (from the printed `✗ <name>` lines / `result.json`
  `"checks"`),
- `details` for the failed check(s) in `result.json` (has the actual
  measured values, e.g. which breakpoint overflowed),
- `git diff` of the file(s) you edited (not the whole repo),
- the relevant screenshot(s) in `/tmp/hikari-quick/after/`.

Do **not** re-read passing checks, do not re-fetch the full docs, do not
re-inspect files you haven't touched. Diagnose the ONE cause of the failure,
fix only that, then repeat step 5.

**Maximum 3 repair attempts.** If still failing after repair #3, stop and
escalate:
```
scripts/run.sh start "<original request>"
```
Report to the user what failed and why, then follow the full workflow from
`docs/change-workflow.md` (baseline/acceptance-criteria/bounded repair) — do
not attempt a 4th quick repair.

### 7. Done

Print only:
```
status: DONE (or ESCALATED)
risk: <low|medium|high>
files changed: <list>
checks run: <list, e.g. overflow, copy>
repairs: <count, 0-3>
screenshots: /tmp/hikari-quick/{baseline,after}/*.png
unresolved: <none, or what's left if escalated>
```
No verbose report, no JSON ledger, no run directory. This is not recorded in
`.agent-state/` — that's reserved for the full workflow.

---

## Hard constraints

- **Never commit or push.** The user does that.
- **Never** run the full `run.sh start/baseline/verify/report` graph from
  inside this skill except as the explicit escalation path in steps 1 or 6.
- **One agent, no delegation.** Don't spawn sub-tasks for this.
- **Don't re-read the whole repo on repair.** Context in step 6 is scoped on
  purpose — that's the whole point of this skill over the full workflow.
- If asked to do something this skill's risk tiers don't cover well (e.g. a
  multi-page change, a new dependency, a build step) — escalate rather than
  force it through `quick`.
