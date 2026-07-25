# Known Regressions & Fragile Areas

Bugs we have already hit (do not reintroduce) and issues that predate the current
task. Check this before "fixing" something that looks off — it may be known.

## Regressions we already fixed (do NOT reintroduce)
- Header text invisible over the hero: white text was used over a light hero.
  The hero is dark; `--over` state = white. If the hero image ever becomes light
  at the top, re-solve contrast, don't just flip colors blindly.
- Hidden section reappeared: a section with `display:grid/flex` overrode the
  `hidden` attribute. Fix lives in the reset: `[hidden]{display:none!important}`.
  Keep it. Hide sections with the `hidden` attribute only.
- Carousel first card flush to the viewport edge: caused by a negative-margin
  "bleed" + `padding-inline` on an `overflow-x` grid (leading padding is ignored).
  Do NOT reintroduce the bleed. Tracks keep the container gutter so the first card
  aligns with the section heading.
- Footer wordmark clipped on the right / touching the bottom: caused by a `vw`
  font-size that overflows. It is now an SVG cropped to the glyph ink bounds — see
  protected-regions.md before touching it.
- Mobile CTAs forced to a fixed 320px width: they must hug their text.
- Hero used images with baked-in promotional text: only use clean (text-free)
  hero images and add our own overlay.
- Malformed `clamp(min, pref, max)` where min > max silently resolves to `min`
  (it looked like a fixed 116px h1 on all widths). Always keep min ≤ max.
  Current hero h1: `clamp(4.6rem, 9vw, 11.6rem)`.
- Ensui D70 AR model rendered solid violet/magenta in Quick Look on iPhone:
  `models/ensui-d70.usdz` had been regenerated with Blender, which by default
  re-exports textures in their *source* codec — the source `.glb` uses WebP,
  and AR Quick Look/RealityKit cannot decode WebP textures in a USDZ, so it
  falls back to its missing-texture magenta. Fix: convert textures to PNG
  (`sips -s format png` or Pillow) and relink Blender's image datablocks to
  those PNG files (swap `.image` on each `TEX_IMAGE` node to a freshly
  `bpy.data.images.load()`-ed PNG — reassigning `file_format` on the original
  webp-backed image alone does not work reliably) *before* exporting. Any
  future `.glb` → `.usdz` regen must verify with `unzip -l`/`file` that
  `textures/*.png` (not `.webp`) landed inside the `.usdz`.

## Known pre-existing issues (NOT introduced by current tasks)
- Header icons, hamburger, and search are visual-only (no menu/search behavior).
- Newsletter form is inert (`onsubmit="return false"`).
- Many nav/footer links are `#` placeholders or in-page anchors.
- Repo carries unused/backup assets: hero-1.png, hero-1b.png, hero-2.png, all
  hero-*.webp, logo.webp; plus committed .DS_Store files.
- Uses Hikari's real brand/photos/video — personal demo only; not an Artifact.
- Product names/prices are a snapshot and may be stale.

## Fragile coupling (change one → re-verify the others)
- Hero image ↔ scrim legibility ↔ header contrast ↔ mobile crop.
- Footer wordmark text/font/weight/letter-spacing ↔ its SVG viewBox.
- Carousel alignment ↔ track margin/padding ↔ per-breakpoint grid-auto-columns.
- Header solid trigger ↔ presence/position of the marquee element.
