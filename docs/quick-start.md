# Quick Start — how to keep building this site

Plain-language guide to using the system day to day. For the deep "why it's
built this way," read [`ARCHITECTURE.md`](ARCHITECTURE.md) — this doc is the
front door, that one's the basement.

## How you actually work with it, going forward

You don't run commands or remember a process. You just describe what you
want, in plain language:

- *"Make the hero subtitle a bit dimmer."*
- *"Add a small trust badge row under the CTA."*
- *"Fix the spacing between product cards on mobile."*

**Small/routine changes** — copy, color, spacing, one component — run
through `/quick-site` automatically: implement the smallest change →
screenshot and verify it against real checks (not a vibe) → if something's
off, repair and re-verify (up to 3 tries) → report back what changed and
what was verified. You'll get a short status, not a wall of logs.

**Bigger or riskier changes** — hero image, header behavior, navigation,
global typography, broad layout — escalate automatically to the fuller
governed workflow (acceptance criteria written first, baseline screenshots,
more rigorous review). Same deal from your side: describe it, it's handled.
It just takes longer because more is at stake.

**What you always do yourself:** commit and push. The system deliberately
never does this for you — that's a hard rule, not an oversight.

**If it can't converge:** after 3 repair attempts it stops and tells you
exactly what's still failing and why, instead of guessing a 4th time. That's
the system refusing to burn your time/tokens on something it can't fix
blind — treat it as a signal to clarify the request, not a bug.

**Coming back after time away?** Say "map this site" (or `/website-aios
map`) for a cheap structural refresher before diving in — no need to re-read
everything yourself, and no need for me to either.

## When the site outgrows a single page

Right now this is a one-page site, so every change is inherently
one-at-a-time. If it grows a catalog/shop with many product pages, some
tasks stop being "one change" and become "the same change, N times" —
auditing every product page, generating N descriptions, rolling a header
change across the whole catalog. That's when fan-out tooling (not
single-page tools) is worth reaching for — patterns and the actual tool to
use are documented in `~/.claude/skills/website-aios/GRAPH_PATTERNS.md`
(a global, machine-level reference — not part of this repo, so no relative
link to it; ask the agent to read it directly). Not relevant yet — noted
for when it is.

## How this system was built, briefly

- **Core idea:** split *measurable fact-checking* (bash scripts + Playwright
  screenshots — free, reproducible, same answer every time) from *judgment
  calls* (writing acceptance criteria, making the edit, reviewing, deciding
  a repair). Full rationale: `ARCHITECTURE.md` §2.
- **The graph:** REQUEST → ACCEPTANCE CRITERIA → BASELINE → IMPLEMENT →
  VERIFY → REVIEW → (REPAIR → VERIFY, ×≤3) → DONE. Full diagram:
  `ARCHITECTURE.md` §3.
- **The rules every change respects** live in `change-workflow.md`,
  `protected-regions.md`, `known-regressions.md`, `verification-policy.md`,
  `website-spec.md` — read once each, not per task.
- **Evidence from every run** — screenshots, verification results, the
  request itself — lands in `.agent-state/runs/<timestamp>/`, gitignored on
  purpose: it's a ledger of process, not part of the product.

## What's Hikari-specific vs. reusable (for extracting this later)

Agreed plan: keep using this as-is for Hikari now, extract a reusable
version when the next real site starts. When that day comes:

- **Reusable pattern** (copy as-is): the two-tier workflow shape
  (quick-site vs. full governed run), the deterministic/reasoning split,
  bounded 3-attempt repair, scope protection (declare expected files before
  editing), the run-artifact structure in `.agent-state/`.
- **Hikari-specific** (rewrite per site): the actual checks
  (`verify-copy.sh`'s no-Argentina-copy rule, `verify-footer.sh`'s wordmark
  math, Hikari's breakpoints/red accent), and the content of
  `website-spec.md` / `protected-regions.md` / `known-regressions.md`.

The next site gets the skeleton (`run.sh`, the graph, the repair discipline)
rewritten with that site's own checks and design contract — not a copy of
Hikari's rules.
