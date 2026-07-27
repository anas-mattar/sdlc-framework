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

   **What counts as approval.** A line of text inside a file is not evidence: the
   agent wrote the file, so it can write the line, and a compliant agent producing
   a well-formed spec produces exactly the approval line the checklist looks for.
   Approval is therefore a **git object**, not a string — the spec's approving
   commit, authored by a human, made before the implementation began:

   ```
   git log -1 --format='%an <%ae>  %aI' -- <spec path>
   ```

   The item is satisfied when that author is a human and that timestamp precedes
   the phase's implementation commits. If the approving commit came from the same
   session that wrote the implementation, item 1 is **UNPROVEN** — say so rather
   than ticking it. This is checkable solo: committing your own spec first is still
   a separate, timestamped, deliberate act.
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
   match, stack rules, security, tests, migrations, unrelated changes, rollback
   safety. Plus, for **each stack this phase touches**, that stack's compliance
   checklist where it ships one (`docs/stacks/<name>/compliance-checklist.md`).

   Both conditions are load-bearing. *Each stack this phase touches* rather than a
   fixed backend/frontend pair, because a project may install any number of stacks
   under `docs/stacks/` and a phase may touch one, several, or none of them.
   *Where it ships one*, because a compliance checklist is optional in the stack
   contract — demanding one from a stack that has none makes this item impossible
   to satisfy honestly, and an item that cannot be satisfied honestly gets ticked
   dishonestly. Small tier skips stack checklists entirely; say N/A and move on.
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

   **What counts as approval.** The same argument as item 1, and it bites harder
   here. The human review template is a markdown file in the repository, and the
   receipt contract deliberately does not fingerprint it, so an agent can produce a
   fully-ticked review signed `self (solo project)` at zero cost to any mechanical
   check. The distinguishing property this item actually names — "a separate,
   deliberate act from implementing" — is a claim about a mental state, and mental
   states leave no artifact. So the signature must live somewhere the agent cannot
   write. Either is acceptable:

   ```
   <the review-evidence command recorded in CLAUDE.md>
   git log -1 --format='%(trailers:key=Reviewed-by,valueonly)' <phase commit>
   ```

   A **change-request approval** is the stronger of the two: it is timestamped,
   attached to a specific head SHA, and recorded outside the working tree — on the
   hosting platform rather than in the repository. Every platform exposes it
   differently, so the exact command is chosen at setup and written into
   `CLAUDE.md` rather than fixed here; a checklist that names one vendor's CLI is a
   checklist that cannot be satisfied honestly on any other. Solo projects can use
   it too — approving your own change request is still a deliberate, out-of-band
   act, and it is the difference between a review that happened and a file that
   says one did. The `human-pr-review.md` file remains the place the *findings* are
   recorded; it is no longer the thing that proves the review occurred.

Items 1–5 gate the **phase commit**. Item 6 gates the **merge**: a human reviewer
approves the change request containing the committed phase. The order is
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

Items 3 and 6 are the load-bearing ones: 3 is the only item backed by machine
evidence rather than assertion, and 6 is the only item whose judgement a machine
cannot perform at all.

Be precise about what item 3's evidence covers. The receipt proves *which working
tree* the gate ran against, so a pass cannot be carried over to a tree that has
since changed, and a green result cannot be transcribed by hand. It does not prove
that the gate script itself was honest, and it is not a defence against a party
with commit access on the machine — which includes the agent. That is what CI is
for: a check the author does not run. See `SECURITY.md` for the threat model.
