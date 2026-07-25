# Brief Guide — reference, not a form

A checklist of what a complete picture of "the whole site" eventually needs.
This is **not** something to hand the user to fill out mechanically — use it
as a mental checklist during ordinary conversation, and record answers into
`docs/site-structure.md` as they come up naturally.

## For a redesign (a reference site already exists — this project)
- Full page/nav inventory of the reference site — what pages actually exist
- Which of those pages are in scope for the redesign vs. explicitly cut
  (e.g. this project currently assumes login/cart/checkout/accounts are out
  of scope, since it's a static design rebuild, not a working store — confirm
  rather than assume if it matters)
- Content source per page: pulled from the live site (products, prices, nav)
  vs. new copy written for this project
- Functional scope: static/demo vs. anything that needs to actually work
  (forms, filters, search)
- Any content on the reference site that must NOT be reused as-is — check
  the Copy rules in `CLAUDE.md` first

## For a from-scratch site (no reference exists)
- Business name, what they sell/do, target audience
- Pages/sections needed
- Existing brand assets (logo, photos, colors, fonts) — or do they need to
  be created
- Design inspiration / reference sites
- Content readiness — is copy already written, or does it need drafting
- Functional requirements (forms, e-commerce, booking, etc.)
- Hosting/deploy target

If a project has no `docs/site-structure.md` yet and no reference site, ask
for this information conversationally before treating any scope as settled.
