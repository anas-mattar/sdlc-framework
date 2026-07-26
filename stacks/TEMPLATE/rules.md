# Stack Rules — {{STACK_NAME}}

> **This is the contract for a `stacks/<name>/` folder.** Copy this directory to
> `stacks/<your-stack>/`, replace the placeholders, delete what does not apply, and
> keep the file names below. `SETUP.md` Q1 asks you to write one of these when your
> stack has no folder yet; before this template existed you had to reverse-engineer
> the shape from two folders that did not agree with each other — one shipped
> `architecture-rules.md` with 36 numbered rules, the other `rules.md` with 8.

## The file contract

A stack folder is **layer 2**: rules that hold for any project on this technology,
and nothing that names a product, a domain, or a company. Only `rules.md` is
required.

| File | Required | What belongs in it |
|---|---|---|
| `rules.md` | **yes** | The numbered rules themselves. This is the file every other document links to. |
| `compliance-checklist.md` | no | A per-phase checklist the AI review walks. Ship one only if the stack has failure modes a reviewer would otherwise miss. |
| `security.md` | no | Authorization, secrets, injection, upload handling — where the stack's defaults are unsafe. |
| `database-rules.md` | no | Schema conventions, migrations, soft delete, audit fields. |
| `performance.md` | no | N+1s, bundle size, caching — the stack's characteristic slow paths. |
| anything else | no | Split `rules.md` when it gets long. Keep names descriptive and lowercase-hyphenated. |

Do **not** invent a second name for `rules.md`. `architecture-rules.md` exists in
`stacks/dotnet-api/` for historical reasons and is the thing this template is
correcting; new stacks use `rules.md`.

## Rule IDs

Every rule gets a stable ID so a review can cite it:

```
{{PREFIX}}1  — one short imperative sentence, testable by reading a diff.
```

Pick a two- or three-letter `{{PREFIX}}` unique across the stacks a project might
install together (`B` backend, `F` frontend, `DB` database, `SEC` security). IDs are
**append-only**: never renumber, because review artifacts in old specs cite them.
Retire a rule by marking it withdrawn rather than reusing its number.

A rule is worth an ID when a reviewer could plausibly disagree about whether the
code follows it. Preferences that no review would ever cite do not need one, and
numbering them dilutes the ones that matter.

## What does NOT belong here

- **Product, domain, or company names.** Those are layer 3 — the consuming
  project's `docs/project/`. The self-tests enforce this on `process/`; for
  `stacks/` it is on you.
- **Commands.** The gate script is the only place gate commands are defined
  (`process/core/gate-command.md`). Naming `yarn test` here creates a second copy
  that will drift.
- **Process.** When a review happens, what "done" means, and who approves are layer
  1. This file says what good code looks like on this stack, nothing else.

## Numbered rules

### Architecture

- **{{PREFIX}}1** —
- **{{PREFIX}}2** —

### Data access

- **{{PREFIX}}3** —

### Error handling

- **{{PREFIX}}4** —

<!-- Add sections as the stack needs them. Keep each rule to one sentence a
     reviewer can check against a diff; move the reasoning to a note beneath it. -->
