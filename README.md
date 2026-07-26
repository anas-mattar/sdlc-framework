# SDLC Framework

**Claude Code-first, with tool-neutral SDLC principles.**

A reusable, controlled-delivery framework for building applications with an AI
coding assistant. The *process* — spec-first, phased delivery, gate receipts,
layered rules, source-of-truth priority — is tool-neutral and transfers to any
assistant. The *enforcement* currently ships for one: slash commands, hooks, the
package guard, and the permissions template are Claude Code artifacts under
`tooling/claude/`. On another assistant you keep the process and re-implement the
enforcement; the gate scripts and CI workflow are plain shell/PowerShell/YAML and
carry over unchanged.

> **Status: public beta.** The process has been used in production, but the
> packaged framework has not yet been installed by someone other than its author,
> and no project has upgraded across a framework version yet. Expect breaking
> changes in minor releases until v3.0. See "Support & Version Policy" below.

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
   so "it passed" is checkable evidence about *which* tree passed, rather than a
   number someone transcribed (`process/gate-command.md`). It defends against
   staleness and transcription error; it is not a defence against a party with
   commit access, and CI is what makes the gate binding (`SECURITY.md`).

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

### Which stacks does it work on?

**Layer 1 is stack-neutral** — nothing in `process/` names a language or
framework, and the self-tests enforce that. The workflow applies unchanged to
Python, Go, Rust, Java, PHP, Ruby, mobile, or anything else.

**Layer 2 ships rules for two stacks today** — `dotnet-api` and `nextjs-trpc`.
That is the only stack-bound part, and `SETUP.md` Q1 expects you to add a folder
for yours, starting from the closest existing one.

The tooling sits in between: the gate scripts' receipt machinery is pure git and
shell, with three or four stack-specific command lines to swap; `tooling/ci/gate.yml`
needs its toolchain block replaced; and the package guard already covers 56
manifest and lockfile patterns across every mainstream ecosystem, whether or not
layer-2 rules exist for it — a guard that quietly ignores `go.mod` is worse than
no guard, because it reports itself as verified.

So a third stack costs one rules folder (the real work), plus a few lines in the
gate script and CI file.

## Repository Structure

```
sdlc-framework/
├── VERSION                    # framework version — stamp it into consuming projects
├── CHANGELOG.md               # what changed + what each project must re-copy
├── README.md                  # this file
├── SETUP.md                   # 6-question guided setup for a new project
├── ADOPTION.md                # adopting in an EXISTING project (governs new work only)
├── CONTRIBUTING.md            # how to change the framework + what the tests protect
├── SECURITY.md                # reporting; what counts as a vulnerability here
├── LICENSE                    # MIT
├── CLAUDE.md.template         # generates the consuming project's CLAUDE.md
├── examples/
│   └── minimal-node/          # what a Small-tier solo install actually looks like
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
    run-all.ps1                #   Windows launcher for the same script (not a second suite)
    framework-checks.sh        #   static consistency (encoding, syntax, links, layers, tags)
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
│       └── status.md          #   the mutable board — the rest is scope/sequencing
└── specs/                     # per-feature artifacts (Spec Kit layout)
    └── <feature>/             # spec.md, plan.md, tasks.md, status.md, screenshots/, …
```

Both `status.md` files exist because the gate receipt fingerprints requirements
but not status: ticking a phase complete after the gate must not invalidate it,
while changing what the phase was required to do must (`process/gate-command.md`).

## Scope Tiers

Not every project earns the full ceremony. The dividing question is: **what does a
mistake cost?**

| | Small (solo tool, prototype) | Medium (production app, 1–3 devs) | Large (multi-repo, multi-team) |
|---|---|---|---|
| CLAUDE.md + gate script + conflict rules | ✅ | ✅ | ✅ |
| CI gate check on PRs (`tooling/ci/`) | ✅ | ✅ | ✅ |
| Spec docs | single `spec.md`, tasks inline | spec + plan + tasks | full set incl. contracts, rollback |
| Phased implementation, gate per phase | ❌ gate per feature | ✅ | ✅ |
| AI review / human review | AI + developer acceptance | ✅ both | ✅ both |
| Stack compliance checklists | ❌ | ✅ | ✅ |
| Roadmap doc | ❌ | optional | ✅ mandatory |
| Multi-repo wrapper | ❌ | usually ❌ | ✅ |

`SETUP.md` walks you through picking a tier; the answer is recorded in the
project's `CLAUDE.md` (`Scope tier:`), and `process/project-rules.md` and
`process/definition-of-done.md` read from it.

No tier removes the human from the loop — what varies is **who** that human is.
On a team, review means a peer other than the feature's owner. Solo, it means the
developer's own acceptance review, completed deliberately and separately from
implementing. A framework that told a solo developer to find an independent
reviewer would simply be ignored, and a rule that gets ignored trains people to
ignore the others.

> **Known gap (v2.x):** the tier model is currently expressed as conditionals
> inside the layer-1 docs rather than generated per tier, so a Small install still
> receives text describing Medium/Large behavior alongside its own. Executable tier
> profiles are the headline item for the next consistency release.

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

## Support & Version Policy

- **Beta.** Minor releases may contain breaking process changes until v3.0. Every
  one is recorded in `CHANGELOG.md` with what a consuming project must re-copy.
- **Semver**, applied to process rather than to an API: patch = wording, minor =
  new rules/modules, major = changes to how phases are gated or reviewed.
- **Supported version: the latest minor only.** There are no maintenance branches.
  Upgrading is `/framework-upgrade <path-to-this-repo>`, which walks the changelog,
  reports which local edits an upgrade would overwrite, and stops for approval.
- **Every release is tagged** `vX.Y.Z`. Untagged versions are unreachable by
  `/framework-upgrade` — the self-test fails a `VERSION` with no matching tag
  unless its changelog entry is marked `(unreleased)`.
- Security reports: `SECURITY.md` (privately — never a public issue).
- Contributions: `CONTRIBUTING.md`. Licensed MIT.

What "stable" would require, and what beta means it lacks: installation by someone
other than the author without help, at least one project upgraded across framework
versions, both solo and team workflows demonstrated end to end, and at least one
non-Claude adapter. None of those are done yet — hence beta, and hence the honest
gap notice under Scope Tiers.

## Working on the Framework Itself

Run the self-tests before committing:

```sh
sh tests/run-all.sh          # macOS, Linux, WSL, Git Bash
```

```powershell
.\tests\run-all.ps1          # Windows — finds Git's sh.exe and runs the same suite
```

CI runs `run-all.sh` — the rule this framework imposes on consuming projects
applies to the framework too. The PowerShell entry point is a **launcher, not a
second suite**: reimplementing the checks would create a second definition of "the
framework passes", and the two would drift. It is why a Windows contributor never
needs to reason about which command is authoritative.

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
