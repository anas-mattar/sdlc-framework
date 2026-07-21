# SDLC Framework

A reusable, controlled-delivery framework for building applications with Claude Code
(or any AI coding assistant). Extracted from the WMS project and generalized.

The core methodology:

> **spec → plan → tasks → one phase at a time → gate with user-confirmed exit code →
> AI review → human review → merge.**

Supported by three ideas most teams never formalize:

1. **Source-of-truth priority with conflict rules** — artifacts are ranked; on
   conflict, stop and report instead of silently choosing.
2. **Prototype screenshots as UI authority** — when a prototype exists, the AI never
   invents a layout.
3. **Numbered rules** — every rule has an ID (B1, DB4, F12…) so reviews can cite them.

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
    ├── gate/                  # gate scripts (single command, prints EXIT: <code>)
    └── claude/                # settings template, hooks, slash commands
```

## Installed Layout (in a consuming project)

`SETUP.md` copies framework folders into a standard layout. All cross-references
inside the docs assume this layout:

```
<project>/
├── CLAUDE.md                  # generated from CLAUDE.md.template
├── gate.ps1 / gate.sh         # from tooling/gate (per repo, at repo root)
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
