# Review Process

## Terminology — this is the canonical definition

**Change request** — the unit of review your hosting platform merges: a *pull
request* on GitHub, Azure DevOps and Bitbucket, a *merge request* on GitLab. Every
document in this framework says "change request" so that a rule written once
applies wherever the project is hosted. Which platform this project uses, and the
command that proves a change request was approved, are recorded in `CLAUDE.md`.

**Protected-branch rules** — the platform setting that stops a branch being pushed
to directly and makes a status check mandatory before merge. Called *branch
protection* on GitHub, *protected branches* on GitLab, *branch policies* on Azure
DevOps, *branch restrictions* on Bitbucket.

**Code ownership** — the mechanism that requires a named human to approve changes
to a specific path. A `CODEOWNERS` file on GitHub and GitLab; *automatically
included reviewers* in an Azure DevOps branch policy; *default reviewers* on
Bitbucket. `tooling/ci/` ships the file or the instructions for each.

> One filename is deliberately not renamed: the human review is recorded in
> `specs/feature/NNN-<name>/human-pr-review.md`. That name is written into every
> gate script's receipt exclusions and into the review templates, and renaming a
> fingerprint-excluded path to improve wording is how an exclusion silently stops
> matching. The file's name is historical; the rule it records is not.

## After Each Phase

1. User runs the gate script (`docs/process/gate-command.md`).
2. User checks:

```bash
git diff --stat
```

3. Fix only current phase issues.
4. Revert unrelated changes.
5. Commit successful phase.
6. Do not start next phase without approval.

## AI Review

Check:
- Spec match
- Screenshot match
- Backend rules
- Frontend rules
- Security
- Tests
- Migrations
- Unrelated changes
- Rollback safety

## Human Review

AI review alone is insufficient. **Human review is required before merge**, and a
change MUST NOT be merged until a human approves it. Who that human may be, and
what counts as evidence of approval, is defined once in
`docs/process/definition-of-done.md` item 6 — do not restate it here.

Human reviewer checks:
- Actual UI vs screenshots
- Business behavior
- Financial / domain correctness
- Security implications
- Architectural compliance
- Code diff
- Gate result
- No unrelated changes

## Merge

Merge only after the human reviewer approves. See the consolidated gates in
`docs/process/definition-of-done.md`.
