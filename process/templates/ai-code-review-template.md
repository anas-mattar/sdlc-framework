# AI Code Review — [feature-name] / Phase [N]

> Copy this template to `specs/feature/NNN-<name>/ai-code-review.md` and complete one
> section per phase. This is Definition of Done item 5. AI review alone never
> authorizes a merge — human review (item 6) follows it.
>
> **Keep this list short on purpose.** Human attention is the scarcest resource in
> this process, and the steps that get rubber-stamped first are the expensive,
> low-visibility ones — running the app against the screenshots, verifying a
> permission denial with a second account, reading the full diff rather than
> `--stat`. Those are the only end-to-end checks the framework has. Anything a
> script can decide belongs in the gate or in CI, where it is free and never
> skipped; if you find yourself adding a box here that a grep could answer, add
> the grep instead.
>
> **Reviewed tree, not reviewed commit.** This review runs *before* the phase
> commit, so there is no sha to name: the honest answers were "none yet", "pending",
> or `HEAD` — which points at the *previous* phase's commit and is actively
> misleading. The gate receipt's `tree` hash is available pre-commit, identifies
> exactly what was reviewed, survives the commit that follows, and is already
> printed by `--verify`. Quoting it makes this artifact independently checkable for
> the first time: anyone can re-run `--verify` and compare.

| Field | Value |
|-------|-------|
| Feature | `feature/[NNN-name]` |
| Phase | [N] — [phase title from tasks.md] |
| Repos / stacks touched | [repo → `docs/stacks/<name>/`, one per stack this phase touches] |
| Branch(es) | [feature/... per repo] |
| Reviewed tree | [`tree` from `./gate.sh --verify`] |
| Review date | [YYYY-MM-DD] |
| Verdict | PASS / FAIL — [one line why] |

## 1. Spec Match

- [ ] Implemented behavior matches `spec.md` for this phase — no more, no less.
- [ ] Only the current approved phase from `tasks.md` was implemented.
- [ ] Conflicts between artifacts: **state them, or state that there were none.**
      Every conflict encountered is a row in `specs/feature/NNN-<name>/decisions.md`
      with who resolved it and how. Write "none encountered" here if there were
      none — silence is not the same claim, and only an explicit answer can be
      wrong. A conflict resolved silently is the one failure this checklist cannot
      detect after the fact.

      Conflicts this phase: [none encountered / see decisions.md rows N–M]

Notes: [deviations found, or "none"]

## 2. Screenshot Match

*Skip only if this phase has no UI.*

- [ ] UI matches `specs/feature/NNN-<name>/screenshots/` (layout, component placement, flow).
- [ ] Screenshot sequence order (prototype view order) is respected in navigation/flow.
- [ ] No invented layout where screenshots or a prototype exist.

Notes:

## 3. Stack Rules

**Repeat this section once per stack this phase touches.** A project installs one
directory per stack under `docs/stacks/`, however many it has — this is not a
backend-and-frontend pair. A phase may touch one stack, several, or none.

### Stack: `docs/stacks/[name]/`

- [ ] The numbered rules in that stack's `rules.md` are followed; any deviation
      cites the rule ID and says why.
- [ ] No new architectural pattern was introduced without `plan.md` approval —
      existing wiring, layering and directory conventions were followed, including
      names that are misspelled on purpose (`docs/project/gotchas.md`).
- [ ] Data access goes through the stack's approved path; nothing bypasses it.
- [ ] Schema or persistence changes follow that stack's database rules, where it
      ships them (PK convention, soft delete, audit fields).
- [ ] **That stack's `compliance-checklist.md` completed and passing — where the
      stack ships one.** A stack with no checklist is N/A, not a FAIL: the
      checklist is optional in the stack contract (`stacks/TEMPLATE/rules.md`).

Notes:

## 4. Security

- [ ] Authorization enforced server-side (permission checks / protected procedures);
      client-side permission checks are UX only.
- [ ] No secrets committed, copied, logged, or documented; no secrets or backend
      URLs in client-exposed variables.
- [ ] Sensitive data exposure, file uploads, and webhook validation reviewed per
      the security rules of each stack this phase touches (`docs/stacks/<name>/`,
      where that stack ships them) and `docs/contracts/`.

Notes:

## 5. Tests

- [ ] **For each acceptance criterion this phase touches, name the test that would
      fail if it regressed.** Fill the table below. A criterion with no such test
      is a FAIL, not a note. "Tests accompany the behavior" was the old wording and
      it is a *co-location* predicate — a test file next to the code satisfies it,
      including one whose only assertion is that the code ran. This asks for a
      mapping a reviewer can spot-check in ten seconds.

      | Acceptance criterion (from `spec.md`) | Test that fails if it regresses |
      |---|---|
      | | |

- [ ] The stub ratchet passes (`./check-stubs.sh`). Any `TODO`, `FIXME` or
      `NotImplementedException` this phase added is either implemented or carries
      `approved-stub: <where the spec defers it>`.
- [ ] Tests use each stack's own conventions — isolated per-test fixtures where the
      stack persists data, e2e coverage where the phase adds a user flow. Each test
      states the business rule it protects.
- [ ] No tests weakened, skipped, or deleted to make the gate pass.

Notes:

## 6. Migrations

*Skip only if this phase has no schema change.*

- [ ] Migration lives in the project's migrations directory, named per the database
      rules of the stack that owns the schema (`docs/stacks/<name>/`).
- [ ] Change is additive; no dropped tables/columns without explicit approval.
- [ ] Data migration (if any) is reversible and preserves transactional records.

Notes:

## 7. Unrelated Changes

- [ ] `git diff --stat` shows only files this phase intended to change — no
      refactors of unrelated files, no unrelated features.

Notes: [list any reverted stragglers]

*Unapproved packages are not on this list.* The package and install guards block
manifest edits and install commands at the moment they are attempted, and CI fails
if the approval marker was committed. Re-checking by eye what a hook already
enforces spends the scarcest thing in this process — human attention — on the item
least likely to be wrong.

## 8. Rollback Safety

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
