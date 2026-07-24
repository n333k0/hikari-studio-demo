# Protected Regions

Do NOT change these unless the request explicitly targets them. If a task seems to
require changing one, stop and confirm first.

## Locked design decisions
- Accent color `#E5381F` (red). Do not revert to Gantri green.
- Full-bleed layout: `--container:100%`, gutters 32px / 16px.
- No drop shadows; pill buttons; square imagery.

## Header (styles.css `.header*`, index.html header + inline JS)
- Per-breakpoint layout: desktop logo-left/nav-center/icons-right; ≤1024px
  hamburger-left/logo-center/icons-right. Keep explicit `grid-column` per child.
- Logo height 50px, width auto (no distortion); `brightness(0)` on `--solid`.
- Solid-state trigger tied to the marquee at ~0.7·innerHeight. The marquee element
  must remain present directly after the hero.

## Hero (`.hero*`)
- Centered white text; white-fill + white-outline CTAs — NEVER red on the hero.
- Keep the vignette + top scrim (legibility). Only use text-free hero images.
- CTAs stack and hug their text on mobile.

## Carousels (`.track*`)
- Keep the container gutter on both sides (first card aligns with the heading).
- Do NOT reintroduce the negative-margin bleed.

## Footer wordmark (index.html `.footer__wordmark-svg`)
- It is an SVG whose `viewBox="7.5 -97.3 947.1 98.6"` equals the measured ink
  bounds of "HIKARI STUDIO" at Inter 800, letter-spacing -3px, with width:100%
  inside a gutter-padded box (equal left/right/bottom gaps).
- If you change the text, font, weight, or letter-spacing you MUST re-measure the
  ink bounds (canvas `measureText` actualBoundingBox*) and reset the viewBox.
  A `vw` font-size is NOT acceptable (it clips).

## Content / structure
- `#historia` (mission) and `#acabado` (finish rail) stay hidden via the `hidden`
  attribute until explicitly asked to restore them.
- Keep `[hidden]{display:none!important}` in the reset.
- Video section has exactly one CTA; no "Ver tutoriales".
- No "handmade in Argentina/Buenos Aires" copy, ever.
- WhatsApp FAB stays WhatsApp-green (brand convention), not the red accent.

## Distribution
- Never publish this site as a Claude Artifact (real Hikari brand/assets).
