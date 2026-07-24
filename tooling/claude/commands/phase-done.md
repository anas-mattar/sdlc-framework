# /phase-done — verify the Definition of Done before declaring a phase complete

Walk `docs/process/definition-of-done.md` for the current phase. This command is a
verification gate — it must refuse to declare the phase Done when any item is
unproven.

## Step A — finish the artifacts first

Before verifying anything, complete the phase's own paperwork:

- Mark the phase's tasks in `specs/<feature>/tasks.md`.
- **Roadmap sync** (if `docs/roadmap/` exists) — bring the roadmap's status for
  this feature/phase in line with the phase markers in `tasks.md`, per
  `docs/process/source-artifacts.md`.

Do this before Step B so the Done check runs against the final state of the
feature rather than a half-written one. These files, along with the review
artifacts written in item 5, are excluded from the gate receipt's fingerprint
(`docs/process/gate-command.md`) — process paperwork must not invalidate a gate
result, and it can never change what builds.

## Step B — verify the Definition of Done

Check each item and collect evidence. The numbering matches
`docs/process/definition-of-done.md`:

1. **Specification approved** — the artifacts this project's scope tier requires
   exist and are approved. Read the `Scope tier:` line in `CLAUDE.md`:
   Medium/Large → `spec.md`, `plan.md`, `tasks.md`, with the current phase marked
   approved in `tasks.md`; Small → `spec.md` alone, marked approved. Do not demand
   a `plan.md` from a Small-tier project, and do not accept its absence from a
   Medium/Large one.
2. **Single-phase scope** — `git diff --stat` shows only files belonging to the
   approved phase.
3. **Gate passed** — run `./gate.ps1 -Verify` (or `./gate.sh --verify`) in each
   affected repo and quote its output. **Only `RECEIPT: valid` satisfies this
   item.** Verify runs no build; it only checks the receipt the user's gate run
   left behind (`docs/process/gate-command.md`).
   - `RECEIPT: stale` / `missing` / `min` / `failed` → ask the user to run the
     full gate (`./gate.ps1` or `./gate.sh`) and re-verify. Report which one you
     got; do not paraphrase it as "the gate needs re-running".
   - Never run the *gate itself* and treat that as satisfying this item — the
     user runs the gate. Never accept a pasted `EXIT: 0` in place of a receipt,
     and never infer success from a previous run.
4. **Diff reviewed** — the user has confirmed reviewing `git diff --stat`.
5. **AI review complete** — `specs/<feature>/ai-code-review.md` contains a dated
   PASS for this phase (run `/phase-review` if missing).
6. **Human review** — required before MERGE (not before commit). Confirm the user
   knows merge is blocked until a human approves. Read the `Developers:` line in
   `CLAUDE.md`: on a **team**, that human must be someone other than the feature's
   owner; **solo**, it is the developer's own acceptance review against
   `specs/_templates/human-pr-review-template.md` — a separate deliberate act, not
   a formality, and never performed by you. Never report this item as satisfied on
   your own assessment of the code.

## Verdict

- Step A done and items 1–5 true → report "Phase N is Done pending human review",
  and offer the phase commit (`feat(<feature>): complete phase <N>`).
- Anything false or unproven → report exactly which items are unmet and stop. Do
  not soften the verdict, do not mark the phase complete in `tasks.md`.
