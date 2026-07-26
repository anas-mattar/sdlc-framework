# CLAUDE.md

<!-- Generated from sdlc-framework CLAUDE.md.template.
     Small tier, solo, single repo, no design source, no external integrations.
     Sections excluded by those answers have been deleted, not commented out. -->

Framework: sdlc-framework v2.0.0
Scope tier: Small
Developers: solo

Guidance for Claude Code working in this repository.

This project uses a controlled SDLC workflow with Spec Kit style documents.
Do not implement everything at once.

## Precedence Rule

If this file and a `docs/` file conflict, **the `docs/` file wins** — report the
conflict so this file gets corrected. This file is an index plus non-negotiables,
not the source of detail.

## Task → Doc Map

Read the mapped doc **before** starting the matching task — not the whole list up
front:

| When the task involves… | Read first |
|---|---|
| Starting any feature | `docs/process/project-rules.md` |
| Writing or updating a `spec.md` | `docs/process/source-artifacts.md` |
| Finishing a feature | `docs/process/definition-of-done.md` |
| Any data-entry form | `docs/stack-frontend/forms.md` |
| Any data table/list | `docs/stack-frontend/tables.md` |
| New API procedure / data fetching | `docs/stack-frontend/trpc.md` |
| Auth, permissions, sensitive data | `docs/stack-frontend/security.md` |
| Anything product-specific | `docs/project/` (domain rules + gotchas) |
| Framework seems not to be enforcing | run `/framework-doctor` |
| Moving to a newer framework version | run `/framework-upgrade <path-to-framework>` |

## Workflow (non-negotiable)

1. Check current branch and working tree; stop if unrelated changes exist.
2. Run the baseline gate on untouched code.
3. One feature branch per feature.
4. Create/update `spec.md` (tasks inline — Small tier has no `plan.md`/`tasks.md`)
   and get approval.
5. Implement the feature, then stop and ask the user to run the gate. At Small
   tier the gate is per feature, not per phase — but "the whole feature" still
   means one feature, not three.
6. The gate is `./gate.sh` at the repo root. The **user** runs it; it prints
   `EXIT: <code>` and writes a receipt. **Do not claim success until
   `./gate.sh --verify` reports `RECEIPT: valid`** — a pasted exit code does not
   count, and a receipt from before the latest edit reports `RECEIPT: stale`.
7. User checks `git diff --stat`; fix only in-scope issues; commit.
8. AI review (`/phase-review`), then the developer's own acceptance review
   (`specs/_templates/human-pr-review-template.md`), then merge. Never merge on
   AI review alone — solo does not mean unreviewed, it means the author reviews
   deliberately and separately.

## Strict Rules

- Implement the approved scope only; do not continue without user approval.
- Do not refactor unrelated files or change unrelated features.
- Do not add packages unless approved in the feature's `spec.md` (a hook enforces
  this — see `.claude/settings.json`).
- Do not change architecture unless approved in `spec.md`.

## Source of Truth Priority

1. `specs/feature/NNN-<name>/spec.md`
2. `docs/stack-frontend/` (mandatory defaults)
3. `docs/project/` (domain rules and gotchas)

On any conflict between artifacts: **stop and report** — never silently choose.

Phase progress goes in `specs/feature/NNN-<name>/status.md`, never as edits to the
spec's task list — the spec is fingerprinted by the gate receipt, so rewriting a
task after the gate would (correctly) invalidate it. Wanting to change the task
list after implementation means the requirements moved: stop and report.

This project has no design source: no prototype, no Figma, no captured
screenshots. The `spec.md` layout section plus the app's design system govern the
UI. Offer a generated mock for non-trivial UI; never demand screenshots that
cannot exist. If a design source is adopted later, screenshots become the #1
layout authority and this section must be updated
(`docs/process/source-artifacts.md`).

## Frontend Reference

```sh
yarn dev          # http://localhost:3000
yarn test
```

Gate: `./gate.sh` at the repo root — `yarn build`, then `yarn check && yarn test`.

Architecture summary: Next.js App Router with tRPC for all data access and
NextAuth for sessions; server components by default, client components only where
interaction requires them. UI is shadcn/ui over Tailwind. Every mutation goes
through a tRPC procedure with server-side authorization — never a route handler
that trusts the client. Rules: `docs/stack-frontend/`.

## Project Knowledge (layer 3 — grows over time)

Domain rules, external systems, and vocabulary: `docs/project/domain-rules.md`.

Gotchas — traps that look like mistakes but are intentional
(`docs/project/gotchas.md`):

- Nothing yet. This is the most valuable section of the file: every time a session
  trips over something non-obvious, add one line here.
