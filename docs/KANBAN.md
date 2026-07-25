# Kanban — Hikari Studio site

A plain-markdown worklist, hand-maintained like the other `docs/*.md` files. No
build step or task tracker for this project, so this file *is* the tracker.
Check it before starting new work. This is a worklist, not a design doc —
keep it short and honest; no aspirational content.

Update this file in the same turn work state changes (item started, blocked,
cleared, done) — same rule as `docs/site-structure.md`.

## Blocked on validation

**Top priority — nothing below can mass-scale until this clears.**

- **Phase 1 product-page template validation.** Full checklist lives in
  `docs/site-structure.md` → "Planned pages / phases" → Phase 1 →
  **Validated?**. Currently **not yet validated**. Outstanding: AR tested on
  a real iOS device, AR tested on a real Android device, the built page
  manually reviewed end-to-end by the user, **and** the D50/Ikigai S USDZ
  webp-texture bug fixed (confirmed present 2026-07-25 — see
  site-structure.md). Per the rule in `docs/site-structure.md` → "How to use
  this file," no session should propose building the remaining ~27 product
  pages until these are checked off with evidence. Live URL to test AR on a
  real phone: https://n333k0.github.io/hikari-studio-demo/productos/ensui-d70/
  (D50/Ikigai S will show the known violet-placeholder bug in Quick Look
  until their USDZ is re-exported with PNG textures).

## Backlog (priority order)

1. **Fix the D50/Ikigai S USDZ texture bug** (re-export with PNG textures,
   same fix as `4ccdcc5`) — the concrete unblock for the validation item
   above.
2. **Source a real home-page card for Ikigai S** (price/copy from the live
   site) — it has no card in the "Novedades" carousel yet, unlike D50 which
   already had one with a placeholder `href`.
3. **Phase 1 remainder — ~27 more product detail pages** (copy the
   `productos/ensui-d70/index.html` pattern). **Blocked** by the validation
   item above.
4. **Phase 2 — Category / catálogo pages** (`/de-pie/`, `/colgantes/`,
   etc.). Not started. Per `docs/site-structure.md`, this comes after
   Phase 1's template is solid.
5. **Phase 3 — Blog / Tutoriales.** Not started. No content shape agreed
   yet beyond "it exists on the real site as `/blog/`."
6. **Phase 4 — Contacto, Política de Devolución.** Not started.

## Needs a human decision

- **AR real-device confirmation itself.** Testing "Ver en tu espacio" on a
  real iPhone (Quick Look/USDZ) and a real Android phone (Scene
  Viewer/WebXR) requires physical hardware only the user has — an agent
  cannot self-certify this.
- ~~Local vs. live reconciliation for Ensui D70~~ — resolved 2026-07-25,
  commit `77b514c` pushed and confirmed `built` on GitHub Pages.
- **End-to-end manual review of the built PDP** (gallery, sticky bar,
  modals, specs accordion) — needs the user's own pass, not an agent's
  self-report.

## Cross-references

- `docs/site-structure.md` — scope, phase status, and each template's
  Validated? field.
- `CLAUDE.md` — operating manual pointer block and project conventions.
