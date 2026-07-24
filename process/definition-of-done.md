# Definition of Done

The single, authoritative checklist a phase MUST satisfy before it is considered
complete. **This document is authoritative on its own** — nothing else has to exist
for it to be enforceable, and no other document is required to interpret it.

> If your project also maintains a constitution, charter, or engineering principles
> doc, this checklist is its operational form for delivery: keep the two consistent,
> and treat any divergence as a stop-and-report event. The framework does not ship
> or require such a document.

> A phase is **Done** only when **every** item below is true. If any item is false,
> the phase is **not** Done — stop and resolve it before proceeding.

## Gates (all required, in order)

1. **Specification approved** — the feature's specification artifacts exist and are
   approved before implementation begins. A `spec.md` defining business behavior is
   required in every project; `plan.md` (technical approach) and `tasks.md` (phase
   breakdown) are required by the scope tier this project selected at setup and
   recorded in `CLAUDE.md`. Implementation never starts from an unapproved spec.
2. **Single-phase scope respected** — only the one approved phase was implemented; no
   unrelated changes are bundled in (CLAUDE.md Strict Rules).
3. **Gate passed, proven by a valid receipt** — the user (not AI) ran the gate
   script, and `./gate.ps1 -Verify` (or `./gate.sh --verify`) reports
   `RECEIPT: valid` — a full gate at `EXIT: 0` against the *current* working tree
   (`docs/process/gate-command.md`). A stale, `min`, or missing receipt does not
   satisfy this item, and neither does a pasted exit code.
4. **Diff reviewed / scope guard** — `git diff --stat` was reviewed and shows only the
   files this phase intended to change; unrelated changes were reverted
   (`docs/process/review-process.md`).
5. **AI review complete** — the AI review checklist
   (`specs/_templates/ai-code-review-template.md`) was completed: spec/screenshot
   match, backend/frontend rules, security, tests, migrations, unrelated changes,
   rollback safety. When the phase touches frontend code, this includes passing
   `docs/stack-frontend/compliance-checklist.md`.
6. **Human review approved** — a human verified business requirements,
   business/domain correctness, security implications, screenshot compliance, and
   architectural compliance, and approved the change **before merge**
   (`specs/_templates/human-pr-review-template.md`). Who that human is depends on
   how many developers the project has:
   - **Team (2+ developers)** — independent peer review: the reviewer is someone
     other than the feature's owner (`docs/process/team-workflow.md` §4). Self-review
     does not satisfy this item when another developer is available.
   - **Solo** — developer acceptance: the developer completes the same checklist
     deliberately, as a separate act from implementing. The AI never signs it.

   The requirement that a *human* approves before merge is absolute in both cases.
   What varies is only whether that human can be the author.

Items 1–5 gate the **phase commit**. Item 6 gates the **merge**: a human reviewer
approves the pull request containing the committed phase. The order is
commit → review → merge, so a reviewer has a commit to review; never merge on
items 1–5 alone.

Operationally, run item 5 with the `/phase-review` command, and the final check
across all six gates with the `/phase-done` command.

## Conflict rule

If any artifact conflicts with another, **stop and report** rather than silently
choosing one. Within a feature, the source-of-truth priority in `CLAUDE.md` orders
the artifacts; across the process, **this document prevails** on what "done" means.

If the project maintains its own governing document (constitution, charter,
engineering principles) and it conflicts with this checklist, that is a
stop-and-report event, not a judgement call for the AI: raise it and let a human
decide which document to correct.

## Why these six and not more

Each item closes a failure this process has actually seen, and none is redundant
with another:

| Item | The failure it closes |
|---|---|
| 1 | Building the wrong thing, discovered at review |
| 2 | A phase that quietly became three, so nothing is reviewable |
| 3 | "It builds" asserted rather than demonstrated |
| 4 | Correct feature, plus unrelated edits nobody asked for |
| 5 | Rule violations no build catches (security, layering, migrations) |
| 6 | Everything mechanical passing while the behavior is still wrong |

Items 3 and 6 are the load-bearing ones: 3 is the only item backed by evidence an
AI cannot fabricate, and 6 is the only item a machine cannot perform at all.
