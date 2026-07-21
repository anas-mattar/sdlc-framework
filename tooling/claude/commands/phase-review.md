# /phase-review — AI review of the current phase

Perform the AI review for the current phase (Definition of Done item 5) and record
the result. Do NOT fix anything during the review — report first.

## Steps

1. Identify the active feature (current branch / `specs/<feature>/`) and the phase
   being reviewed (from `tasks.md`).
2. Run `git diff --stat` against the phase's base commit. **Scope check:** every
   changed file must belong to the approved phase. List any file that does not.
3. Walk `specs/_templates/ai-code-review-template.md` item by item against the
   actual diff (not from memory — read the changed files).
4. If the phase touches frontend code, additionally walk
   `docs/stack-frontend/compliance-checklist.md` item by item. Any FAIL blocks the
   phase.
5. If the phase touches the database, verify against
   `docs/stack-backend/database-rules.md` (naming, soft delete, audit fields, no
   physical deletes of transactional records).
6. If screenshots exist for the feature, compare the implemented UI structure
   against `specs/<feature>/screenshots/` — layout, component placement, flow.
7. Write the completed checklist with PASS/FAIL per item and evidence
   (file:line references) to `specs/<feature>/ai-code-review.md`, appending a
   dated section per phase.
8. Report the verdict to the user:
   - **PASS** — phase is ready for human review. Remind the user that human review
     is still required before merge.
   - **FAIL** — list the failing items ranked by severity. Do not start fixing
     until the user approves.
