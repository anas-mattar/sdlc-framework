# AI Code Review — [feature-name] / Phase [N]

> Copy this template to `specs/feature/NNN-<name>/ai-code-review.md` and complete one
> section per phase. This is Definition of Done item 5. AI review alone never
> authorizes a merge — human review (item 6) follows it.

| Field | Value |
|-------|-------|
| Feature | `feature/[NNN-name]` |
| Phase | [N] — [phase title from tasks.md] |
| Repositories touched | [{{BACKEND_DIR}} / {{FRONTEND_DIR}} / specs] |
| Branch(es) | [feature/... per repo] |
| Reviewed commit(s) | [sha(s)] |
| Review date | [YYYY-MM-DD] |
| Verdict | PASS / FAIL — [one line why] |

## 1. Spec Match

- [ ] Implemented behavior matches `spec.md` for this phase — no more, no less.
- [ ] Only the current approved phase from `tasks.md` was implemented.
- [ ] Any spec/plan/screenshot conflict was **stopped and reported**, not resolved silently.

Notes: [deviations found, or "none"]

## 2. Screenshot Match

*Skip only if this phase has no UI.*

- [ ] UI matches `specs/feature/NNN-<name>/screenshots/` (layout, component placement, flow).
- [ ] Screenshot sequence order (prototype view order) is respected in navigation/flow.
- [ ] No invented layout where screenshots or a prototype exist.

Notes:

## 3. Backend Rules

*Skip only if this phase does not touch the backend repo.*

- [ ] Controllers/handlers follow the project's error-handling conventions; domain
      exceptions used for error paths (per `docs/stack-backend/` rules).
- [ ] Repositories/DI follow the existing wiring patterns; no new patterns
      without `plan.md` approval.
- [ ] New tables follow the mandatory database standards (PK convention, soft
      delete, audit fields).
- [ ] Async patterns, N+1 prevention, and index considerations checked.

Notes:

## 4. Frontend Rules

*Skip only if this phase does not touch the frontend repo.*

- [ ] All data access goes through the approved data path (e.g. BFF procedures with
      auth-protected variants); no direct backend fetches from UI code.
- [ ] Forms follow the project's mandatory form stack (schema-validated, no manual
      per-field `useState`-style state).
- [ ] Tables compose the shared table base components; no hand-rolled table markup.
- [ ] Schemas and types live in their designated directories; existing directory
      names kept (even misspelled ones).
- [ ] **`docs/stack-frontend/compliance-checklist.md` completed and passing.**

Notes:

## 5. Security

- [ ] Authorization enforced server-side (permission checks / protected procedures);
      client-side permission checks are UX only.
- [ ] No secrets committed, copied, logged, or documented; no secrets or backend
      URLs in client-exposed variables.
- [ ] Sensitive data exposure, file uploads, and webhook validation reviewed per
      `docs/stack-frontend/` security rules and `docs/contracts/`.

Notes:

## 6. Tests

- [ ] Tests accompany the behavior introduced in this phase.
- [ ] Backend: project test framework with isolated per-test database/fixtures; each
      test class documents the business rule under test.
- [ ] Frontend: unit tests; e2e tests where the phase adds user flows.
- [ ] No tests weakened, skipped, or deleted to make the gate pass.

Notes:

## 7. Migrations

*Skip only if this phase has no schema change.*

- [ ] Migration lives in the project's migrations directory, named per the database
      rules (`docs/stack-backend/`).
- [ ] Change is additive; no dropped tables/columns without explicit approval.
- [ ] Data migration (if any) is reversible and preserves transactional records.

Notes:

## 8. Unrelated Changes

- [ ] `git diff --stat` shows only files this phase intended to change.
- [ ] No refactors of unrelated files, no unrelated features, no unapproved packages.

Notes: [list any reverted stragglers]

## 9. Rollback Safety

- [ ] Phase is revertible with `git revert` of its commit(s).
- [ ] Rollback would not physically delete or corrupt posted transactional records.
- [ ] Large tier only: the feature's `specs/feature/NNN-<name>/rollback.md` is
      updated if this phase changes rollback steps. Small and Medium tiers ship no
      per-feature rollback doc — mark N/A. The rules that govern any rollback live
      in `docs/process/rollback-process.md` and are not restated here.

Notes:

## Findings

| # | Severity (blocker/major/minor) | File:line | Finding | Resolution |
|---|-------------------------------|-----------|---------|------------|
| 1 | | | | |

## Outcome

- Verdict: **PASS / FAIL**
- Blockers outstanding: [none / list]
- Handoff: ready for human review (`human-pr-review.md`) — human review is still
  required before merge regardless of this verdict.
