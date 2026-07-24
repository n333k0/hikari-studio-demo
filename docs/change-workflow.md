# Change Workflow — Operating Manual

This is the MANDATORY process for every future modification to this website.
It applies to changes of any size, including "tiny" ones. Read it with
website-spec.md, protected-regions.md, known-regressions.md and
verification-policy.md. When in doubt, do less and confirm.

## The Change Workflow (never skip a step)

1. **Understand the request.** Restate it in your own words. Identify the exact
   element(s) and the intended outcome.
2. **Translate it into explicit acceptance criteria.** Write the checklist
   (see "Acceptance Criteria" below) BEFORE touching code.
3. **Ask for clarification if the criteria are ambiguous.** Do not guess on
   anything that could change layout, copy, assets, or scope.
4. **Capture a baseline.** Confirm a clean git tree; screenshot the affected
   area at 1440px and 390px; note the current values you intend to change.
5. **Plan the smallest possible implementation.** Choose the minimal edit that
   satisfies the criteria. Prefer one property over a refactor.
6. **Modify only the minimum required files.** List expected files first
   (see "Scope Protection").
7. **Run technical verification.** Per verification-policy.md → "Always".
8. **Run visual verification.** Per verification-policy.md → visual list.
   Screenshot the same views as the baseline.
9. **Compare against the baseline.** Only the intended thing may have changed;
   everything else must match before/after.
10. **Check that no protected regions changed.** Per protected-regions.md and
    "Protected Invariants" below.
11. **If verification fails, diagnose the exact cause.** Find the specific line/
    rule responsible. No speculative edits.
12. **Repair only that issue.** Do not bundle other fixes or cleanups.
13. **Repeat verification** (steps 7–10).
14. **Stop after 3 failed repair cycles** and explain, with evidence, what is
    failing and why — do not keep trying blindly.

## Acceptance Criteria

Every request is rewritten into a pass/fail checklist before implementation.
Implementation does not begin until the criteria are understood (and confirmed
if ambiguous). Criteria always include the change itself PLUS the invariants it
must not break.

Example —
Request: "Move the lamp slightly left."
Acceptance criteria:
- ✓ Lamp moves left (by the requested amount).
- ✓ Hero height unchanged.
- ✓ Hero text unchanged (content and position).
- ✓ Mobile unchanged.
- ✓ Desktop unchanged.
- ✓ No new console errors.
- ✓ No horizontal overflow at any breakpoint.
- ✓ Only approved files changed.

## Scope Protection

- BEFORE editing: write the list of files you expect to change.
- AFTER editing: run `git status --porcelain` (or `git diff --name-only`) and
  compare to the expected list.
- If any unexpected file changed (including formatter churn, .DS_Store, or an
  asset), treat it as a VERIFICATION FAILURE: report it, revert the unintended
  change, and re-verify. Do not deploy with unexplained changed files.

## Protected Invariants

These general rules must NEVER be violated unless explicitly requested. (The
concrete, project-specific locked list lives in protected-regions.md.)

- Never redesign unrelated sections.
- Never refactor working code unless requested.
- Never change typography globally (family, scale, weights) unless requested.
- Never replace or re-encode assets (images, video, logo) unless requested.
- Never modify spacing/layout outside the requested scope.
- Never make "while I'm here" aesthetic improvements outside the task.
- Never assume a redesign is wanted — a targeted request means a targeted change.
- Never introduce new dependencies, frameworks, or build steps unprompted.
- Never reintroduce a known regression (see known-regressions.md).

## Definition of Done

Code compiling / the page rendering is NOT "done". A task is complete only when
ALL of the following hold, with evidence:

- ✓ Every acceptance criterion passes.
- ✓ Technical verification passes (verification-policy.md → Always).
- ✓ Visual verification passes (screenshots for the required cases).
- ✓ No protected invariant or protected region changed.
- ✓ No unexpected regressions (baseline comparison is clean).
- ✓ Scope is clean (only expected files changed).
- ✓ Before/after evidence has been generated and, when deploying, the live URL
  has been re-verified.

If any item fails, the task is not done — diagnose, repair the single cause,
and re-verify (max 3 cycles, then stop and explain).
