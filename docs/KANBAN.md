# Kanban — Hikari Studio site

A plain-markdown worklist, hand-maintained like the other `docs/*.md` files. No
build step or task tracker for this project, so this file *is* the tracker.
Check it before starting new work. This is a worklist, not a design doc —
keep it short and honest; no aspirational content.

Update this file in the same turn work state changes (item started, blocked,
cleared, done) — same rule as `docs/site-structure.md`.

## How the board reads this file
The WebsiteOS panel (`.claude/dashboard/serve.sh`) renders every top-level list
item below as a card, and picks its column from the **section heading's
keywords** (`classify_kanban_section()` in `server.py`) — not from a fixed list
of headings, so a new section still lands somewhere sensible:

| Heading contains | Column |
|---|---|
| `block` / `bloque` / `waiting` / `espera` / `on hold` | Trabado |
| `human` / `decis` / `necesita` / `manual` / `input` | Trabado, tagged "te necesita a vos" |
| `progress` / `curso` / `doing` / `wip` | En curso |
| `done` / `listo` / `hecho` / `complet` / `cerrad` | Listo |
| `cross-ref` / `referenc` / `links` | **excluded** — links, not work |
| anything else | Por hacer |

Two formatting habits the board relies on, both of which this file already
follows: start an item with `**A short title.**` (that bold lead becomes the
card's headline, the rest becomes the body), and mark finished items with
`~~strikethrough~~` (those move to Listo instead of being deleted). Numbered
items keep their number as a `#N` priority chip. Nothing here is required —
an unformatted bullet still renders, just with less structure.

## Blocked on validation

**Top priority — nothing below can mass-scale until this clears.**

- **Phase 1 product-page template validation.** Full checklist lives in
  `docs/site-structure.md` → "Planned pages / phases" → Phase 1 →
  **Validated?**. Currently **not yet validated**. Outstanding: AR tested on
  a real iOS device, AR tested on a real Android device, and the built page
  manually reviewed end-to-end by the user. The D50/Ikigai S USDZ
  webp-texture bug is **fixed** (2026-07-25, all three verify `webp=0 png=3`).
  Per the rule in `docs/site-structure.md` → "How to use this file," no session
  should propose building the remaining ~27 product pages until these are
  checked off with evidence. Live URL to test AR on a real phone:
  https://n333k0.github.io/hikari-studio-demo/productos/ensui-d70/

- **Pendant hang, unproven on hardware (new 2026-07-25).** The D70 model now
  carries its own 1,29 m drop (84 cm of cord from a 2,40 m ceiling) plus a
  y=0 anchor so AR shows it *hanging*
  instead of resting on the floor (`scripts/3d/pendant_hang.py`). The premise —
  that Quick Look / Scene Viewer rest `bbox.min.y` on the detected plane — has
  never been confirmed on a device in this project. Confirm on the D70 before
  applying it to any other pendant. If it fails, the CSS/JS/framing half of the
  change stands on its own and only `models/` needs reverting.

## Backlog (priority order)

1. **Apply the pendant hang to Ensui D50** — it is a colgante but still rests
   on the floor in AR; only the D70 got the treatment, so the method could be
   proven on one product first. `blender --background --python
   scripts/3d/pendant_hang.py -- --glb models/ensui-d50.glb ...` — note the
   D50 model has **no cord geometry at all**, so one has to be borrowed from
   the D70 GLB or synthesised. **Blocked** on the D70 confirming on hardware.
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
7. **Hard-enforce agent claims** (2026-07-25, deliberately deferred — see
   `docs/ARCHITECTURE.md` §13 "Declaring scope at lock time"). Today, a
   locked worktree's declared scope (`.agent-state/claims/<name>.md`) is only
   a soft signal: `SessionStart` surfaces it, `CLAUDE.md` instructs sessions
   to respect it, but nothing technically stops an edit to a claimed path.
   Next step: a `PreToolUse` hook that checks `Edit`/`Write` targets against
   active claims and refuses collisions. Deferred until the soft version has
   run in practice for a while and claim-file cleanup (deleting a claim when
   its worktree unlocks) is reliably happening — an enforced block against a
   stale, un-cleaned-up claim would wrongly refuse legitimate work.

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
