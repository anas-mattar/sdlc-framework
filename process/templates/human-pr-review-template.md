# Human PR Review — [feature-name] / Phase [N]

> Copy this template to `specs/feature/NNN-<name>/human-pr-review.md` and complete one
> section per phase. This is Definition of Done item 6: AI review alone is
> insufficient — a change MUST NOT be merged until a human approves it.
>
> **Team:** the reviewer is a developer other than the feature's owner.
> **Solo:** the developer completes this checklist as their own acceptance review —
> a separate, deliberate act from implementing, never delegated to the AI. Record
> "self (solo project)" as the reviewer so the record stays honest.

| Field | Value |
|-------|-------|
| Feature | `feature/[NNN-name]` |
| Phase | [N] — [phase title from tasks.md] |
| Repositories / PRs | [{{BACKEND_DIR}} PR #, {{FRONTEND_DIR}} PR #, specs PR #] |
| Reviewer (human) | [name — or "self (solo project)"] |
| Review date | [YYYY-MM-DD] |
| AI review verdict | PASS / FAIL (see `ai-code-review.md`) |
| Gate result | RECEIPT: valid — run by [user], [YYYY-MM-DD] |
| Decision | APPROVED / CHANGES REQUESTED / REJECTED |

## Preconditions (verify before reviewing)

- [ ] AI review (`ai-code-review.md`) is complete for this phase with no open blockers.
- [ ] The gate was run **by the user** and `--verify` reports `RECEIPT: valid`
      (AI claims of success without this do not count).
- [ ] `git diff --stat` output is attached/linked below.

## 1. Actual UI vs Screenshots

*Skip only if this phase has no UI.*

- [ ] Ran the app and compared each affected view against
      `specs/feature/<name>/screenshots/` — layout, component placement, and
      view sequence match the prototype.
- [ ] No invented layout.

Notes:

## 2. Business Behavior

- [ ] Behavior matches `spec.md` and the referenced business source documents
      (e.g. an operator manual) where applicable.
- [ ] Edge cases exercised: [list what was manually tried]

Notes:

## 3. Financial / Domain Correctness

- [ ] Quantities, amounts, and state transitions are correct across the tested flows.
- [ ] Posted transactional records are never edited or deleted — corrections are
      reversal/adjustment only (where the domain has posted/immutable records).
- [ ] Records are correctly scoped (e.g. per site / legal entity, where the domain
      requires it).

Notes:

## 4. Security Implications

- [ ] Permissions enforced server-side for every new endpoint/procedure; verified
      with a user lacking the permission.
- [ ] No sensitive data leaked to the client bundle, logs, or responses.
- [ ] No secrets introduced anywhere in the diff.

Notes:

## 5. Architectural Compliance

- [ ] Backend follows the layered rules (`docs/stack-backend/`); frontend follows
      the mandatory defaults (`docs/stack-frontend/`).
- [ ] No unapproved packages or architecture changes (must be in `plan.md`).
- [ ] Cross-repo ordering respected: backend contract defined/merged before
      dependent frontend work (multi-repo projects;
      `docs/process/repository-strategy.md`).

Notes:

## 6. Code Diff

- [ ] Read the full diff in each repository — not just the summary.
- [ ] `git diff --stat` shows only files this phase intended to change; unrelated
      changes were reverted (Definition of Done item 4).

`git diff --stat` output:

```text
[paste here]
```

## 7. Findings

| # | Severity (blocker/major/minor) | File:line | Finding | Resolution |
|---|-------------------------------|-----------|---------|------------|
| 1 | | | | |

## Decision

- **APPROVED** — phase may be merged. / **CHANGES REQUESTED** — fix findings and
  re-review. / **REJECTED** — phase reverted per `rollback.md`.
- Reviewer sign-off: [name], [YYYY-MM-DD]
- Merge performed by: [name], [YYYY-MM-DD], merge commit: [sha]
