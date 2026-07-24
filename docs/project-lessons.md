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
