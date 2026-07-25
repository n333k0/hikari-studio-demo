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
10. **The OS improves itself, continuously, at two different speeds.** Any
    session that notices a gap in *this system* (not site content — the
    hooks, scripts, docs, or conventions in `scripts/`, `docs/`, `.claude/`)
    should fix it in the same session, not defer it to a future ask. But
    "fix it" splits by risk, the same way site changes already split by risk
    in `CLAUDE.md`:
    - **Safe → adjust directly.** Additive, reversible, non-gating changes:
      a new `SessionStart` hook section, a documentation clarification, a
      new backlog item, a bug fix in a script with an obvious correct
      behavior, a new lesson logged. Do it, verify it (run the script, check
      the syntax), report what changed.
    - **Risky or ambiguous → propose and ask first**, the same bar as any
      other high-risk change: anything that could *gate or block* a future
      session's actions (e.g. a `PreToolUse` hook that refuses edits —
      see §13's hard-enforcement claim system, deliberately deferred for
      this reason), anything that changes an existing policy's meaning
      (what counts as "Validated?", a verification threshold, a protected
      region), or anything whose blast radius isn't obviously contained.
    - **Either way, log it in `docs/project-lessons.md`.** A safe fix made
      without a trace is a fix the next session can't learn from; the lesson
      log is what makes "improves itself" cumulative instead of one-off.

If a future change would violate one of these, that is the signal to stop and
reconsider the design — not to weaken the principle.

---

## 13. Parallel agent dispatch — composing independent units of work

> This section extends the OS beyond a single change. §1–§12 describe how *one*
> editor safely makes *one* change. This section describes when it is safe to run
> *several* editors — as background agents in isolated git worktrees — at the same
> time, and what to do when their work turns out not to be as independent as it
> looked.

### Philosophy

Sections 1–12 assume one editor, one change, one shared checkout — that is where
`run.sh`'s baseline/verify/repair loop and `/quick-site`'s fast path both live, and
it is the right model whenever a change touches the site's *shared* surface
(`index.html`'s structure, `styles.css`, `main.js`, `product.js`, `product.css`,
the header/nav). But some requests aren't one change; they are N independent
changes that happen to be batched together — "build the next three product pages,"
for instance. Running those serially wastes wall-clock time for zero safety
benefit, because the discipline in §1–§12 exists to protect *shared* invariants,
and provably independent new files (a product's own folder, its own 3D model)
can't collide on anything to protect.

So a second, complementary pattern exists: **parallel background agent dispatch**
via isolated git worktrees, for the subset of a request that is provably
independent. It is a *dispatch layer above* `run.sh` and `/quick-site`, not a
replacement for either — every agent dispatched into a worktree still follows
`/quick-site` or the full `run.sh` workflow internally for its own slice of work.
Parallelism changes *how many editors run right now*; it never relaxes what any
one editor is required to do once it is running.

### Mechanism

**When a unit of work is parallel-safe.** A task is safe to dispatch alongside
others in the same batch when its entire footprint is files that exist *only* for
that task — the canonical shape is one new `productos/<slug>/` folder plus that
product's own `models/<slug>.glb` / `.usdz`. No task in a batch may need to touch a
file that another concurrent task, or the live site's shared surface, also needs —
if scope isn't actually disjoint, it isn't parallel-safe, however small each
individual edit looks.

**When it needs a human check-in first, not blind dispatch:**
- The task's *primary* deliverable is a shared file — `index.html`, `styles.css`,
  `main.js`, `product.js`, `product.css` — not a corner discovered mid-task
  (that's the "flag, don't edit" case below, which is different).
- The task touches the header/nav protected region (`docs/protected-regions.md`).
  Protected regions are protected precisely *because* they're shared, fragile,
  hand-tuned invariants; `/quick-site` already treats a solo change there as
  high-risk, so dispatching several agents at it in parallel multiplies collision
  risk instead of dividing it.
- The request has no defined acceptance criteria yet. Parallel dispatch presumes
  each agent can verify its own work against a clear bar; an ill-defined request
  can't be verified, so it isn't a parallel-dispatch candidate — it's a scoping
  problem, and the answer is a **scout** task (below), not N agents guessing in
  parallel.
- No available model meets the task's capability floor (see "Choosing a
  soldado's model" below). Dispatching a weaker model at a task that needs a
  stronger one is a silent downgrade of the whole safety argument, so the
  answer is to stop and check in — never to send the best model on hand and
  hope.

**The "flag, don't edit" convention.** When a dispatched agent discovers, mid-task,
that it needs to change a file shared with the rest of the batch or with the live
site (most often `index.html`), it must **not** make that edit. It states exactly
what needs to change and why in its final report, and stops there. These flagged
needs are **batched into one deliberate follow-up edit** — applied together, by a
human or a single later dedicated step — rather than let two or more parallel
agents each quietly touch the same shared file, where they could collide outright
or apply the same kind of change in two different styles.
`docs/site-structure.md` carries a living "Pending shared-file edits" list for
exactly this — see the worked example below for its first real entries. This
convention is specific to *shared* files that *more than one* task in the batch
might need; a shared file that only one task in the batch touches (nothing else
concurrent needs it) has no collision to avoid and can simply be edited directly —
see the overflow-fix agent in the worked example.

**The "scout" task shape.** For work whose scope is undefined or that targets a
protected region, dispatch a **read-only, no-edits** investigation agent instead of
a "ship" agent. Its job is to look, compare against whatever reference the request
implies, and come back with a written proposal — not to make the change blind.
This turns an ambiguous or high-risk request into either (a) a scoped,
now-parallel-safe follow-up task, or (b) a decision point for a human, before any
edit happens. Scout and ship are the two task shapes this pattern dispatches; a
scout never becomes a ship mid-run — its output is a proposal, reviewed, *then* a
new ship task is dispatched (or the full `run.sh` workflow is used) if the
proposal is approved.

**Open-ended investigation also belongs in the background, even alone.** This
isn't only about running several agents at once. A single open-ended investigation
or diagnosis — "why does X happen," "audit Y against Z" — is itself multi-step and
unpredictable in length. Doing it in the foreground of the orchestrating session
blocks that session for however long the investigation takes, which defeats the
reason this pattern exists in the first place: keeping the orchestrating
conversation unblocked. A scout task is dispatched to a background agent even when
there is exactly one of it.

**Relation to `run.sh` and `/quick-site`.** This layer answers "how many
independent editors should run right now"; `run.sh` and `/quick-site` each still
answer "how does a single editor safely make one change," and neither question
replaces the other. A single high-risk or ambiguous-scope change is still routed
through `run.sh`'s full graph (or `/quick-site`'s own escalation path) exactly as
§1–§12 describe — it is never fanned out into a parallel batch just because a
batch happened to be running. Use this pattern only when a request genuinely
decomposes into multiple units of work with disjoint file scope.

### Worked example (2026-07-25)

This is the run that this section codifies, not a hypothetical:

1. **Two ship agents in parallel** each built one new, independent
   product-detail page — `productos/ensui-d50/` and `productos/ikigai-s/`. Safe
   to run together because each agent's entire footprint was its own new folder
   plus its own `models/<slug>.glb`/`.usdz` — never a file the other agent, or
   the live site, also needed.
2. **One scout agent**, explicitly told read-only/no-edits, audited the mobile
   hamburger menu against the Gantri reference. This touches the protected
   header/nav region and had no defined acceptance criteria yet, so it was not
   dispatched as a ship task — it came back with a written proposal instead of a
   blind edit.
3. **Two more agents**, dispatched in parallel because their file scopes didn't
   overlap: one fixed the real bug the scout had found (mobile horizontal
   overflow) directly in `styles.css` — a shared file, but only this one agent in
   the batch needed it, so no flag was necessary, it just made the fix; the other
   hardened the overflow-check tooling itself, confined to `scripts/`.
4. **Both product-page agents independently hit the same shared-file need**:
   each had to point the home page's product card `href="#"` at its new real
   page — an `index.html` edit needed by both. Per instructions, **neither agent
   made that edit.** Each flagged it precisely in its final report instead, so a
   human (or one later dedicated step) applies both link updates together in a
   single, deliberate, reviewed change — rather than two parallel agents quietly
   racing to touch the same file. Those two items are the first real entries in
   `docs/site-structure.md`'s "Pending shared-file edits" list, seeded 2026-07-25
   and still unapplied as of this writing (neither product page is merged into
   `main` yet).

### Why not a new skill for this

`/quick-site` is explicitly single-agent/no-delegation (its own SKILL.md says so),
and `run.sh` is a single-run verify/repair graph — neither is the right home for
"decide how many independent editors to dispatch right now," and neither needed to
change. But that decision is a judgment call about *when* to fan out work, not a
fixed, scriptable procedure the way `/quick-site`'s baseline→verify→repair loop is
(which has real deterministic checks behind each step) — there is no new
deterministic tool to package. `CLAUDE.md` already carries an unconditional,
every-session instruction to propose a parallel batch when one is warranted, which
is a stronger trigger than a skill description a model has to judge as relevant;
this section is the reference that instruction points to. A dedicated skill file
would mostly duplicate this section and the CLAUDE.md instruction, with the same
staleness risk §12 already warns about for any doc, so one was not added.

### Why a SessionStart hook, not just the doc-read convention

The one part of this pattern a doc-read convention alone handles poorly is
**cross-session memory of flagged, not-yet-applied shared-file edits** — that's
specifically a session-boundary problem, not a knowledge problem, and hooks exist
for exactly that class of problem. A minimal, read-only `SessionStart` hook
(`.claude/settings.json`) runs `git worktree list` (parallel work may already be
in flight) and prints the "Pending shared-file edits" section of
`docs/site-structure.md` verbatim into context at the start of every session —
deterministically, the same way §2's verification scripts surface ground truth
instead of trusting an agent to remember or to scroll to the right subsection. It
does not gate anything and changes no site file; if it can't find its markers it
says so loudly rather than silently showing nothing, in keeping with design
principle 5 (§12).

### Declaring scope at lock time — the claim file

"Flag, don't edit" (above) and "Pending shared-file edits" are both
*retrospective* — they record a shared-file need discovered mid-task, after work
already happened. They don't help a **second, independently-opened session** —
e.g. the user opens a fresh Claude Code window to work on something else while a
background agent from an earlier dispatch is still running — know *what the
still-running agent is allowed to touch* before that second session starts
editing anything. That's a distinct, forward-looking problem: declaring scope
*at* lock time, not flagging a collision after the fact.

**The convention.** Whenever a session locks a git worktree for background or
parallel work (`git worktree lock`, whether the worktree was created via the
Agent tool's `isolation: "worktree"` or a manually-opened separate session), its
first action after locking — before any edit — is to write a small claim file at
`.agent-state/claims/<worktree-dir-name>.md` (matching the worktree's directory
basename under `.claude/worktrees/`) stating, in plain markdown: the task in one
line, the allowed scope (paths/globs it may touch), and anything explicitly
forbidden. `.agent-state/` is already gitignored local run-memory (§7), so this
is machine-local coordination state, not a committed artifact.

**Surfacing.** `session-start-summary.sh` scans `.git/worktrees/*/locked` for
every currently-locked worktree and prints that worktree's claim file verbatim
(or a loud `NO CLAIM FILED — unknown scope` warning if one is missing) in a
dedicated section, right after the worktree list. `CLAUDE.md` instructs the
opening reply of every session to read that section and state plainly which
paths are currently claimed by another live agent — and, if the user's request
would touch a claimed path, to say so and propose a non-overlapping or
read-only alternative instead of just proceeding.

**Cleanup is best-effort, not safety-critical.** A claim file for a worktree
that has since been unlocked or removed is simply never read again — the hook
only inspects *currently-locked* worktrees, so a stale claim file left behind
is inert rather than misleading. Deleting it when a worktree unlocks is good
hygiene, not a requirement.

**The claim system's blind spot: foreground work in the main checkout.** Claims
are keyed to *locked worktrees*, so a session editing the primary checkout
directly — the normal shape of ordinary foreground work — declares nothing and
appears nowhere. This is not a rule anyone broke; the convention simply never
covered it. It bit for real on 2026-07-25: a session inspected every branch and
worktree, found all of them clean or merged, and told the user there was "no
trace" of an AR fix that was at that moment live in `scripts/3d/` — uncommitted,
in the main checkout, invisible to every signal the hook printed.

The fix is deliberately *observational*, not another convention to remember:
`session-start-summary.sh` prints `git status --porcelain` for this checkout and
annotates each path with the age of its newest file, flagging anything touched
within 90 minutes as `LIKELY ACTIVE`. Recency is what distinguishes live work
from stale leftovers, and it needs no cooperation from the session doing the
work — which is the point, since that session has no reason to know another one
just opened. It stays a soft signal like everything else here: it says "someone
may be mid-edit on this path," never "you may not touch it."

**This is a soft signal today, not an enforced one.** Nothing currently stops a
session from editing a claimed path — the claim file is informational, and the
guarantee rests on every session actually reading and respecting it (the same
trust model as the rest of this doc-driven system). A harder guarantee — a
`PreToolUse` hook that inspects the target path of every `Edit`/`Write` call
against active claim files and refuses the ones that collide — is a deliberate
future step, not built yet (see `docs/KANBAN.md`). Soft was chosen first
because it's low-risk and immediately useful, and because a hard block needs
the claim-cleanup discipline above to actually be reliable first — an enforced
block against a stale, un-cleaned-up claim would wrongly refuse legitimate
work.

### Choosing a soldado's model — capability floor, not model name

Every dispatched agent runs on *some* model. Left implicit, that choice drifts
with whoever is orchestrating that day, which makes it exactly the kind of
undeclared variable §12 principle 2 warns about — a judgment call quietly
deciding something the rest of the safety argument depends on.

**Express the rule as a capability floor per task class, never as a fixed
model name.** Model names rotate every few months; the risk classes this
section already defines (ship vs. scout, isolated vs. shared footprint,
protected region or not) do not. A doc that hardcodes "new product page →
model X" is stale the day X is superseded, with the same staleness risk §12
warns about for any doc. So the durable half of the rule is the floor:

| Class | The work | Floor |
|---|---|---|
| **Mechanical** | Following an already-**validated** template, footprint provably isolated, fully reversible | A downgrade is permitted, with a stated reason |
| **Judgment** | Anything that *decides* rather than executes — scout tasks, audits, design, diagnosing a failure, writing docs or conventions | The orchestrator's own model |
| **Irreversible** | Protected region, shared file as the primary deliverable, no acceptance criteria yet | Not dispatched at all — human check-in (see the list above) |

**Default to inheriting; make downgrade the justified exception.** Omitting the
Agent tool's `model` parameter inherits the orchestrator's model, and that is
the correct default for almost every dispatch. Passing `model` at all is an
affirmative decision that needs a one-line reason in the dispatch prompt
itself, so the agent's own transcript records why it was run at that level.
This makes the system fail toward *expensive* rather than toward *wrong* —
the right direction when the failure mode of "too weak" is a plausible-looking
edit that nobody caught.

**Never degrade to fit what's available.** If nothing on hand meets the floor,
that is a stop condition, not a reason to send the strongest available model
and hope — it is the last bullet in "needs a human check-in first" above,
deliberately filed there rather than given its own mechanism.

**The volatile half, expected to change — keep it to these two lines.** As of
2026-07-25 the `model` parameter accepts `sonnet`, `opus`, `haiku`, and
`fable`. Only one downgrade is currently considered safe: `haiku` for
Mechanical-class work. `fable` has no assigned class here because nobody on
this project has evaluated it for these task shapes — an unassigned model is
not an implicitly-permitted one. When the roster changes, edit *these two
lines only*; if a change seems to require editing the table above, that is a
signal the floors were written in terms of model names after all.

**This is a soft signal too.** There is no pre-dispatch check that a given
model is actually available or actually clears a floor — the parameter takes a
fixed enum and a bad choice surfaces as a poor result, not as a refusal. Like
the claim files above, this rests on each session applying it honestly rather
than on tooling enforcing it.
