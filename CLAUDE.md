# CLAUDE.md — Hikari Studio site

Conventions and hard-won gotchas for this project. Read before editing so we don't
re-litigate fixes we already made.

## What this is
A single-page marketing site for **Hikari Studio** (Japanese-style rice-paper lamps),
built by applying the **Gantri design language** documented in [../DESIGN.md](../DESIGN.md)
to Hikari's real content. Static site: `index.html` + `styles.css` + inline `<script>`,
assets in `images/` and `media/`. No build step, no framework.

- Language: **Spanish (es-AR)**. English brand taglines are OK (e.g. "Rice & shine").
- Content max-width is **full-bleed** (`--container: 100%`), gutter `32px` desktop / `16px` mobile.

## Deploy (GitHub Pages)
- Repo: **`n333k0/hikari-studio-demo`** (public). Live: **https://n333k0.github.io/hikari-studio-demo/**
- Deploy = commit to `main` + `git push origin main`; Pages rebuilds automatically from `main`/root.
- Verify build: `gh api repos/n333k0/hikari-studio-demo/pages/builds/latest --jq '.status'`
  (wait for `built`), then curl the live URL with a `?cb=timestamp` cache-buster.
- Pages occasionally sits in `building` for several minutes — that's a GitHub-side delay, not an error.
- End commit messages with the `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer.

## Design system (from DESIGN.md, with this project's overrides)
- **Accent: Hikari red `#E5381F`** (`--accent`/`-hover`/`-active` in `styles.css`) — actions,
  links, footer background. Everything else is black/white/grey. This *replaces* Gantri's green.
- Type: **Inter** (400 body; 800 for the giant footer wordmark), size carries hierarchy, not weight.
  Mono (`Roboto Mono`) for eyebrows/labels.
- Pill buttons (`border-radius:40px`), **square-cornered imagery**, no drop shadows, flat tints for hover.
- Button variants: `--contrast` (white fill / black text), `--outline` (white border / white text),
  `--primary` (red). Over photos use contrast + outline, NOT red.

## Component rules (already dialed in — keep them)
- **Header**: `grid 1fr auto 1fr`. Desktop = logo left / nav centered / icons right.
  Mobile (≤1024) = hamburger left / logo centered / icons right (Gantri mobile). Assign
  `grid-column` explicitly per element; the hamburger is a direct header child (not inside utils).
  - Logo is `images/logo.png` at **`height:50px`** (the PNG has internal padding). White over the
    hero; on the solid state it flips to black via `filter: brightness(0)`.
  - States: `--over` (transparent, white logo/nav/icons) vs `--solid` (white bg, black). Solid
    triggers when the **marquee scrolls into the lower viewport** (`marquee.getBoundingClientRect().top
    <= innerHeight*0.7`), not a fixed scroll fraction.
- **Hero**: full-screen photo (`images/hero/hero-*.png`) with a radial vignette scrim so the
  **centered white text** stays legible; a top scrim keeps the header readable. CTAs stack and
  **hug their text** on mobile (no forced width).
- **Video** (`media/hikari-720.mp4`, 360 fallback): muted autoplay loop, full-width, centered white text.
- **Footer**: red bg, link columns, and a **giant edge-to-edge "HIKARI STUDIO" wordmark** rendered
  as a self-fitting SVG (see gotcha below), with equal gutter on left/right/bottom.

## Copy rules
- **Do NOT claim the lamps are "handmade in Argentina / Buenos Aires"** — they are not made here.
  Removed from title, meta, marquee, video, mission and footer. Keep neutral/true claims
  ("inspiración japonesa", "papel de arroz", "teñido en baño de té", "envíos a todo el país").
  The CABA store address in the footer legal line is fine (real contact info).
- Brand statement section uses the tagline **"Rice & shine"** + "Japanese-inspired forms for modern
  spaces, made with real rice paper." Sentence case, not uppercase.

## Gotchas (things that bit us — don't repeat)
1. **`[hidden]` needs `!important`** to hide sections whose class sets `display:grid/flex`
   (e.g. `.mission`). We hide sections with the `hidden` attribute; `[hidden]{display:none!important}`
   is in the reset. Delete the attribute to restore a section.
2. **Carousel first-card alignment**: `padding-inline` on an `overflow-x:auto; grid-auto-flow:column`
   track does NOT offset the first item (leading padding ignored). Do **not** use the negative-margin
   "bleed" trick — the track should just keep the container gutter so the first card lines up with the
   section heading.
3. **Giant footer wordmark**: a `vw` font-size overflows and clips on the right / touches the bottom.
   Use an inline `<svg>` cropped to the glyph **ink bounds** (measure with canvas `measureText`
   `actualBoundingBox*`, set `viewBox` to those bounds) with `width:100%` inside a gutter-padded box —
   it scales to the content width so left/right/bottom gaps all equal the gutter. Crisp at any size.
4. Environment has **no ffmpeg**; `yt-dlp` was installed via `python3 -m pip install --user yt-dlp`.
   The process video is Hikari's own YouTube clip `bqNjbeKbBRE` (720p is video-only, fine for a
   muted loop).
5. The browser tool writes screenshots relative to a different root than the project dir — save
   screenshots to an absolute scratchpad path.
6. Do **not** publish this as a Claude Artifact — it uses Hikari's real name/branding/photos. Local
   files + the user's own GitHub Pages only.

## Assets
- Used: `images/logo.png`, `images/hero/hero-3.png` (current hero bg — check the `.hero` rule),
  `images/products/*`, `media/hikari-720.mp4` + `hikari-360.mp4`.
- Unused/backup (safe to ignore): `images/logo.webp`, `images/hero/hero-1.*`, `hero-1b.png`,
  `hero-2.*`, `hero-3.webp`.
