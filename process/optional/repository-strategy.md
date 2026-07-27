# Repository Strategy

> **Optional module — multi-repo projects only.** The wrapper pattern below applies
> when a product is split across independent repositories (e.g. separate backend and
> frontend). Single-repository projects skip this document; their specs, docs, and
> source live in the one repo.

## Rule

Every deployable project has its own repository.

Required repositories:

```text
{{BACKEND_DIR}}     # Backend repository (its own remote)
{{FRONTEND_DIR}}    # Frontend repository (its own remote)
```

Specs/documentation repository:

```text
(wrapper root)      # Thin wrapper repository (holds docs/ and specs/); the
                    # sub-repositories are checked out inside it
```

Always run git commands (status, commit, branch, push) inside the repository you
changed, not at the wrapper root.

## {{BACKEND_DIR}}

Contains:

- Backend API source
- Data-access layer and database migrations
- Backend tests
- Backend CI/CD
- External API integrations and messaging
- Workers/background jobs if part of the backend

Does not contain:

- Frontend application source
- UI components
- Frontend package files

## {{FRONTEND_DIR}}

Contains:

- Frontend application source
- The frontend data layer (e.g. a BFF proxying the backend APIs)
- Frontend tests (unit and e2e)
- Frontend CI/CD

Does not contain:

- Backend database migrations
- Backend controllers
- Backend services

## Specs Repository

The wrapper root repository holds shared:

- Specs (`specs/feature/NNN-<name>/`)
- Process and rules documentation (`docs/`)
- Architecture and business source documents
- Screenshots
- API contracts
- Review notes

## Branch Strategy

Use one feature branch per feature.

Examples:

```text
feature/001-order-intake
feature/002-invoice-finalize
feature/003-external-status-api
```

Branch naming follows `docs/process/branch-strategy.md`: `feature/NNN-<name>` with
sequential numbering.

Do not mix unrelated backend and frontend work unless the feature requires both and
both repositories have matching branches.

## Cross-Repository Feature Rule

When a feature affects both backend and frontend:

1. Create the backend branch in `{{BACKEND_DIR}}`.
2. Create the frontend branch in `{{FRONTEND_DIR}}`.
3. The backend contract must be defined before frontend implementation.
4. Merge backend only after gate and review.
5. Merge frontend only after the backend contract is stable or mocked.

## The Gate Receipt Across Repositories

A receipt is a `git write-tree` over **one** repository. That is the whole of its
scope, and the wrapper pattern splits a phase across two or three of them: the
requirements (`spec.md`, `plan.md`, `tasks.md`) live in the wrapper, and the code
they describe lives in a sub-repo. So the guarantee `docs/process/gate-command.md`
states — *the requirements it was measured against have not moved since* — holds
inside each repository and **does not cross the boundary between them**. A backend
receipt says nothing about `tasks.md`, because `tasks.md` is not in that tree.

This is a property of content-hashing one git tree, not a defect to fix in the
gate. It is written down here because a control whose limits are undocumented gets
trusted past them.

**The rule.**

1. **Only code repositories have a gate.** The wrapper holds no build and no tests,
   so it gets no `gate.sh`, no `.gate-stubs-baseline` and no `.gate-sha256`. Do not
   install one to make the layout look symmetrical; a gate that verifies nothing is
   the decoration this framework exists to remove.
2. **One receipt per repository the phase changed.** A phase touching backend and
   frontend needs two valid receipts, checked independently. Definition of Done
   item 3 is satisfied only when *every* touched repo reports `RECEIPT: valid`.
3. **The wrapper is committed first.** Specs are committed and pushed in the
   wrapper *before* the gate runs in any sub-repo. This makes the requirements a
   git object with a timestamp that precedes the run, which is the same argument
   Definition of Done item 1 makes about approval.
4. **The wrapper tree must be clean when the phase closes.** `/phase-done` checks
   `git status --porcelain` in the wrapper alongside each sub-repo receipt. An
   uncommitted change there means the requirements may have moved after the gate
   ran — precisely the condition a receipt detects in-repo and cannot detect
   across repos.
5. **Record what the receipts were measured against.** `/phase-done` writes the
   wrapper's `git rev-parse HEAD` into the phase's `status.md` next to each repo's
   receipt. `status.md` is outside every fingerprint, so recording it stales
   nothing, and it turns "which specs was this built from" from a memory into a
   SHA a reviewer can check out.

**What this does not close.** Rules 3–5 detect *uncommitted* requirement drift and
record the commit the phase claimed to build from. They do not prevent a wrapper
commit that rewrites `tasks.md` between the gate run and the merge — nothing short
of putting both trees in one repository would. If that risk matters more than the
deploy independence that bought the split, the honest answer is a single
repository, and `SETUP.md` Q2 says to choose multi-repo only when the lifecycles
are genuinely separate.
