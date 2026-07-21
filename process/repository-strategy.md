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

- Specs (`specs/[feature-name]/`)
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
