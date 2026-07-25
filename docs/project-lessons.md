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
