# /phase-done — verify the Definition of Done before declaring a phase complete

Walk `docs/process/definition-of-done.md` for the current phase. This command is a
verification gate — it must refuse to declare the phase Done when any item is
unproven.

## Step A — finish the artifacts first

Before verifying anything, complete the phase's own paperwork:

- Record the phase as complete in `specs/feature/NNN-<name>/status.md` (create it if this
  is the first phase). One line per phase: number, date, and outcome.
- **Roadmap sync** (if `docs/roadmap/` exists) — bring this feature's line in
  `docs/roadmap/status.md` in line with the phase markers in `status.md`, per
  `docs/process/source-artifacts.md`.

Do this before Step B so the Done check runs against the final state of the
feature rather than a half-written one. These two files, along with the review
artifacts written in item 5, are the *only* process files excluded from the gate
receipt's fingerprint (`docs/process/gate-command.md`).

**Write status to `status.md`, never to `tasks.md` or the roadmap definitions.**
Those are fingerprinted: they define what the phase was required to do, and
editing them here would correctly invalidate the receipt you are about to verify
in item 3. If you find yourself wanting to change `tasks.md` at this point, the
requirements moved during implementation — that is a stop-and-report event, not a
paperwork update.

## Step B — verify the Definition of Done

Check each item and collect evidence. The numbering matches
`docs/process/definition-of-done.md`:

1. **Specification approved** — the artifacts this project's scope tier requires
   exist and are approved. Read the `Scope tier:` line in `CLAUDE.md`:
   Medium/Large → `spec.md`, `plan.md`, `tasks.md`, with the current phase marked
   approved in `tasks.md`; Small → `spec.md` alone, marked approved. Do not demand
   a `plan.md` from a Small-tier project, and do not accept its absence from a
   Medium/Large one.

   Then check the approval is real rather than written. An approval line inside a
   file the AI authored proves nothing — a compliant agent writing a well-formed
   spec writes that line too. Run:

   ```
   git log -1 --format='%an <%ae>  %aI' -- specs/feature/NNN-<name>/spec.md
   git log --format='%an  %aI' -20 -- <the phase's implementation paths>
   ```

   Report item 1 as **UNPROVEN**, not satisfied, when any of these holds:
   - the spec has never been committed — it exists only in the working tree;
   - its last commit is *later* than the earliest implementation commit for this
     phase, so the requirements were finalised after the code;
   - the spec and the implementation were committed in the same commit, or by the
     same session — there was no separate act of approval to point at.

   Say which of the three it was. Do not offer to fix it by committing the spec
   now: that produces the artifact without the act, which is the exact failure this
   check exists to detect.
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
5. **AI review complete** — `specs/feature/NNN-<name>/ai-code-review.md` contains a dated
   PASS for this phase (run `/phase-review` if missing).
6. **Human review** — required before MERGE (not before commit). Confirm the user
   knows merge is blocked until a human approves. Read the `Developers:` line in
   `CLAUDE.md`: on a **team**, that human must be someone other than the feature's
   owner; **solo**, it is the developer's own acceptance review against
   `specs/_templates/human-pr-review-template.md` — a separate deliberate act, not
   a formality, and never performed by you. Never report this item as satisfied on
   your own assessment of the code.

   A ticked `human-pr-review.md` is **not** evidence. That file lives in the
   repository, you can write it, and the receipt contract deliberately does not
   fingerprint it — so its contents are exactly as trustworthy as your own report.
   The evidence is outside the tree, and the command is the one recorded on the
   `Review evidence:` line of `CLAUDE.md` — it differs per hosting platform, so do
   not assume a vendor's CLI is installed. If that line is missing or still holds a
   placeholder, say so: the project never chose its evidence, which is itself a
   finding worth reporting rather than working around.

   The everywhere-fallback is a signed trailer on the phase commit:

   ```
   git log -1 --format='%(trailers:key=Reviewed-by,valueonly)' <phase commit>
   ```

   With neither, item 6 is **PENDING** — which is the normal and correct state at
   `/phase-done` time, since review follows the commit. Report it as pending with
   the reason; never report it as satisfied because a file says so.

## Multi-repo projects — two extra checks

Skip this section entirely if `docs/process/repository-strategy.md` is not
installed; a single-repo project has nothing here to check.

A receipt is a `git write-tree` over **one** repository, and the wrapper pattern
puts the requirements (`tasks.md`, `spec.md`) in the wrapper while the code sits in
a sub-repo. So item 3's guarantee — *the requirements have not moved since the gate
ran* — holds inside each repository and not across the boundary between them. Two
things close as much of that as is closable:

7. **One valid receipt per repository this phase changed.** Check each of them
   independently. A phase touching backend and frontend with one valid receipt is
   **not** past item 3; say which repo is unproven.
8. **The wrapper's tree must be clean.** Run `git status --porcelain` at the
   wrapper root. Any output means a spec or task file may have changed after the
   gates ran, which is exactly the condition a receipt detects in-repo and cannot
   detect across repos. Report it as a FAIL on item 3 and name the dirty paths.

Then record what the receipts were measured against: write the wrapper's
`git rev-parse HEAD` into the phase's `status.md` next to each repo's receipt
verdict. `status.md` is outside every fingerprint, so writing it stales nothing.
This does not prevent a later wrapper commit from rewriting `tasks.md` — nothing
short of one repository would — but it turns "which specs was this built from" into
a SHA a reviewer can check out.

## Verdict

- Step A done and items 1–5 true → report "Phase N is Done pending human review",
  and offer the phase commit (`feat(<feature>): complete phase <N>`).
- Anything false or unproven → report exactly which items are unmet and stop. Do
  not soften the verdict, and revert the Step A status entry — a phase recorded
  complete in `status.md` that did not pass the Definition of Done makes the
  status board lie.
