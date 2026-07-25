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
| Inner pages (product detail, category, tutoriales, contacto, policies, etc.) | **Phase 1: 1 of ~30 products live** (`productos/ensui-d70/`) | Full phased scope defined 2026-07-24 — see below. Template pattern proven end-to-end, including real device AR. Remaining work is mostly repeating the pattern per product. |

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
- [ ] **Phase 1 — Product detail pages** — 1 of ~30 live: `productos/ensui-d70/index.html`.

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
      Until all four are checked, treat this template as proven for **one**
      product page, not thirty — see `docs/KANBAN.md` for how this blocks
      the rest of Phase 1.

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
        Pipeline, run once per product:
        1. `mcp__claude_ai_Higgsfield__generate_3d` (model
           `tripo_h3_1_image_to_3d`, `auto_size:true`, `texture:true`,
           `pbr:true`) on the cleanest single studio photo → raw GLB.
           Costs ~9 Higgsfield credits/product (balance: check
           `mcp__claude_ai_Higgsfield__balance` first). Multi-view models
           (`multi_image_to_3d`) are better if a product actually has 2-4
           clean angle shots — Ensui D70's other photos were lifestyle/detail
           crops, not usable angles, so single-image was used.
        2. `npx @gltf-transform/cli optimize <in> <out> --texture-size 1024
           --texture-compress webp --simplify-ratio 0.03 --simplify-error
           0.001 --compress false` — raw Tripo output was 57MB (1M
           vertices); optimized down to ~1.8MB. `--compress false` matters:
           it skips Draco/meshopt so Blender can still import the result.
        3. Blender (already installed locally, headless
           `blender --background --python script.py`) imports the optimized
           GLB, **rescales it to the product's real listed dimensions**
           (don't trust the AI's own scale guess — Ensui D70 came out ~1.08m
           when it's actually Ø0.70m), recenters/drops to floor, then
           exports both a final GLB and a `.usdz` via `bpy.ops.wm.usd_export`
           (Blender's built-in USD exporter — no external converter needed).
           Script kept at
           `/private/tmp/.../scratchpad/glb_to_usdz.py` in the session that
           built it; rewrite it fresh next time rather than hunting for that
           temp path.
        4. Both files ship under `models/<slug>.glb` + `models/<slug>.usdz`.
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
  anything else — don't wait to be asked.
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
