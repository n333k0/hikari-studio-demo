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
