# Definition of Done

The single, authoritative checklist a phase MUST satisfy before it is considered
complete. This consolidates the rules already implied across `CLAUDE.md` and the
project constitution into one place. It is the operational form of constitution
**XVII. Controlled Delivery** and **XVI. Human Review Requirement**.

> Principle numbers (I, XVI, XVII, …) refer to the consuming project's constitution.
> If your constitution numbers its principles differently, map them accordingly.

> A phase is **Done** only when **every** item below is true. If any item is false,
> the phase is **not** Done — stop and resolve it before proceeding.

## Gates (all required, in order)

1. **Specification approved** — `spec.md`, `plan.md`, and `tasks.md` for the feature
   exist and are approved before implementation begins (constitution I).
2. **Single-phase scope respected** — only the one approved phase was implemented; no
   unrelated changes are bundled in (constitution XVII; CLAUDE.md Strict Rules).
3. **Gate passed with user-confirmed exit code** — the user (not AI) ran the gate
   script (`docs/process/gate-command.md`) and reported `EXIT: 0`. AI MUST NOT claim
   success without that confirmation (constitution XVII).
4. **Diff reviewed / scope guard** — `git diff --stat` was reviewed and shows only the
   files this phase intended to change; unrelated changes were reverted
   (`docs/process/review-process.md`).
5. **AI review complete** — the AI review checklist
   (`specs/_templates/ai-code-review-template.md`) was completed: spec/screenshot
   match, backend/frontend rules, security, tests, migrations, unrelated changes,
   rollback safety. When the phase touches frontend code, this includes passing
   `docs/stack-frontend/compliance-checklist.md`.
6. **Human review approved** — a human reviewer verified business requirements,
   business/domain correctness, security implications, screenshot compliance, and
   architectural compliance, and approved the change. **Human review is required
   before merge** (constitution XVI;
   `specs/_templates/human-pr-review-template.md`).

Only after items 1–6 are all true may the phase be **committed and merged**. Merge
occurs only after the human approval in item 6.

Operationally, run item 5 with the `/phase-review` command, and the final check
across all six gates with the `/phase-done` command.

## Conflict rule

If any artifact conflicts with another, or with the constitution, **stop and report**
rather than silently choosing one. The constitution prevails (constitution
Governance).

## Equivalence to the constitution

This Definition of Done is equivalent to constitution **XVII** (incremental delivery,
one approved phase at a time, no unrelated changes, every phase passes the gate) plus
**XVI** (mandatory human review before merge). Applying this checklist to a phase
yields the same pass/fail outcome as applying those principles directly. If this
document and the constitution ever diverge, the constitution prevails and this
document MUST be corrected.
