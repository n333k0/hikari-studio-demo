# Hikari Studio — demo site

A homepage for **Hikari Studio** (handmade Japanese-style rice-paper lamps, Buenos Aires),
built by applying the **Gantri design language** documented in [`../DESIGN.md`](../DESIGN.md)
to Hikari's real content (product names, prices, materials, contact info from
https://hikaristudio.com.ar/).

## Run
Static site — no build step. Open `index.html` in a browser, or serve the folder:

```bash
cd hikari-site
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Files
- `index.html` — single-page homepage (Spanish, es-AR)
- `styles.css` — design system: Gantri tokens (green accent, mono/neutral scale, 8px spacing,
  pill buttons / square imagery, no shadows), responsive at 1024px / 640px
- `images/products/*` — product photos pulled from hikaristudio.com.ar
- `images/hero/*`, `images/logo.webp` — hero/logo assets (unused hero banners kept for reference)

## Design language applied (from DESIGN.md)
Regular-weight grotesque type (Inter) where **size**, not weight, carries hierarchy · one
saturated brand accent (**Hikari red `#E5381F`**, `--accent*` in `styles.css`) for
actions/links/footer only · fully-rounded pill controls vs. square-cornered imagery · generous
whitespace, flat tints instead of shadows · Gantri page arc: hero → trust marquee → product
carousel → oversized brand statement + value tiles → category carousel → UGC strip → finish rail
→ footer.

## Notes
- Product images, names, prices, the process video and the Hikari name/branding belong to Hikari
  Studio; this is a local demo/study, **not** for publishing as-is.
- Prices reflect the list + 10% transfer discount shown on the source store (ARS).
- **Layout is full-bleed** (`--container: 100%`, 32px gutter) to match Gantri's edge-to-edge feel.
- **Hero:** full-screen photo (`images/hero/hero-1.png`, text removed) with a white text overlay
  (eyebrow / H1 / sub / CTAs) and a dark scrim for legibility — Gantri's dark-hero treatment.
- **Process video** (`media/hikari-720.mp4`, 360p fallback) is Hikari's own YouTube clip
  (`bqNjbeKbBRE`), downloaded with yt-dlp and played as a muted autoplay loop, full-width with a
  white text overlay + CTAs, between "Explorá por forma" and "#HikariEnCasa".
- Temporarily hidden via the `hidden` attribute (delete it to restore): the mission section
  `<section id="historia">` and the finish rail `<section id="acabado">`.
- Accent color lives in three CSS vars (`--accent`, `--accent-hover`, `--accent-active`); change
  those to re-theme the whole site.
