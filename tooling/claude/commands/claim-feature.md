# /claim-feature — claim a feature and allocate its number

Execute the claim protocol from `docs/process/team-workflow.md` §2a. This command
is the mandatory first step of starting any feature on a multi-developer project
(solo projects may skip it — computed numbering is safe with one writer).

Do NOT create any branch, folder, or spec content before the claim has landed on
main.

## Steps

1. **Preflight** — in the specs repo (the repo containing CLAUDE.md; for
   multi-repo projects, the wrapper root): verify a clean working tree, then
   pull `main`. Stop if the tree is dirty.
2. **Compute the next free number (project-wide)** — take the highest number
   across ALL roadmaps in `docs/roadmap/` and all existing `specs/feature/*`
   folders, plus one. Never trust a scaffold tool's suggestion over this.
3. **Confirm with the user** — feature name (kebab-case slug), owner, and which
   roadmap the feature belongs to (exactly one). Show the computed number.
4. **Write the claim** — add the single roadmap line: number, feature name,
   owner, status (e.g. `Claimed`). Nothing else in the commit.
5. **Commit and push directly to main** — commit message:
   `chore(roadmap): claim NNN-<feature-name> (<owner>)`. This is the sanctioned
   review-gate exemption — but it never bypasses the user: show the claim line
   and get their go-ahead before pushing.
   - **Push rejected?** Someone claimed concurrently: pull, recompute the next
     free number, update the line, push again. Repeat until it lands.
   - **Direct pushes to main forbidden?** Stop and tell the user this project
     needs the tracker-ID scheme instead (assigning yourself the issue is the
     claim); do not try to work around branch protection.
6. **Report and hand off** — state the claimed number and offer the next steps:
   create the feature branch (`feature/NNN-<name>`) and scaffold
   `specs/feature/NNN-<name>/` (e.g. via the project's spec tooling).

## Rules

- The number is identity: never recycle, never compact, gaps are fine.
- If the user asks to claim a feature that already has an owner in a roadmap,
  stop and report — reassignment is a human decision made with the current
  owner, not a claim.
- One claim per command run; one feature per claim.
