# ARCHITECTURE — the Website OS

> The single document to read to understand the whole system. It explains the
> *architecture and its rationale*, not line-by-line implementation. For commands
> see `website-change-system.md`; for rules see `change-workflow.md`,
> `website-spec.md`, `protected-regions.md`, `known-regressions.md`,
> `verification-policy.md`; for accumulated lessons see `project-lessons.md`.

---

## 0. What this is

The "Website OS" is a small, local orchestration layer that turns *changing a
website* into a governed process. The website itself (`index.html`, `styles.css`,
assets) is a dependency-free static artifact. The OS is everything around it that
makes a change **safe, verifiable, scoped, and reproducible** — whether the editor
is a human or an AI agent.

It is deliberately *not* a framework. It is a handful of single-purpose bash
scripts, one Node screenshot tool, a state directory, and a set of documents that
are treated as the source of truth. Nothing is installed into the website; the OS
lives beside it in `scripts/`, `docs/`, and `.agent-state/`.

---

## 1. Philosophy

The core belief: **a website change is a software change and deserves the same
discipline** — a specification, a baseline, verification against reality, bounded
scope, and protection of invariants. Most website regressions are not caused by
hard bugs; they are caused by *unbounded, unverified edits* — a "quick tweak" that
silently breaks a breakpoint, re-introduces forbidden copy, or clips an element
off-screen.

From that belief follow the system's guiding ideas:

- **Intent is captured before code changes.** A request is rewritten into
  acceptance criteria first. You cannot verify what you did not define.
- **Reality is measured, not assumed.** "It should work" is not evidence. The OS
  observes the rendered page and asserts facts about it.
- **Scope is a first-class constraint.** Every run declares the files it may
  touch; anything else that changes is a failure, not a convenience.
- **Invariants are protected by default.** The design language, header behavior,
  hidden sections, copy rules, and the footer wordmark do not change unless a
  request explicitly targets them.
- **Small, composable, honest tools.** One responsibility per script; fail loudly;
  never report success you cannot prove.
- **Documents are the source of truth; scripts are executable documents.** Each
  check cites the rule it enforces, so the prose and the automation cannot drift
  apart silently.

---

## 2. Why deterministic verification is separated from AI reasoning

There are two fundamentally different kinds of "correct," and conflating them
makes a verification system untrustworthy.

- **Objective correctness** — measurable, reproducible facts: *is there horizontal
  overflow? are the footer gaps equal? are the hidden sections still hidden? did
  forbidden copy reappear? does the responsive contract hold?* These have a single
  right answer that a machine can compute identically every time.
- **Interpretive correctness** — judgment calls: *does the hero still look right?
  is this actually the change that was asked for? are the changed files
  semantically in scope?* These require understanding intent and aesthetics.

The architecture draws a hard line between them:

- **Deterministic scripts** produce evidence (screenshots, measurements) and
  booleans. No AI is in this loop. This keeps the layer trustworthy, reproducible,
  and CI-able: the same inputs always yield the same verdict.
- **AI reasoning** consumes that evidence to make the interpretive calls it is good
  at, and to author the parts a machine cannot (acceptance criteria, the actual
  edit, the diagnosis of a failure).

The payoff:

1. **Attributable failure.** When a run fails you know *which layer* failed — a
   measurable regression (script) or a judgment gap (review).
2. **An honest gate.** DONE requires *both* layers to agree. Passing scripts alone
   is never DONE, because "no overflow" does not mean "looks right"; and an AI
   "looks fine" can never override a red deterministic check.
3. **A promotable core.** Because the deterministic layer has no AI in it, it can
   be lifted into CI unchanged — a machine gate that runs without a human or model
   present.

---

## 3. The complete execution graph

```
        ┌─────────────────────────────────────────────────────────────┐
        │                        A WEBSITE CHANGE                       │
        └─────────────────────────────────────────────────────────────┘

  REQUEST ──▶ ACCEPTANCE ──▶ BASELINE ──▶ IMPLEMENT ──▶ VERIFY ──▶ REVIEW ──▶ DONE
              CRITERIA                                    │  ▲          │
   (reason)   (reason)     (script)      (reason)      (script)         │(reason)
                                                        │  │            │
                                                        │  └──── REPAIR ◀┘ (if REVIEW fails)
                                                        │       (reason, ONE cause)
                                                        └──── re-VERIFY (attempt-1..3, max 3)
                                                                    │
                                                              still failing after
                                                              3rd repair ──▶ ESCALATE
```

Ownership of each node:

| Phase              | Owner        | Produced artifact                          |
|--------------------|--------------|--------------------------------------------|
| REQUEST            | reason+script| `request.md`, a fresh run dir              |
| ACCEPTANCE CRITERIA| reasoning    | `acceptance-criteria.md`, `expected-files.txt` |
| BASELINE           | script       | `baseline/` (git state + inventory + PNGs) |
| IMPLEMENT          | reasoning    | the minimal edit to website files          |
| VERIFY             | script       | `verification/attempt-N.json`, `after/`, `changed-files.txt` |
| REVIEW             | reasoning    | `review.json` fields set                   |
| REPAIR             | reasoning    | a fix targeting one diagnosed cause        |
| DONE               | script+reason| `final-report.md`, `final_status`          |

The graph is intentionally *not* a fully autonomous loop. IMPLEMENT, ACCEPTANCE,
REVIEW, and REPAIR are reasoning nodes because no script can author intent, edit
code toward a goal, or judge whether pixels look right. The orchestrator runs the
deterministic nodes and hands control back at each reasoning boundary.

---

## 4. Major components and responsibilities

| Component | Responsibility |
|---|---|
| `scripts/run.sh` | **Orchestrator.** Subcommands (`start/baseline/verify/review/report/status`) advance the graph, own the run directory, aggregate results, track attempt counters, and enforce the repair ceiling. It is the only component that knows the *sequence*. |
| `scripts/lib.sh` | **Shared substrate.** Repo-root resolution (never CWD), the `chrome-devtools-axi` eval wrapper, the Playwright `shot()` delegate, JSON emit/merge helpers. No verification logic — pure plumbing. |
| `scripts/capture-baseline.sh` | Snapshot the pre-change world: git head/branch/porcelain status + a hashed file inventory + baseline screenshots. Enables "what changed *during this run*" later. |
| `scripts/verify-*.sh` (6) | **The deterministic checks.** Each protects exactly one invariant and emits one result. (Detailed in §9.) |
| `scripts/capture-after.sh` | Snapshot the post-change world, diff it against the baseline to separate *pre-existing* from *run-introduced* changes, and compute the scope result against `expected-files.txt`. |
| `scripts/generate-report.sh` | Fold everything into `final-report.md` and compute `final_status`. Enforces that DONE needs deterministic + visual + acceptance + scope. |
| `scripts/screenshot/shoot.mjs` | **The screenshot engine (Playwright).** One job: render a URL at a viewport and write a verified PNG to an absolute path. (Rationale in §5.) |
| `.agent-state/` | **Run memory.** Per-run artifacts and history; gitignored. (Rationale in §7.) |
| `docs/*.md` | **The governing knowledge.** Spec, workflow, protected regions, regressions, verification policy, lessons — the rules the scripts enforce and the humans/agents follow. |

A key structural property: the verification scripts communicate with the
orchestrator only through a **stable contract** — each writes a small JSON result
to `verification/parts/<name>.json` and returns an exit code. The orchestrator
merges parts without knowing what any check does. That contract is the system's
extensibility seam (§11).

---

## 5. Why Playwright handles screenshots

Screenshots are **evidence**, and evidence that can silently vanish is worse than
no evidence — it produces false confidence.

The original approach used `chrome-devtools-axi screenshot`. Investigation of the
source showed its browser process (`chrome-devtools-mcp`) runs every file write
through `validatePath()`, which only permits paths inside a set of *allowed roots*
(effectively the process's temp directory / the agent sandbox). Writes outside
those roots are rejected — **and the CLI prints the requested path as success
regardless**, because it never checks the tool's result. The consequence: images
appeared to be captured but landed nowhere portable, and the only writable
location was an environment-specific scratchpad.

That is disqualifying for a verification system meant to run on any machine, so
screenshots were moved to **Playwright**, used through a dedicated module:

- **Portable and unsandboxed.** Playwright drives its own browser and writes via
  Node `fs` to *any* absolute path — proven to write into the run directory and
  `/tmp` alike, with no scratchpad dependency.
- **Verifiable and loud.** The module confirms the file exists and is non-empty
  after capture, and exits non-zero with a clear error if not. There is no silent
  "success."
- **Decoupled and single-purpose.** It knows nothing about `chrome-devtools-axi`;
  its interface is `--url/--out/--width/--height/--eval`. It can be swapped or
  reused independently.

The cost — one dependency and a one-time browser download — is deliberately paid
by the *tooling*, not the website. The site stays dependency-free; Playwright and
its `node_modules` are isolated under `scripts/screenshot/` and gitignored.

---

## 6. Why chrome-devtools-axi handles browser inspection

DOM inspection has different requirements from screenshots, and the right tool for
it is a live, stateful, queryable browser session:

- **Rich, repeated querying.** Checks need computed styles, bounding rectangles,
  class state, and the results of *interaction* — e.g. "scroll to the marquee,
  then assert the header flipped to solid." `chrome-devtools-axi`'s `eval` runs
  arbitrary JS in a persistent page and returns structured values, which is
  exactly this shape of work.
- **Already present and ergonomic.** It is available in the environment, fast, and
  purpose-built for agent-driven DOM interrogation.
- **Statefulness that screenshots do not need.** A screenshot is a one-shot render;
  DOM verification is a conversation with a page that holds state between calls.

So the architecture runs **two engines with a clean boundary**:
`chrome-devtools-axi` observes and interrogates the DOM; Playwright renders and
captures. Each is used only for what it is best at, and neither leaks into the
other. (Screenshots that must match an interaction — the solid header, the footer
wordmark — reproduce that state via Playwright's `--eval`, so the two engines stay
independent yet produce consistent evidence.)

---

## 7. Why `.agent-state` exists

A run generates two categories of data: **source** (the website and the tooling,
which belong in git) and **run history** (evidence, results, orchestration state,
which do not). `.agent-state/` is the boundary between them.

It exists to give every change an auditable, self-contained record:

- **Accountability unit.** Each `runs/<timestamp>/` is one change attempt with its
  request, criteria, declared scope, baseline, after-state, screenshots, per-attempt
  verification results, review decisions, and final report.
- **History, not just latest.** Verification results are preserved per attempt
  (`attempt-0..3.json` + `latest.json`) so you can see *what failed, what was
  repaired, and whether the system converged* — a signal about whether the process
  itself is healthy.
- **Separation of concerns.** Orchestration state and attempt counters live apart
  from verification results, so "how many repairs" is never entangled with "what
  the checks found."
- **Reproducibility and forensics.** Because the baseline captures a hashed file
  inventory, the after-state can distinguish changes that *pre-existed* the run
  from changes the run *introduced* — the difference between "someone else's dirty
  tree" and "this task's edit."

It is gitignored on purpose: it is a ledger of process, not a part of the product.

---

## 8. The lifecycle of a website change

A single change flows through the OS like this:

1. **REQUEST.** `run.sh start "<request>"` mints `runs/<ts>/`, records the request,
   and initializes state and review files. The run becomes "current."
2. **ACCEPTANCE CRITERIA.** The editor (AI or human) rewrites the request into a
   pass/fail checklist in `acceptance-criteria.md` — including the change itself
   *and* the invariants it must not break — and declares the permitted blast radius
   in `expected-files.txt`. Ambiguity is resolved *here*, before code moves.
3. **BASELINE.** `run.sh baseline` freezes the pre-change truth: git identity,
   dirty state, a hashed inventory, and screenshots at the canonical widths.
4. **IMPLEMENT.** The editor makes the *smallest* change that satisfies the
   criteria — ideally one property, never a refactor.
5. **VERIFY.** `run.sh verify` captures the after-state, runs every deterministic
   check, computes the scope diff, and writes `attempt-0.json`. It exits non-zero
   if any check fails.
6. **REVIEW.** The editor reads the evidence — `after/` vs `baseline/` screenshots,
   `verification/latest.json`, `changed-files.txt` vs `expected-files.txt` — and
   records judgment in `review.json`: does it look right, does it meet the criteria,
   is the scope clean?
7. **REPAIR (if needed).** On any failure, the editor diagnoses *one* cause, fixes
   *only* that, and re-runs `verify` (§10).
8. **DONE.** `run.sh report` writes `final-report.md` and sets `final_status` to
   `done` only when deterministic **and** visual **and** acceptance **and** scope
   all pass. Anything less is `pending` (or `escalated`).

Every phase leaves an artifact, so the run is legible after the fact by someone who
was never present for it.

---

## 9. The role of each verification script

Each check is small, deterministic, and exists because it protects a real, learned
invariant — not a hypothetical one.

- **`verify-overflow.sh`** — asserts `scrollWidth == clientWidth` at every
  breakpoint (1440/1024/768/641/640/390). Horizontal overflow is the most common
  and most visible responsive regression; it is checked at the desktop, tablet
  edges, mobile edges, and mobile.
- **`verify-header.sh`** — asserts the header state machine: transparent/white
  `--over` at the top of the hero, flipping to solid-white/black `--solid` once the
  marquee scrolls into view, with the logo inverting. This behavior was
  hand-tuned repeatedly; the check pins it.
- **`verify-hidden-sections.sh`** — asserts `#historia` (mission) and `#acabado`
  (finish rail) remain non-rendered. They are intentionally hidden and must not
  reappear as a side effect of an unrelated edit.
- **`verify-copy.sh`** — a static guard that forbids "made in Argentina / Buenos
  Aires" claims. The lamps are not made there; this is a factual/brand invariant,
  and the one check that needs no browser.
- **`verify-footer.sh`** — asserts the giant footer wordmark keeps equal gaps on
  left/right/bottom and is not clipped. The wordmark is a fragile, measurement-tuned
  SVG; this catches regressions to it directly.
- **`verify-layout.sh`** — asserts the *reliably measurable* parts of the
  responsive contract (gutter, hero-CTA direction, value-tile columns, and that the
  hero title scales and fits). It deliberately does **not** assert aesthetic density
  ("does it look balanced") — that is captured as screenshot evidence for human
  review instead of pretending it is deterministic.

Plus a scope check (from `capture-after.sh`): run-introduced files must be a subset
of `expected-files.txt`; unexpected changes fail deterministically.

Together they encode "the site is still itself." Each cites its governing doc in a
header comment so the check and the rule stay synchronized.

---

## 10. The repair loop

Repair is **bounded and diagnostic**, not a retry-until-green scramble.

- **Numbering.** `attempt-0` is the verification *after the initial
  implementation* — it is **not** a repair. `attempt-1..3` are verifications after
  repairs #1–#3. The ceiling is **three repairs**.
- **Cycle shape.** A repair cycle is strictly: *failed verification → diagnose the
  exact cause → fix only that cause → verify again.* No speculative edits, no
  bundling of unrelated fixes.
- **Termination.** If the third repair passes, the run may finish. If verification
  still fails after the third repair, the orchestrator refuses a fourth and the run
  **escalates** — the system stops and explains, rather than thrashing.
- **Separation of counters from results.** The attempt/repair count lives in the
  run's orchestration state, distinct from the verification result files, so
  "how hard was this" and "what was wrong" never contaminate each other.
- **Why bounded.** A cap forces *diagnosis over guessing*, prevents infinite
  flailing, and — because every attempt is preserved — makes it visible whether the
  system is converging or oscillating. A change that needs more than three targeted
  repairs is a signal that the request or the approach is wrong, and a human should
  look.

---

## 11. Future extension points

The system was built to grow along its existing seams, without redesign:

- **New deterministic checks.** Add a `verify-<thing>.sh` that emits the standard
  `parts/<name>.json` and an exit code; the orchestrator aggregates it
  automatically. The parts-JSON contract *is* the plugin API.
- **Visual regression.** The natural next layer: diff `after/` against committed
  baseline PNGs (e.g. pixel comparison) to catch unintended visual change. The
  screenshot engine already produces the inputs.
- **Live / deploy verification.** A `verify-live` step that checks the published
  URL and gates on the GitHub Pages build, extending the loop past DONE into deploy.
- **CI promotion.** Because the deterministic layer has no AI in it, `run.sh verify`
  can run in CI and gate deployment — the same gate, now enforced by a machine.
- **New signal classes.** Accessibility, performance (Lighthouse), link-checking,
  and multi-page routes all fit as additional single-responsibility checks.
- **Engine evolution.** The two-engine split is an implementation choice behind
  stable interfaces (`browser_eval`, `shot`); either engine can be swapped without
  touching the graph or the checks.

The invariants that make extension safe: the JSON contract, the review-state schema,
and the exit-code convention (0 = pass, non-zero = fail/not-done).

---

## 12. Design principles future contributors must preserve

1. **One responsibility per script.** If a script needs "and," split it.
2. **Keep the deterministic/reasoning boundary sharp.** Never let AI judgment
   decide a measurable fact, and never assert an aesthetic judgment as if it were
   deterministic — capture evidence instead.
3. **Documents are the source of truth.** Checks enforce documented rules and cite
   them; when behavior changes, update the doc in the same breath.
4. **Scope protection is sacred.** Declare expected files before editing; treat any
   unexpected change as a failure, not a convenience.
5. **Fail loudly; never claim unproven success.** The screenshot rewrite exists
   precisely because a tool reported success it could not back up. Verify, then
   report.
6. **Stay portable and dependency-light.** No scratchpad or machine-specific paths;
   resolve everything from the repo root, not the current directory. Keep the
   *website* dependency-free; confine tooling dependencies to the tooling.
7. **Bound the repair loop.** Diagnose one cause, fix one cause, cap the attempts,
   and escalate honestly.
8. **Preserve history.** Never overwrite a run's attempt records; the ledger is how
   we learn whether the system is improving.
9. **Prefer the smallest change.** The whole apparatus exists to make minimal,
   verified edits — not to enable large ones faster.

If a future change would violate one of these, that is the signal to stop and
reconsider the design — not to weaken the principle.
