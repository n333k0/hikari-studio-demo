# Verification Policy

Run these after EVERY change before claiming it works or deploying. "Verify"
means observe the real result (measurement or screenshot), not read the code.

## Always (code + measurement)
1. Horizontal overflow: `scrollWidth - clientWidth === 0` at 1440, 1024, 768, 390.
2. Hidden sections still hidden: `#historia` and `#acabado` have
   `offsetParent === null`.
3. No forbidden copy: grep for `hecho a mano en|hechas a mano en|taller de buenos|
   hecho en buenos` → zero matches.

## Visual verification REQUIRED (screenshot, not code) when the change touches:
- Hero (image, scrim, text, CTAs): screenshot 1440 + 390; confirm white text is
  legible and CTAs are white-fill + white-outline.
- Header: top-of-hero state (transparent, white logo/nav/icons) AND scrolled
  state (solid white, black, logo inverted); confirm solid triggers at the marquee.
- Carousels: measure first-card `left` == heading `left` (== gutter); screenshot to
  confirm the next card peeks at the right gutter.
- Footer wordmark: measure left/right/bottom gaps equal the gutter; screenshot to
  confirm no clipping.
- Video: confirm a playing frame (differs from the poster).
- Any gradient/scrim alpha edit: confirm it renders (invalid alpha silently breaks).
- Mobile header: hamburger left · logo centered · icons right.

## After a hero image swap (mandatory)
Re-check, at 1440 AND 390: scrim/text legibility, header contrast at the top,
and the mobile crop focal point.

## Deploy verification
1. commit + `git push origin main`.
2. Poll `gh api repos/n333k0/hikari-studio-demo/pages/builds/latest --jq .status`
   until `built` (it can sit in `building` for minutes — that's a GitHub delay).
3. Load the live URL with `?cb=<timestamp>` and confirm the change is live.

## Hardware-dependent features (AR, camera, GPS...) — deploy without being asked
A desktop/headless browser cannot verify these: real-device AR (Quick Look /
Scene Viewer), camera access, geolocation, motion sensors. Local `file://` or
`localhost` previews only prove the non-AR framing (e.g. the model-viewer
canvas) — they say nothing about the actual AR session on a phone.
- The moment a change touches one of these, run the full Deploy verification
  flow above immediately, without waiting for the user to ask — don't leave it
  sitting local-only.
- Hand back the exact live URL (deep-linked to the page/section if possible)
  so the user can open it on their phone. Say plainly which parts you could
  verify yourself (desktop framing, console errors) vs. which parts only they
  can confirm on-device.

## Tooling notes
- The browser tool writes screenshots relative to a different root — save to an
  absolute scratchpad path.
- No ffmpeg in this env; yt-dlp was installed via `python3 -m pip install --user`.
