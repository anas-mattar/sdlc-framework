# Deployment Standards

> **Status: PLACEHOLDER, and optional.** This document reserves a home for the
> project's deployment governance. It is installed only if you asked for it
> (`SETUP.md` step 1) — a project with no deployment pipeline should skip it
> rather than ship a page of headings describing behaviour it does not have.
>
> **Everything you record here goes inside the preserved region below.** This is a
> `copy`-class file: `/framework-upgrade` replaces it outright, because layer 1 is
> upstream-owned. Content between the `LOCAL` markers survives that; content
> outside them does not. Before preserved regions existed, this document asked you
> to write down your identity provider, your environment-variable names and the
> locations of committed secrets — into a file the next upgrade would overwrite.

<!-- LOCAL: preserved by /framework-upgrade -->
<!-- Record this project's deployment facts here. Everything between these two
     markers survives an upgrade; everything outside them is replaced. -->
<!-- /LOCAL -->

## Scope (to be expanded)

When the first deployable module is planned, this document will define:

- **CI/CD gate enforcement** — beyond the per-repo gate check
  (`tooling/ci/gate-ci.sh`), the deployment pipeline's own gates and the branch
  protection that makes them non-optional.
- **Environment promotion** — the ordered path (e.g. dev → test → staging →
  production) and the approval required at each boundary.
- **Secrets handling** — secrets are never committed to source; how they are
  injected per environment (aligned with `docs/contracts/auth-patterns.md`).
- **Migration & rollback alignment** — migrations and deployment must align with
  `docs/process/rollback-process.md`; records that project has recorded as
  irreversible are never physically deleted.
- **Repository separation** (multi-repo projects) — which repos deploy
  independently, per `docs/process/repository-strategy.md`.

## Production runtime invariants (record inside the LOCAL region above)

Record how the apps are actually configured today, so any environment can be
provisioned accordingly *before* the CI/CD pipeline above is built out. **Write the
answers inside the `LOCAL` markers at the top of this file, not here** — this
section lists what to record, and an upgrade replaces it.

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
