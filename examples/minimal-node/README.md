# Example — Minimal Small-Tier Install

What this framework looks like after `SETUP.md` on the smallest project it
supports: **one developer, one Next.js repo, low cost of a mistake.**

Read this before installing anywhere. Setup produces a specific shape, and it is
easier to recognise that shape than to infer it from the instructions. Budget
half a day to reach it on a stack that already ships rules — see `SETUP.md`.

## The answers that produced it

| SETUP.md question | Answer |
|---|---|
| Q1 stack | Next.js + tRPC (frontend only) |
| Q2 repos | Single repo |
| Q3 designs | No design source — spec text plus the design system govern |
| Q4 integrations | None — `modules/contracts/` skipped |
| Q5 developers | Solo — coordination rules skipped, **CI kept** |
| Q6 cost of a mistake | Low → **Small tier** |

## What that produces

```
my-app/
├── CLAUDE.md                      # ← in this folder: the real, fully filled file
├── gate.sh                        # ← copied from tooling/gate/gate-node.sh
├── check-stubs.sh                 # ← copied from tooling/gate/check-stubs.sh
├── .gate-stubs-baseline           # ← generated: sh check-stubs.sh --baseline
├── .gate-sha256                   # ← generated: sha256sum gate.sh check-stubs.sh
│                                  #    .gate-stubs-baseline > .gate-sha256
├── .gitignore                     # ← in this folder: note the .gate-result.json line
├── tooling/ci/gate-ci.sh          # ← the checks; every platform installs this
├── .github/workflows/gate.yml     # ← wrapper, from tooling/ci/github/
├── .github/CODEOWNERS             # ← from tooling/ci/github/ (this example is on GitHub)
├── .claude/
│   ├── settings.json              # ← copied from tooling/claude/
│   ├── framework-manifest.json    # ← copied from framework-manifest.template.json
│   ├── hooks/                     # ← copied: guard-packages, guard-installs,
│   │                              #    verify-guard
│   └── commands/                  # ← copied: phase-review, phase-done,
│                                  #    framework-doctor, framework-upgrade
├── docs/
│   ├── process/                   # ← copied verbatim from process/
│   ├── stacks/nextjs-trpc/        # ← copied verbatim from stacks/nextjs-trpc/
│   └── project/                   # ← copied from tooling/project-docs/ (starts empty)
└── specs/
    ├── _templates/                # ← copied from process/templates/
    └── feature/001-note-tags/     # ← in this folder: a real Small-tier spec
        └── spec.md
```

**Only the files marked "in this folder" are checked in here.** Everything else is
a verbatim copy of a folder that already exists upstream, and duplicating it in the
example is exactly how an example goes stale and starts teaching the wrong thing.
Copy those folders from this repo; do not copy them from here.

Files present in this example:

- `CLAUDE.md` — every `{{…}}` placeholder filled, and every section a Small solo
  project does not use deleted. This is the file people get most wrong.
- `.gitignore` — minimal, but with the one line that matters.
- `specs/feature/001-note-tags/spec.md` — what "a single `spec.md` with tasks
  inline" actually means at Small tier. No `plan.md`, no `tasks.md`.

## What Small tier gives up, and what it does not

Given up: `plan.md`, `tasks.md`, per-phase gating, stack compliance checklists, a
roadmap, and independent peer review.

**Not** given up, at any tier:

- A spec approved before implementation starts.
- A gate the developer runs, proven by a receipt — not a pasted exit code.
- A `git diff --stat` scope check.
- AI review against the checklist.
- A human approving before merge. Solo, that is the developer's own acceptance
  review — deliberate, and separate from having written the code.
- **CI running the same gate script.** A solo project has no peer review, so CI is
  its only mechanical enforcement. It is the single least skippable item here.

## Trying it

There is no application code — this is a shape, not a runnable app. To exercise
the real thing on your own repo:

1. Follow `SETUP.md`, answering as above.
2. Run `/framework-doctor`. Fix every FAIL before writing a feature.
3. Run `./gate.sh` on your untouched baseline. It must print `EXIT: 0` **before**
   any feature work — a gate you have never seen pass is not evidence of anything.
