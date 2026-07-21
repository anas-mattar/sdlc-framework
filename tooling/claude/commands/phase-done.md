# /phase-done — verify the Definition of Done before declaring a phase complete

Walk `docs/process/definition-of-done.md` for the current phase. This command is a
verification gate — it must refuse to declare the phase Done when any item is
unproven.

## Steps

Check each item and collect evidence:

1. **Specification approved** — `spec.md`, `plan.md`, `tasks.md` exist for the
   feature and the current phase is marked approved in `tasks.md`.
2. **Single-phase scope** — `git diff --stat` shows only files belonging to the
   approved phase.
3. **Gate passed** — ask the user: "Please run `./gate.ps1` (or `./gate.sh`) in the
   affected repo(s) and paste the `EXIT:` line." **Only a user-reported `EXIT: 0`
   satisfies this item.** Never run the gate yourself and treat that as
   satisfying it; never infer success from a previous run.
4. **Diff reviewed** — the user has confirmed reviewing `git diff --stat`.
5. **AI review complete** — `specs/<feature>/ai-code-review.md` contains a dated
   PASS for this phase (run `/phase-review` if missing).
6. **Human review** — required before MERGE (not before commit). Confirm the user
   knows merge is blocked until a human reviewer approves.
7. **Roadmap sync** (if `docs/roadmap/` exists) — the roadmap's status for this
   feature/phase matches the phase markers in `specs/<feature>/tasks.md`. Update
   the roadmap as part of completing the phase, per
   `docs/process/source-artifacts.md`.

## Verdict

- All of 1–5 and 7 true → report "Phase N is Done pending human review", and
  offer the phase commit (`feat(<feature>): complete phase <N>`).
- Anything false or unproven → report exactly which items are unmet and stop. Do
  not soften the verdict, do not mark the phase complete in `tasks.md`.
