# Site Structure — single source of truth

> **Read this FIRST, every session, before anything else** — including a bare
> "hey." Lead your first reply with a short, honest status line drawn from
> this file (what's done, what's next, what's still undefined). Update this
> file in the same turn whenever the user gives new scope, priorities, or
> direction, so the *next* session opens already knowing it.

## What this project is
A redesign of the real, live business site **https://hikaristudio.com.ar/**
(Japanese-style rice-paper lamps, currently hosted on Tiendanube/e-commerce).
We apply the Gantri design language (`../DESIGN.md`) to Hikari's real content
— products, prices, copy tone, contact info. It is a design/marketing
rebuild, not a working store clone: no real cart, checkout, accounts, or
backend unless/until the user explicitly asks for that.

The live site is fair game to browse for real content (products, prices,
nav, policy pages) — but write copy in our own words rather than copying
verbatim, and keep the existing copy rules in `CLAUDE.md` (e.g. never claim
"handmade in Argentina").

## Current status

| Area | Status | Notes |
|---|---|---|
| Home page | In progress, largely built | Header, hero, marquee, "Novedades" product carousel, statement + value tiles, "Explorá por forma" category carousel, full-width process video, #HikariEnCasa UGC section, footer with wordmark — all built. `#historia` (mission) and `#acabado` (finish rail) sections exist in the HTML but are intentionally `hidden`. |
| Inner pages (product detail, category, tutoriales, contacto, policies, etc.) | **Phase 1: 3 of ~30 products live** (`productos/ensui-d70/`, `productos/ensui-d50/`, `productos/ikigai-s/`) | Full phased scope defined 2026-07-24 — see below. Template pattern proven structurally, but **not validated** — see Validated? below. Ensui D50 and Ikigai S were built in the same parallel batch as D70 and carry the same known AR texture bug (not yet fixed for those two — see Validated?). Ikigai S also has no home-page card yet (no real price/copy sourced for one). Remaining work is mostly repeating the pattern per product, gated on validation clearing first. |

## Pending shared-file edits (flagged, not yet applied)

Shared-file changes that a parallel agent run identified as needed, but did
**not** make itself — per the "flag, don't edit" convention in
`docs/ARCHITECTURE.md` §13. Applying these piecemeal, one parallel agent at a
time, risks two agents colliding on the same file or applying the same kind of
change in inconsistent styles, so they wait here until a human (or one later
dedicated step) applies all of them together in a single reviewed change —
then the row is deleted. A `SessionStart` hook (`.claude/settings.json`)
surfaces this section automatically at the start of every session; see
`docs/ARCHITECTURE.md` §13 for why.

<!-- PENDING-SHARED-EDITS:START -->
| File | Needed change | Why | Flagged | Status |
|---|---|---|---|---|

(An empty table between the markers means nothing is currently pending.)
<!-- PENDING-SHARED-EDITS:END -->

## Full site scope
**Defined 2026-07-24.** Goal: recreate the *entire* real site
(https://hikaristudio.com.ar/) in the Gantri-derived design language, one
inner-page type at a time. This is an explicitly long-running, multi-session
effort — work proceeds phase by phase without pausing to re-confirm each
phase; only stop and ask when a decision is genuinely expensive/irreversible
(e.g. the AR question below).

Real site inventory (crawled 2026-07-24, via `hikaristudio.com.ar` nav +
footer): Inicio, Productos (flat catalog + category pages like `/de-pie/`,
`/colgantes/`), product detail pages (`/productos/<slug>/`), Tutoriales
(`/blog/`), Contacto, Política de Devolución, Acceso Mayoristas (external
Tiendanube portal — **out of scope**, not ours to rebuild), account
login/register (Tiendanube auth — **out of scope**, no real accounts per the
top of this doc).

Real product pages already have (verified on `/productos/ensui-d70/`): 6
photos, category breadcrumb, price + "3x sin interés", SKU, **MEDIOS DE
ENVÍO** and **COMPARTIR** actions, a rich description (measurements,
material, portalámpara, cable, dimmer) plus a standing "Características del
proceso artesanal" paragraph (rice paper + glue traces, tea-dye color
variation — real content, reusable verbatim/adapted), and a related-products
rail. **No reviews anywhere on the real site** — do not add a reviews UI.

### Planned pages / phases
- [x] Home — largely built (see table above)
- [ ] **Phase 1 — Product detail pages** — 3 of ~30 live: `productos/ensui-d70/`,
      `productos/ensui-d50/`, `productos/ikigai-s/` (matches the status table
      above; this line read "1 of ~30" until 2026-07-25).

      **Validated? Not yet validated.** The page has been built and its AR
      logic has been code-reviewed by an agent, but nobody has confirmed it
      end-to-end on real hardware or with a human review pass. Do **not**
      propose duplicating this template across the other ~29 products until
      every item below is checked off — each with evidence (a link, a
      screenshot, or an explicit "yes I checked X" from the user; an agent
      reporting "verified" is not evidence):
      - [ ] AR ("Ver en tu espacio") tested on a real **iOS** device via
            Quick Look / USDZ — not just `canActivateAR` reviewed in code.
      - [ ] AR tested on a real **Android** device via Scene Viewer / WebXR
            — not just code review.
      - [ ] The built page manually reviewed by the user end-to-end
            (gallery, sticky bar, modals, specs accordion) — not just an
            agent's self-reported "verified".
      - [ ] Local vs. live reconciled: resolved 2026-07-25 — commit `77b514c`
            ("fix Ensui D70 AR preview framing and add cord canopy cap") is
            pushed to `main` and confirmed `built` on GitHub Pages, so
            **local and live now match**. Live URL to test:
            https://n333k0.github.io/hikari-studio-demo/productos/ensui-d70/
            — future validators should still name which version they
            checked if this drifts again (local file vs. pushed/live URL).
      - [x] `productos/ensui-d50/` and `productos/ikigai-s/` USDZ files
            re-exported with PNG textures — **done 2026-07-25**. All three
            `.usdz` now verify `webp=0 png=3` via `unzip -l`. The conversion is
            no longer a one-off: it lives in `scripts/3d/export_usdz.py`, which
            is what stops it regressing a third time.
      - [ ] **Pendant hang confirmed on a real device.** The D70 model was
            re-authored 2026-07-25 so it *hangs* (shade at 1,29 m, canopy at
            2,40 m, anchor at y=0) instead of resting on the floor — see
            `scripts/3d/README.md`. Verified locally only: bbox `0 → 2.40 m`,
            anchor survives the GLB round-trip, preview framing screenshotted
            at 390×844 and 1440×900. Whether Quick Look / Scene Viewer really
            rest `bbox.min.y` on the detected plane is **the premise of the
            whole technique and is unproven on hardware.**
      - [ ] **Ensui D50 still rests on the floor in AR.** It is a pendant
            ("Colgante gota") but only the D70 got the hang treatment, by
            decision, so the method could be proven on one product first. Apply
            `pendant_hang.py` to it once the D70 is confirmed. Ikigai S is a
            *lámpara de pie* and correctly stays floor-standing.
      Until all five are checked, treat this template as proven for **zero**
      product pages end-to-end (D70's AR was fixed once, but the underlying
      *pipeline step* that produced the webp bug hasn't been corrected at
      its source, since two more products built the same way have the same
      defect) — not thirty. See `docs/KANBAN.md` for how this blocks the
      rest of Phase 1.

      **Pattern decision (2026-07-24, revised from the original plan):** one
      static HTML file per product at `productos/<slug>/index.html` (matches
      the real site's URL shape), NOT a JS-templated single file driven by a
      data blob. This project's own convention is "no build step, no
      framework" and to avoid abstraction the task doesn't need — a
      client-side product-data template would have been exactly that.
      Shared *behavior* (not content) was factored out instead: the header
      scroll/carousel logic now lives in `main.js` (both `index.html` and
      every product page load it), and PDP-only behavior (gallery, modals,
      sticky bar, specs accordion, AR) lives in `product.js` + `product.css`.
      To add the next product: copy `productos/ensui-d70/index.html`, swap
      in that product's real photos/copy/specs from the live site, and
      follow "Real AR pipeline" below for its 3D model. Anatomy (adapted from
      Gantri's PDP, verified live on gantri.com 2026-07-24, minus anything
      Hikari doesn't have):
      - Photo carousel (multi-image, matches real product photo counts)
      - Breadcrumb, H1, price, SKU
      - Sticky bottom bar: appears once the user scrolls past the initial
        buy box (Gantri pattern, confirmed via DOM inspection — a
        `position:fixed` bar with name/price/Add-to-cart). Hikari version:
        precio, **agregar al carrito**, **compartir**, **medios de envío**
        (this is our own adaptation — Gantri's bar doesn't carry
        share/shipping, but our real PDP already has those two actions, so
        folding them into the sticky bar suits our thinner page).
      - Descripción + medidas + material + process story (rice paper,
        tea-dye) — real copy already exists per product, reuse it.
      - More photos + editorial text beat
      - Room-scene scale illustration: a line-drawing of a person at a
        table/sofa (to scale) with the lamp rendered in full color —
        confirmed this is exactly what Gantri's "scale photo" is
        (screenshotted 2026-07-24). We build our own inline-SVG version,
        same technique as the footer wordmark.
      - Community section: reuse the home page's `#HikariEnCasa` UGC
        pattern (`.ugc` cards), no comments.
      - Related lamps grid — no reviews, no designer-bio module (we don't
        have named designers).
      - Specs (accordion or plain list): size, material, care — from the
        real description block.
      - **"Ver en tu espacio" (AR)** — AR pipeline **built and code-reviewed**
        (2026-07-24), not a placeholder — but **not yet confirmed on a real
        device**; see **Validated?** above before treating this as proven.
        **The pipeline now lives in [`scripts/3d/README.md`](../scripts/3d/README.md)
        with committed, runnable scripts** (`pendant_hang.py`,
        `export_usdz.py`) — not as prose here. It used to be described here
        with the Blender script left in a `/private/tmp` scratchpad and a note
        to "rewrite it fresh next time"; that is precisely how the WebP/USDZ
        violet-texture bug shipped in two more products after being fixed
        once. Read that README before touching any model. In short:
        1. Higgsfield `generate_3d` (`tripo_h3_1_image_to_3d`) on the cleanest
           studio photo → raw GLB, ~9 credits/product.
        2. `npx @gltf-transform/cli optimize` down to ~1.8MB.
        3. Blender rescales to the product's **real listed dimensions** (don't
           trust the AI's scale guess — the D70 came out ~1.08m when it's
           actually Ø0.70m), and — for a **pendant** — lifts the lamp to its
           hanging height with an anchor mesh at y=0, because no web AR
           runtime can anchor to a ceiling and all of them rest the model's
           lowest bounding-box point on the detected floor.
        4. Both files ship under `models/<slug>.glb` + `models/<slug>.usdz`.
           The GLB keeps WebP textures (small, browsers read it); the USDZ
           **must** be PNG or Quick Look renders it solid violet.
        5. In the product page: `<model-viewer>` (loaded from
           `unpkg.com/@google/model-viewer`, MIT-licensed, same
           CDN-dependency pattern as Google Fonts) with `src` (GLB, Android
           Scene Viewer/WebXR) and `ios-src` (USDZ, iPhone Quick Look) inside
           the "Ver en tu espacio" modal. `canActivateAR` is checked on
           `load`/`ar-status` to show a real "Ver en AR" button only where
           supported, and an honest "tu navegador no soporta AR todavía"
           note otherwise — verified both states render correctly.
        Considered installing a GitHub/skills.sh "skill" for GLB→USDZ first;
        none had meaningful adoption (best ~2K installs) for that narrow
        step, so used Blender's own official USD exporter instead — already
        installed, official, no untrusted code pulled in. Image-to-3D itself
        used the already-connected Higgsfield MCP (Meshy/Tripo-backed), not
        a third-party skill.
      - Blur-backdrop modals (`backdrop-filter: blur`) for the gallery
        lightbox and any popup — matches Gantri's modal treatment. Built and
        verified (share/shipping/AR modals all use the same `.modal`
        pattern in `product.css`).
- [ ] **Phase 2 — Category / catálogo pages** (`/de-pie/`, `/colgantes/`,
      etc.) — not started. Comes after Phase 1's template is solid.
- [ ] **Phase 3 — Blog / Tutoriales** — not started. No content shape agreed
      yet beyond "it exists on the real site as `/blog/`."
- [ ] **Phase 4 — Contacto, Política de Devolución** — not started.

## How to use this file
- Every session: read it, then open with a short status line before doing
  anything else — don't wait to be asked. That status line must be a **full
  overview of the whole site scope** (Home + every phase in "Planned pages /
  phases" — Phase 1 product pages, Phase 2 category pages, Phase 3
  blog/tutoriales, Phase 4 contacto/políticas), not just whatever phase is
  currently in progress. State plainly, per area: done / in progress /
  blocked / not started. The user wants a "vista gorda" (big-picture view) of
  what's missing across the entire site every time a session starts, not a
  spotlight on the current focus area.
- **Before proposing to scale or duplicate any page template across many
  instances** (e.g. "let's build the other 29 product pages now"), check
  that template's **Validated?** status in this file first. If it says "Not
  yet validated," do not propose a batch — surface the specific unchecked
  items and ask the user to confirm each one, with evidence (a link, a
  screenshot, an explicit "yes I checked X"), rather than assuming a prior
  session's "verified" or "working" claim means a human actually checked it.
  This applies to every template, not just Phase 1 products — Phase 2/3/4
  templates get the same field once they exist.
- Check `docs/KANBAN.md` for the current priority-ordered worklist before
  starting new work.
- When scope changes (new page agreed, page finished, direction changed):
  update the relevant row/section here, in the same turn.
- Keep it honest and current, not aspirational — "not started" is a fine
  status if that's the truth.
