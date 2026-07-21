# Deployment Standards

> **Status: PLACEHOLDER.** This document reserves the authoritative home for the
> project's deployment governance so the baseline is discoverable and complete.
> It is intentionally a placeholder — **to be expanded when the first deployable
> module is planned.** No CI/CD pipeline is governed by the baseline yet.

## Scope (to be expanded)

When the first deployable module is planned, this document will define:

- **CI/CD gate enforcement** — the gate (`docs/process/gate-command.md`) must pass
  in CI before any merge to a protected branch; the user-confirmed exit code rule
  applies to automated gates as well.
- **Environment promotion** — the ordered path (e.g. dev → test → staging →
  production) and the approval required at each boundary.
- **Secrets handling** — secrets are never committed to source; how they are
  injected per environment (aligned with `docs/contracts/auth-patterns.md`).
- **Migration & rollback alignment** — database migrations and deployment must
  align with `docs/process/rollback-process.md`; posted transactional records are
  never physically deleted.
- **Repository separation** (multi-repo projects) — backend (`{{BACKEND_DIR}}`) and
  frontend (`{{FRONTEND_DIR}}`) deploy independently per
  `docs/process/repository-strategy.md`.

## Production runtime invariants (record here)

Record how the apps are actually configured today, so any environment (UAT/PROD)
can be provisioned accordingly *before* the CI/CD pipeline above is built out.
Typical invariants to record:

- **Environment variables** — where they are validated at startup (fail-closed on
  missing/invalid values), and which are server-only. Backend URLs and tokens must
  never reach a client bundle. Development-only relaxations (e.g. disabled TLS
  verification for a self-signed local API) MUST NOT apply in UAT/PROD.
- **Authentication** — the identity provider and token flow; any mock/test auth
  must never be enabled in a deployed environment. Behind a reverse proxy,
  configure forwarded headers so the apps see the real client scheme/IP.
- **Known tech debt** — e.g. secrets currently committed to source. Record the
  locations, do not copy the values into new files, logs, or documentation, and
  plan their removal to proper secret storage in any deployment feature.

## Until expanded

No deployment automation is governed yet. Any actual deployment work MUST first
expand this document through the standard SDLC workflow (spec → plan → tasks →
one approved phase), and any new tooling must be approved in that feature's
`plan.md`.
