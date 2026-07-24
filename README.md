# SDLC Framework

A reusable, controlled-delivery framework for building applications with Claude Code
(or any AI coding assistant). Extracted from the WMS project and generalized.

The core methodology:

> **spec → plan → tasks → one phase at a time → user-run gate proven by a receipt →
> AI review → human review → merge.**

Supported by four ideas most teams never formalize:

1. **Source-of-truth priority with conflict rules** — artifacts are ranked; on
   conflict, stop and report instead of silently choosing.
2. **Prototype screenshots as UI authority** — when a prototype exists, the AI never
   invents a layout.
3. **Numbered rules** — every rule has an ID (B1, DB4, F12…) so reviews can cite them.
4. **Gate receipts** — the gate writes a fingerprint of the exact tree it verified,
   so "it passed" is evidence an AI can check and cannot fabricate, rather than a
   number someone transcribed (`process/gate-command.md`).

## The Three-Layer Model

Everything in this framework belongs to exactly one layer:

| Layer | Contents | Reusability | Lives in |
|-------|----------|-------------|----------|
| **1. Process** | SDLC workflow, gates, reviews, definition of done, conflict rules, spec folder layout | Any project, any stack | `process/` |
| **2. Stack rules** | Architecture and coding rules for a specific technology stack | Any project on that stack | `stacks/<stack>/` |
| **3. Project knowledge** | Domain rules, external systems, gotchas, permission vocabulary | Never reusable — starts **empty** in every new project | the project's own `docs/project/` |

**The rule that keeps the framework clean:** if a sentence mentions a specific
product, domain, or system by name, it belongs in layer 3 — never commit it to
layers 1 or 2.

## Repository Structure

```
sdlc-framework/
├── VERSION                    # framework version — stamp it into consuming projects
├── CHANGELOG.md               # what changed + what each project must re-copy
├── README.md                  # this file
├── SETUP.md                   # 6-question guided setup for a new project
├── ADOPTION.md                # adopting in an EXISTING project (governs new work only)
├── CLAUDE.md.template         # generates the consuming project's CLAUDE.md
├── process/                   # LAYER 1 — copy into every project
│   ├── project-rules.md       # spec-first, one-phase-only, branch/commit/review rules
│   ├── gate-command.md        # the gate contract (delegates to gate scripts)
│   ├── review-process.md
│   ├── rollback-process.md
│   ├── branch-strategy.md
│   ├── repository-strategy.md # incl. multi-repo wrapper pattern (optional module)
│   ├── deployment-standards.md
│   ├── definition-of-done.md
│   ├── source-artifacts.md    # authority + derivation rules for guides/prototypes/roadmaps
│   ├── team-workflow.md       # multi-developer coordination (ownership, CI gate, peer review)
│   ├── orchestration.md       # OPTIONAL — boundaries for multi-agent AI work
│   └── templates/             # AI + human review checklists
├── modules/
│   └── contracts/             # OPTIONAL — external API/webhook/auth integration patterns
├── stacks/                    # LAYER 2 — copy the one(s) you use
│   ├── dotnet-api/            # ASP.NET Core Web API + EF Core + SQL Server
│   └── nextjs-trpc/           # Next.js App Router + tRPC + NextAuth + shadcn/ui
└── tooling/                   # ships BEHAVIOR, not prose — copy alongside the docs
    ├── gate/                  # gate scripts (one command, prints EXIT: + writes a receipt)
    ├── ci/                    # gate.yml — the mechanical backstop, solo projects included
    ├── claude/                # settings template, hooks, slash commands
    └── project-docs/          # LAYER 3 skeletons (gotchas, domain rules)
tests/                         # the framework's own regression tests
    run-all.sh                 #   the framework's own gate -- CI runs this exact script
    framework-checks.sh        #   static consistency (encoding, syntax, links, layers)
    receipt-contract.sh        #   the gate receipt contract, both directions
```

## Installed Layout (in a consuming project)

`SETUP.md` copies framework folders into a standard layout. All cross-references
inside the docs assume this layout:

```
<project>/
├── CLAUDE.md                  # generated from CLAUDE.md.template
├── gate.ps1 / gate.sh         # from tooling/gate (per repo, at repo root)
├── .gate-result.json          # gate receipt — GITIGNORED, never committed
├── .github/workflows/gate.yml # from tooling/ci (per repo)
├── .claude/                   # from tooling/claude (settings, hooks, commands)
├── docs/
│   ├── process/               # ← process/
│   ├── stack-backend/         # ← stacks/<backend-stack>/   (if applicable)
│   ├── stack-frontend/        # ← stacks/<frontend-stack>/  (if applicable)
│   ├── contracts/             # ← modules/contracts/        (if applicable)
│   ├── project/               # LAYER 3 — starts empty, grows with the project
│   ├── business/              # source artifacts: guides/manuals (+ md extraction)
│   ├── prototypes/            # source artifacts: HTML prototypes + capture script
│   └── roadmap/               # source artifacts: delivery roadmap
└── specs/                     # per-feature artifacts (Spec Kit layout)
    └── <feature>/             # spec.md, plan.md, tasks.md, screenshots/, …
```

## Scope Tiers

Not every project earns the full ceremony. The dividing question is: **what does a
mistake cost?**

| | Small (solo tool, prototype) | Medium (production app, 1–3 devs) | Large (multi-repo, multi-team) |
|---|---|---|---|
| CLAUDE.md + gate script + conflict rules | ✅ | ✅ | ✅ |
| CI gate check on PRs (`tooling/ci/`) | ✅ | ✅ | ✅ |
| Spec docs | single `spec.md`, tasks inline | spec + plan + tasks | full set incl. contracts, rollback |
| Phased implementation, gate per phase | ❌ gate per feature | ✅ | ✅ |
| AI review / human review | AI only | ✅ both | ✅ both |
| Stack compliance checklists | ❌ | ✅ | ✅ |
| Roadmap doc | ❌ | optional | ✅ mandatory |
| Multi-repo wrapper | ❌ | usually ❌ | ✅ |

`SETUP.md` walks you through picking a tier.

## Versioning & Upstream-First Rule

- This repo is the **upstream**. Consuming projects record the framework version in
  their CLAUDE.md (`Framework: sdlc-framework vX.Y.Z`).
- When you improve a rule while working in a project, **port the improvement back
  here first** (or immediately after), then bump `VERSION`. Never let a project's
  copy silently diverge — that is how five projects end up with five different gates.
- `VERSION` follows semver: patch = wording fixes, minor = new rules/modules,
  major = process changes that alter how phases are gated or reviewed.
- **Every bump gets a `CHANGELOG.md` entry saying what a consuming project must
  re-copy**, and a git tag (`v1.9.0`). Upstream-first only works if downstream has
  a way to follow: without the changelog a project cannot tell what changed, and
  without the tag no tool can distinguish a legitimate upgrade from local drift.
- Downstream, `/framework-upgrade <path-to-this-repo>` walks that changelog,
  reports which local edits an upgrade would overwrite, and stops for approval.
  `/framework-doctor` checks an install is intact.

## Working on the Framework Itself

Run `sh tests/run-all.sh` before committing. CI runs that same script — the rule
this framework imposes on consuming projects applies to the framework too.

The suite covers the things that fail silently: `.ps1` files must stay ASCII-only
(Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI, and a dead hook fails
*open*), shell and PowerShell must parse, JSON/YAML must be valid, every git tag
needs a `CHANGELOG.md` entry, internal links must resolve, and the gate receipt
contract must hold in both directions.

**Layer discipline is enforced, not just asserted.** Layers 1 and 2 carried the
original project's vocabulary for twelve releases — a mandatory frontend checklist
told every project to call `ctx.featcher`. They are now generic, the baseline is
**zero**, and any reintroduction fails the build. When you fork this framework, add
your own product's terms to the pattern in `tests/framework-checks.sh`.

## Design Principles

1. **Ship behavior over prose.** Gate scripts, hooks, and slash commands transfer
   between projects with zero editing and never degrade the way instructions do.
   Prefer adding a script/hook/command over adding a paragraph.
2. **One source of truth per fact.** The gate is defined in `gate.ps1`/`gate.sh` and
   nowhere else; CLAUDE.md and docs only point to it. Never duplicate a rule in two
   files — link it.
3. **Docs win over CLAUDE.md.** CLAUDE.md is an index plus non-negotiables; on
   conflict the detailed doc prevails and the conflict gets reported and fixed.
4. **Task→doc map over "required reading".** Rules load when relevant to the task at
   hand, not as a 3,000-line prerequisite nobody actually reads.
