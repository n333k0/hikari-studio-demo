# Project Lessons (living log)

Append durable lessons here whenever we discover a recurring mistake or a better
way of working. This file — not conversation memory — is the source of truth for
"things we learned". Keep entries short, concrete, and prescriptive.

## How to add an entry
Add to the top of the log using this format:

    ### YYYY-MM-DD — <short title>
    - Context: what we were doing.
    - Lesson: the durable rule or better workflow.
    - Apply: exactly what to do next time.
    - Refs: related file/section (e.g. protected-regions.md → Footer wordmark).

Promote anything structural into the right home doc too:
- A new hard rule → protected-regions.md / change-workflow.md.
- A new check → verification-policy.md.
- A bug not to repeat → known-regressions.md.

## Log

### 2026-07-25 — A user correction is a system trigger; the user shouldn't have to name the file to fix
- Context: the user asked whether these conversations improve the system
  automatically, or whether they have to say "update `CLAUDE.md`" / "fix that
  skill" each time. The self-improvement rule already existed
  (`docs/ARCHITECTURE.md` §12, principle 10) — but it was worded as *"any
  session that **notices** a gap"*, which reads as self-initiated and never
  named a user correction as a trigger. It also required logging a lesson
  without requiring that the lesson's cause be *measured*. Both gaps had just
  produced a live failure: the `dash_probe` bug was "fixed" once with a
  guessed cause and a retry, and recurred.
- Lesson: a correction from the user is the strongest trigger of the
  improve-itself rule, and asking them to identify which artifact to change
  offloads the system's own job onto them. Route the fix to the most
  enforcing surface the risk bar allows — a hook or script beats a doc,
  because code runs and prose has to be remembered. Two hard rules attach:
  **"it happened again"** means the last fix treated a symptom, so reopen the
  diagnosis instead of stacking another mitigation; and **no lesson without
  evidence**, because a guess written as a finding makes the next session
  stop looking.
- Apply: on any user correction, fix + log in the same session unasked. When
  the cause is unknown, record what was ruled out and how to capture the
  evidence next time — never a theory phrased as a conclusion.
- Refs: `docs/ARCHITECTURE.md` §12 principle 10; `CLAUDE.md` → "This OS
  improves itself"; the entry directly below is the worked example.

### 2026-07-25 — `cmd | grep -q` under `pipefail` reports failure on success (the "dashboard not running" bug)
- Context: the `SessionStart` hook reported the WebsiteOS panel as "Not
  running" while the user had it open in a browser — twice, on two separate
  days. The probe was `curl -fsS "$url" | grep -q "WebsiteOS"` inside a
  script with `set -uo pipefail`. Measured, not guessed: `WebsiteOS` is at
  **byte 23** of the page (it's in the `<title>`), so `grep -q` matches and
  exits immediately while curl still has ~54KB to write; curl takes
  SIGPIPE/EPIPE and exits **23**; `pipefail` then hands the pipeline curl's
  failure even though the grep succeeded. 12 back-to-back runs gave
  `23 0 0 23 0 23 0 0 23 0 0 0` — a ~1-in-3 false negative, and it gets
  worse as the board grows, because a bigger page = more unwritten bytes.
- Lesson: **an early-exiting reader (`grep -q`, `head`, `read`) plus
  `pipefail` turns a successful match into a failed command.** The first fix
  attempt diagnosed this as an unexplained transient and added a retry,
  which only squared the odds (~11%) and left the wrong cause in the log —
  a symptom-level "fix" that shipped the same bug twice. When a check fails
  intermittently, get the actual exit code before theorising; `echo $?` in a
  loop found this in one command.
- Apply: never pipe into an early-exiting matcher under `pipefail`. Capture
  the body first, then match it: `body="$(curl ...)" || return 1` +
  `case "$body" in *needle*)`. Grep the repo for `curl .*|` before adding
  another probe — this was the only instance, keep it that way.
- Refs: `scripts/session-start-summary.sh` → `dash_probe()`;
  supersedes the earlier "retry before reporting not running" entry, whose
  diagnosis was wrong.

### 2026-07-25 — Fixed scale is the feature in furniture AR, not a limitation
- Context: asked whether we should let users resize the lamp in AR, "like IKEA".
  IKEA Place specifically does *not* allow it, for the opposite reason to the
  one the question assumes: the whole value of furniture AR is answering "does
  this fit in my room", and a resizable object cannot answer that.
- Lesson: before copying a competitor's affordance, check they actually have it
  — and if they don't, work out what they do instead. Here `ar-scale="fixed"`
  (which sends `#allowsContentScaling=0` to Quick Look) is already correct and
  should stay. What the big catalogues *do* offer is switching to a different
  **product variant** at its own true scale, which is a different feature.
- Apply: keep `ar-scale="fixed"` on every product. If someone wants "a smaller
  one", that is a link to the D50, not a scale control.
- Refs: `scripts/3d/README.md`; `productos/*/index.html` → `<model-viewer>`.

### 2026-07-25 — Build on an undocumented API only with a pin and a soft failure
- Context: the cord-length slider had to move a mesh inside the loaded model.
  model-viewer's public `model` API exposes materials and variants but no scene
  nodes, so the only route is its internal `Symbol(scene)` — and the page loaded
  the library from a floating `@^4` CDN range that could change under us.
- Lesson: reaching into internals is sometimes the only option, but only with
  two guardrails: **pin the exact version** so it cannot move on its own, and
  **write the feature to disappear rather than break** if the internals move
  anyway. Then verify that failure path deliberately instead of assuming it — I
  stubbed `Object.getOwnPropertySymbols` to hide the symbol and confirmed the
  slider stayed hidden, the model still loaded, and no console errors appeared.
- Apply: `@google/model-viewer@4.3.1` is pinned in all three PDPs (that also
  protects the hand-tuned FOV framing). Any code touching `Symbol(scene)` must
  bail out silently on a missing symbol/node/geometry. Re-run the stub test when
  bumping the pin.
- Refs: `product.js` → `setupCordSlider`; `scripts/3d/README.md` → cord slider.

### 2026-07-25 — A control that moves geometry invalidates the framing around it
- Context: the cord slider worked — the geometry moved correctly at every stop —
  but at the long end the shade slid straight out of the bottom of the frame,
  because `camera-target` was a fixed authored value tuned for the default cord.
- Lesson: test the *extremes* of a new range, not just that it responds. A
  mid-range screenshot looked perfect and would have shipped the bug.
- Apply: `apply()` recentres `camera-target` on the lamp each time, and writes it
  to the **attribute** so reopening the modal (which re-applies the authored
  framing) doesn't snap the camera off the subject. Verified by asserting the
  model's world bbox stays inside the camera frustum at 25/50/84/100 cm. Also
  re-check the modal's height budget: the slider pushed the "Ver en AR" button
  below the fold until the CTA was moved directly under the viewer.
- Refs: `product.js` → `setupCordSlider`; `scripts/screenshot/shoot-ar.mjs`.

### 2026-07-25 — One function, three consumers: the status line can't disagree with the board
- Context: the session-opening status and the WebsiteOS panel each computed
  "what's happening" separately — the hook had its own inline Python, the panel
  had its own JS. Same intent, two implementations, and the status line only
  had numbers at all when someone had remembered to start the panel.
- Lesson: two things that must always agree should not be two pieces of code.
  And when availability is what forces the duplicate ("the server might be
  off"), the fix is to make the one implementation runnable *without* the
  server, not to write a second one for the offline case.
- Apply: `summary_lines()` in `.claude/dashboard/server.py` is the only place
  the board's numbers are phrased. Three consumers share it: `/api/summary`
  (what the hook curls when the panel is up), `server.py --summary` (identical
  output, no daemon, what the hook falls back to), and the panel's own
  headline. `CLAUDE.md` tells sessions to render that line verbatim and never
  recompute or invent it. Verified both branches print byte-identical text.
- Also added, for the one incoherence tooling *can't* fix by construction:
  `kanban.commits_since_update` counts commits on main since `docs/KANBAN.md`
  was last edited. Past `KANBAN_STALE_AFTER_COMMITS` (4) the board and the
  status line both warn that finished work may still be sitting in "Por hacer".
  It can't detect a *wrong* card — only that the hand-maintained tracker is
  lagging, which is the honest, mechanical version of that warning.
- Refs: `.claude/dashboard/server.py` → `summary_lines()`, `read_kanban()`;
  `scripts/session-start-summary.sh`; `CLAUDE.md` opening block.

### 2026-07-25 — "0 agentes" was read as "nadie trabajando"; count sessions, don't infer them
- Context: the board said *"Ningún agente está trabajando ahora mismo"* and
  *"0 sesiones con señal"* while two Claude Code windows were actively editing
  the AR pipeline. Both statements were technically true and completely
  misleading: "agente" meant *locked git worktree*, and the session count only
  saw captain files someone had written by hand — the newest was 6 h stale.
- Lesson: two failures, and only one was wording. **(a)** A status panel must
  not report on one population (dispatched agents) in language the reader hears
  as another (anyone working). Name both, always, and never let a zero stand
  alone. **(b)** When a signal is missing, the fix is usually to *emit* it, not
  to soften the copy around it. There's no API for "list open chat windows", but
  every session runs hooks, so every session can leave a trace.
- Apply: `scripts/session-heartbeat.sh` writes/touches
  `.agent-state/captains/<session_id>.md`, wired to `SessionStart` (create +
  prune >24 h) and `PostToolUse` (touch). "Active" now means "used a tool in the
  last 20 min", which ages out a dead session by itself. It parses the hook JSON
  with `sed`, not `python3` — it runs after *every* tool call and an interpreter
  start-up per call is a real tax. It always exits 0; a heartbeat is never worth
  failing a tool call over. Known gap, stated in the panel's help: hooks load at
  session start, so a window opened before the hook existed stays uncounted
  until it restarts.
- Refs: `.claude/settings.json`, `scripts/session-heartbeat.sh`,
  `.claude/dashboard/index.html` → `renderSummary()`.

### 2026-07-25 — The ops panel is WebsiteOS, one screen, and speaks plain language
- Context: the dashboard was a long vertical page ("General y sus Soldados")
  whose metaphor-heavy copy (capitanes, soldados, cuartel general) and
  seven stacked sections meant you had to scroll and decode to answer "what is
  happening right now". The user asked for a name that generalises to other
  projects and for a board that's readable at a glance.
- Lesson: an ops panel earns its keep only if the whole state fits one viewport.
  The fix wasn't styling — it was picking a single organising model (a kanban of
  *work states*) and forcing every data source through it: agents, uncommitted
  changes, `docs/KANBAN.md` items, finished worktrees and recent commits are all
  just cards in `Por hacer / Trabado / En curso / Para revisar / Listo`. Anything
  that would add page height went into a slide-over drawer instead.
- Apply: the panel name is **WebsiteOS**, and the project half of the title is
  *derived* (`detect_project_name()` → `$WEBSITEOS_PROJECT` → `project-name.txt`
  → de-noised repo dirname), never hardcoded — that's what makes it droppable
  into the next project. Kanban headings map to columns by keyword
  (`classify_kanban_section()`), so a new section lands somewhere sensible
  without a code change; `Cross-references`-style sections are excluded from the
  board on purpose. If you rename the panel again, update the `SessionStart`
  probe in `scripts/session-start-summary.sh` — it greps the served HTML for the
  panel's own name to avoid announcing somebody else's localhost server.
- Refs: `.claude/dashboard/index.html`, `.claude/dashboard/server.py`,
  `scripts/session-start-summary.sh`, `docs/KANBAN.md` → "How the board reads this file".

### 2026-07-25 — Web AR anchors bbox-min-Y to the floor; a pendant must carry its own drop
- Context: "Ver en tu espacio" on the Ensui D70 put the lamp on the floor in the
  middle of the room with its cord standing up in the air. The model was built
  shade-at-the-bottom with the cord pointing up — geometrically inverted for
  something that hangs.
- Lesson: there is no ceiling anchor and no placement-height API anywhere in web
  AR (`ar-placement` is `floor|wall`; Scene Viewer has no height intent
  parameter; Quick Look ignores anchoring hints). All three runtimes rest the
  model's *lowest bounding-box point* on the detected plane, so hanging height
  is a property of the **geometry**, not of any attribute. Before reaching for a
  config flag, check whether the platform has the concept at all — here three
  separate feature requests had already been declined upstream.
- Apply: `scripts/3d/pendant_hang.py` — lift the lamp to its hanging height and
  hold the gap open with a small anchor mesh at y=0. The anchor must be
  **visible** (model-viewer measures the bbox with `traverseVisible()`) and must
  **not** be a flat transparent plane (`findBakedShadows`, `MIN_SHADOW_RATIO=100`,
  would classify it as a baked floor shadow and drop it from the bbox). Assert
  `bbox.min == 0` after the transform — that assertion is the fix's only canary.
  Also tell the user to point at the floor and *then look up*, or a correct
  placement reads as a failure.
- Refs: `scripts/3d/README.md`; known-regressions.md; model-viewer issues #998,
  #3446, #2930.

### 2026-07-25 — Throwing away a pipeline script is how the same bug ships twice
- Context: the WebP→USDZ violet-texture bug was fixed once for the D70, then
  shipped again in both products built after it. The cause wasn't the fix being
  wrong — it was that `docs/site-structure.md` recorded the pipeline as prose
  plus a dead `/private/tmp/...` path and told the next session to "rewrite it
  fresh next time."
- Lesson: a fix applied to an *artifact* doesn't fix the *step that produced
  it*. If a build step is documented as prose rather than committed code, every
  future run re-derives it — and re-derives its bugs. Prose is a description of
  a pipeline; a committed script is the pipeline.
- Apply: `scripts/3d/` is versioned (`pendant_hang.py`, `export_usdz.py`,
  `_common.py`, `README.md`), with the known-regression check baked in as an
  assertion rather than a note. `docs/site-structure.md` points at it instead of
  restating it. When a bug is found in generated output, ask whether the
  generator is in the repo — if not, that's the actual finding.
- Refs: `scripts/3d/README.md`; known-regressions.md; commits `4ccdcc5`, `ffa4403`.

### 2026-07-25 — `depsgraph` staleness makes Blender transforms silently no-op
- Context: `pendant_hang.py` reported lifting the lamp and shortening the cord,
  but the final bounding box was unchanged. Assigning `ob.location` does not
  update `ob.matrix_world` until the depsgraph re-evaluates, so every
  measurement taken right after a move read the *old* position — the cord got
  scaled about the wrong pivot and the verification bbox was a lie.
- Lesson: in Blender scripts, a measurement immediately after a mutation is
  reading stale state unless you flush it. This fails *quietly* and, worse, the
  self-verification prints confidently wrong numbers.
- Apply: `bpy.context.view_layer.update()` inside every bbox helper
  (`_common.sync()`), not at call sites where it's easy to forget.
- Refs: `scripts/3d/_common.py`.

### 2026-07-25 — A tool nobody links to doesn't exist: surface system surfaces in the status
- Context: the dashboard ("General y sus Soldados") was built and running on
  `localhost:8765`, but the `SessionStart` hook never mentioned it, so the
  opening status listed only the site's Pages links and the user had to ask for
  the dashboard link by hand.
- Lesson: anything that's part of the operating system of this project — not
  just site content — needs a printed entry point, or each session silently
  rediscovers (or forgets) it. Print the *live* URL when it's up and the start
  command when it isn't, so the line is never a guess.
- Apply: probe a local tool's real port range with bash `/dev/tcp` first (instant
  on a closed local port), then spend a `curl -m 2` only on open ports and grep
  for the tool's own name — that keeps a hung or unrelated service off the hook's
  15s budget and stops us announcing somebody else's server as ours.
- Refs: `scripts/session-start-summary.sh` → part 6; `CLAUDE.md` opening block.

### 2026-07-25 — "No worktree" is not "no work": foreground edits are invisible to the claim system
- Context: asked where an in-progress AR fix lived, this session checked every
  branch and every worktree, found them all clean or already merged, and told
  the user there was "no trace" of it. Wrong: it was live in `scripts/3d/` —
  uncommitted, in the main checkout, being written while the session spoke.
  The claim hook only scans *locked worktrees*, so ordinary foreground work by
  another session declares nothing and shows up nowhere.
- Lesson: a coordination signal keyed to a *mechanism* (worktree locks) only
  covers work that uses that mechanism. The most common shape of work — editing
  the main checkout directly — was the one shape the whole claim system couldn't
  see. Also: "I checked branches and worktrees" is not "I checked for work";
  uncommitted working-tree state is a first-class place work lives.
- Apply: `git status --porcelain` on the checkout is now part of the
  SessionStart print, each path annotated with the age of its newest file and
  flagged `LIKELY ACTIVE` under 90 minutes. Prefer *observational* fixes like
  this over new conventions when the gap involves a session that has no reason
  to know you exist — recency needs no cooperation from the other session. When
  asked "is anything working on X," check working-tree state, not just refs.
- Refs: `scripts/session-start-summary.sh` (part 3); ARCHITECTURE.md §13 →
  "The claim system's blind spot: foreground work in the main checkout".

### 2026-07-25 — Pick a dispatched agent's model by capability floor, not by name
- Context: user asked how model selection works when spawning soldados. It
  didn't — nothing in `CLAUDE.md`, `ARCHITECTURE.md` §13 or `KANBAN.md` said
  anything about it, so the choice was whatever the orchestrating session felt
  like that turn. The obvious fix (a table mapping task → model name) was
  rejected as the *wrong* fix: model names rotate every few months, so that
  table is stale on arrival, while the risk classes §13 already defines don't
  move.
- Lesson: an undeclared model choice silently sets the ceiling on every safety
  argument built on top of it. Write the durable half as a **capability floor
  per task class** and quarantine the volatile half (which model clears which
  floor today) to a couple of clearly-marked lines. Corollary: never degrade to
  fit what's available — "no model meets the floor" is a stop condition, same
  category as a protected-region change, not a reason to send the best one on
  hand and hope.
- Apply: omit the Agent tool's `model` param by default (inherit the
  orchestrator's). Passing it at all is an affirmative decision needing a
  one-line reason in the dispatch prompt. Only downgrade for work that follows
  an already-**validated** template with a provably isolated, reversible
  footprint. When the model roster changes, edit only the two marked lines in
  §13 — needing to edit the floor table means the floors were written in terms
  of model names after all.
- Refs: ARCHITECTURE.md §13 → "Choosing a soldado's model — capability floor,
  not model name"; §12 principle 2 (deterministic/reasoning boundary).

### 2026-07-25 — Independently-opened sessions need a way to see each other's active scope
- Context: user opened a second Claude Code session (dashboard work) while
  this session was active. Separately, this session found 7 old worktrees
  from a prior parallel-dispatch batch and, going only on the user's
  recollection ("terminado pero congelado sin mergear"), almost reported them
  as unmerged/at-risk — a byte-for-byte diff against `main` showed 6 of the 7
  were already fully merged (one even superseded by a newer `main` revision).
  Two distinct gaps: (1) nothing let this session know *what* the other live
  session was allowed to touch, only *that* a worktree was locked; (2) a
  verbal/remembered status ("frozen, not merged") had silently gone stale
  and would have been trusted without the diff.
- Lesson: in a multi-session setup, (a) "locked" is not "scoped" — knowing an
  agent is active tells you nothing about what it's safe to avoid, unless
  scope is declared somewhere machine-readable; (b) any claim about
  merge/freeze/done state (yours, the user's, or a doc's) is a hypothesis
  until checked against a real `diff`/`git log` — state drifts fast when
  multiple sessions touch the same repo.
- Apply: (a) — built the claim-file system: `.agent-state/claims/<worktree>.md`
  declares scope, `session-start-summary.sh` surfaces it for every locked
  worktree, `CLAUDE.md` instructs sessions to read it and route around
  claimed paths. Soft/informational today; hard `PreToolUse` enforcement is
  deferred (KANBAN backlog #7) until claim-cleanup discipline is proven out.
  (b) — before reporting anything as "already done"/"still pending"/"frozen",
  diff it against the actual current state of `main` (or the live site) —
  don't relay a remembered or stated status as fact.
- Refs: `docs/ARCHITECTURE.md` §13 "Declaring scope at lock time"; `docs/KANBAN.md`
  backlog #7.

### 2026-07-25 — Blender USD/usdz export keeps the source texture codec (webp breaks Quick Look)
- Context: regenerated `ensui-d70.usdz` via Blender headless after editing the
  `.glb` (added a cord canopy cap). Deployed it, and the user saw the whole
  lamp render solid violet/magenta in real AR Quick Look on their iPhone —
  looked "fine" in every check I ran myself first, because I only verified
  the `.glb` path (desktop Chrome / model-viewer), never the `.usdz` path.
- Lesson: solid magenta/violet in an AR viewer is the standard "texture
  failed to bind" fallback, not a lighting/material-color issue. Root cause
  here: `bpy.ops.wm.usd_export` re-exports each texture using its *current*
  Blender image codec, and the source `.glb`'s images were WebP (normal for
  web glTF) — AR Quick Look/RealityKit does not reliably decode WebP inside
  a `.usdz`, only PNG/JPEG. Also: simply setting `image.file_format = 'PNG'`
  on a WebP-backed image datablock is not enough — Blender's own internal
  texture-copy step still failed on it; the reliable fix was converting to
  real PNG files on disk and loading them as fresh `bpy.data.images.load()`
  datablocks swapped into the material's `TEX_IMAGE` nodes. Separately, the
  zip-bundling step for direct `.usdz` export failed with a `chown` sandbox
  permission error in this environment — exporting to plain `.usdc` (which
  skips that step) then verifying with `pxr.Usd.Stage.Open` worked instead.
- Apply: after ANY regeneration of a `.usdz`/`.glb` pair, unzip the `.usdz`
  and confirm `textures/*` are `.png`/`.jpg` (`file textures/*`), and verify
  the material's texture asset paths with `pxr.UsdShade` — don't just check
  the `.glb` in a desktop browser and call the pair verified, since the two
  files use different renderers with different codec support.
- Refs: known-regressions.md → Ensui D70 AR model rendered solid violet.

### 2026-07-25 — AR/hardware features must be deployed to be verified, so deploy proactively
- Context: fixed the Ensui D70 AR preview (camera framing was cropping the
  model; the pendant's cord had no ceiling-mount cap). All of it was fixable
  and testable locally in a desktop browser — but the user still needed a
  live URL to check the real AR session (Quick Look) on their phone, and had
  to ask for it explicitly.
- Lesson: no local/desktop tool can verify real-device AR, camera, GPS, or
  other hardware-gated features — only the live site on the actual device
  can. Waiting to be asked to deploy wastes a round-trip every time.
- Apply: the moment a change touches an AR/camera/GPS/sensor feature, commit
  + push + poll the Pages build + hand back the live URL immediately, without
  being asked. Say clearly what you verified yourself vs. what only the user
  can confirm on-device.
- Refs: verification-policy.md → Hardware-dependent features.

### 2026-07-25 — `overflow-x:hidden` on `<body>` silently breaks `position:sticky`
- Context: building the pinned scroll gallery + sticky purchase bar on the
  Ensui D70 product page — every `position:sticky` element (the pinned
  gallery row, the sticky purchase bar) rendered as `position:sticky` in
  computed styles but behaved like `static`, scrolling away immediately.
- Lesson: `body { overflow-x: hidden }` (used site-wide to clamp full-bleed
  layout from causing horizontal scroll) makes `body`, not the viewport, the
  effective scroll container in some browsers — which breaks `sticky` for
  everything inside it. `html { overflow-x: hidden }` avoids this because
  `html` is already the real scrolling element, so it's a no-op for that
  concern.
- Apply: overflow-x clamps belong on `<html>`, never `<body>`, on any page
  that uses (or might later use) `position:sticky`. Already fixed globally
  in `styles.css`.
- Refs: known-regressions.md.

### 2026-07-25 — `position:sticky`'s range is bounded by its immediate parent, not any tall ancestor
- Context: same pinned-gallery build — after fixing the overflow-x issue
  above, the sticky gallery row still only stuck for a few px before
  scrolling away, despite sitting inside a 4050px-tall scroll wrapper.
- Lesson: a sticky element only has "room to stick" for as long as its
  *direct parent's* box is on screen — not any distant tall ancestor. If the
  direct parent auto-sizes to the sticky child's own height (e.g. a `.container`
  div that just wraps it), the sticky range collapses to ~nothing even though
  a grandparent wrapper is genuinely tall.
- Apply: when building a "pin while a tall region scrolls past" effect, the
  tall element must be the sticky item's *immediate* containing block —
  don't put a shrink-wrapped div directly between them.
- Refs: `product.css` → `.pdp-gallery-scroll` / `.pdp-top`.

### 2026-07-24 — Verify both breakpoints, every time
- Context: fixes were confirmed on desktop but broke mobile (and vice-versa).
- Lesson: a change is not verified until seen at BOTH 1440px and 390px.
- Apply: screenshot desktop + mobile for any visual change before "done".
- Refs: verification-policy.md.

### 2026-07-24 — Hero image swaps have side effects
- Context: swapping the hero image repeatedly broke text legibility, header
  contrast, and the mobile crop.
- Lesson: the hero image is coupled to the scrim, the header state, and cropping.
- Apply: after any hero image change, re-verify scrim/text legibility, header
  contrast at the top, and the 390px crop.
- Refs: known-regressions.md → Fragile coupling.

### 2026-07-24 — Full-width text wordmark = SVG, not vw font
- Context: a vw-sized "HIKARI STUDIO" overflowed and clipped on the right.
- Lesson: to fill the content width with equal gutters, use an SVG cropped to the
  glyph ink bounds (canvas measureText actualBoundingBox*), width:100%.
- Apply: never size an edge-to-edge wordmark with a vw font; re-measure the
  viewBox if the text/font/weight/letter-spacing changes.
- Refs: protected-regions.md → Footer wordmark.

### 2026-07-24 — `hidden` needs `!important` against display rules
- Context: a hidden section reappeared because its class set display:grid.
- Lesson: `[hidden]{display:none!important}` must stay in the reset.
- Apply: hide sections with the `hidden` attribute; keep the reset rule.
- Refs: known-regressions.md.

### 2026-07-24 — Carousels keep the container gutter (no bleed hack)
- Context: negative-margin "bleed" + padding-inline left the first card at x=0.
- Lesson: leading padding is ignored on overflow-x grid tracks; the bleed hack
  misaligns the first card.
- Apply: tracks keep the container gutter so card 1 aligns with the heading.
- Refs: protected-regions.md → Carousels.

### 2026-07-24 — Scope discipline beats speed
- Context: concurrent/formatter edits and unrelated tweaks crept into commits.
- Lesson: list expected files before editing; compare after; revert surprises.
- Apply: follow Scope Protection every change; commit only intended files.
- Refs: change-workflow.md → Scope Protection.
