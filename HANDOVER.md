# Project Handover — `sdlc-framework` Evaluation Engagement

**Document version:** 1.0
**Prepared:** 26 July 2026
**Repository under evaluation:** `D:\solutions\sdlc-framework` (VERSION `2.3.0`, unreleased)
**Owner:** DPO International Sdn Bhd — `ict.admin@dpointernational.com`
**Device:** `mys227` (Windows; repo on `D:` drive) · Timezone `Asia/Ulaanbaatar` (UTC+8)

> **Read this first.** This engagement is **not** a software build. No application was written, no
> database exists, no APIs were deployed. The work is a **repeated adversarial evaluation** of a
> process-and-tooling framework the user authored. The deliverables are four HTML evaluation reports.
> Sections below that request database/API/deployment detail are answered honestly — where the
> concept does not exist in this project, it is marked **Not applicable** and the closest real
> analogue is documented instead. Do not invent content for those sections.

---

# 1. Executive Summary

## 1.1 Overall purpose of the project

Two distinct things are in play, and they must not be conflated:

| | What it is | Who owns it |
|---|---|---|
| **The subject** | `sdlc-framework` — a reusable, Claude-Code-first framework that governs how software is built with an AI coding assistant. Ships process documents, stack rule sets, gate scripts, PreToolUse hooks, slash commands, CI workflow, and a self-test suite. | The user (author) |
| **The engagement** | Independent design critique + adversarial red-team of that framework, repeated across four rounds as the user fixed findings. | Claude (this session) |

The engagement's purpose: **find every place where the framework claims a guarantee that no mechanism
actually enforces**, prove each finding by execution rather than inspection, and hand back concrete
minimal fixes.

## 1.2 Current status

- **Framework version:** `2.3.0`, marked *unreleased* in `CHANGELOG.md`.
- **Framework self-test:** **RED** — `sh tests/run-all.sh` → `EXIT: 1`. 89 assertions pass, 1 fails.
- **Findings from rounds 1–3: all 45 resolved and verified.**
- **Round-4 findings: 15 open** (2 Critical, 4 High, 6 Medium, 3 Low).
- **Evaluation reports delivered:** 4 (see §14).
- **No project has ever installed or upgraded this framework other than its author.** This remains
  the single largest unretired risk and has been the closing note of every report.

## 1.3 Main objectives

1. Determine whether the framework's central claim — that the gate receipt is evidence an AI
   "cannot fabricate" — is true. **Answer: it was false; the claim has since been corrected rather
   than the mechanism strengthened, which was judged the honest resolution.**
2. Find every fail-open path in the enforcement tooling (gate scripts, package guards, install
   guards, stub ratchet, CI steps).
3. Critique the process design: coherence, layer discipline, weight/ceremony, adoption friction,
   upgrade viability, extensibility.
4. Re-verify after each fix round, and adversarially attack the fixes themselves.

## 1.4 Outstanding work

**Immediate (blocks release):**
- `G1` — one-line bug making the framework's own suite red.
- `G2` — repository filename (`-q`) silently zeroes the stub ratchet.

**High:**
- `G3`–`G6` — `verify-guard` certifies guards it never tested; `cp -t` perimeter bypass.

**Structural, unretired for four rounds:**
- **No real project has upgraded across a framework version.** The manifest, the `<!-- LOCAL -->`
  preserved-region convention, and `/framework-upgrade` remain entirely untested against reality.

Full prioritised list in §13.

---

# 2. Business Context

## 2.1 Business requirements

| ID | Requirement | Source |
|---|---|---|
| BR-1 | The framework must make "the build passed" a **falsifiable claim**, not an assertion an AI can make freely. | `README.md` idea #4; the gate receipt |
| BR-2 | The process must be **tool-neutral** in its principles even though enforcement ships for Claude Code only. | `README.md` opening |
| BR-3 | Adoption must not require retrofitting existing code. | `ADOPTION.md` |
| BR-4 | The framework must be adoptable by a solo developer and by a small team, with scope tiers. | `SETUP.md` Q5/Q6 |
| BR-5 | Rules must be citable in reviews (numbered rule IDs). | `README.md` idea #3 |
| BR-6 | Layer discipline: nothing project-specific may leak into reusable layers. | Three-layer model |

## 2.2 Functional requirements

- **Spec-first workflow:** `spec → plan → tasks → one phase at a time → user-run gate proven by a
  receipt → AI review → human review → merge`.
- **Gate receipt:** a content fingerprint of the working tree written by the gate, verifiable by
  `--verify`, which must go stale when the tree changes.
- **Package guard:** blocks manifest/lockfile edits without human approval.
- **Install guard:** blocks dependency-installing shell commands.
- **Stub ratchet:** count of unimplemented markers may not increase.
- **Exceptions mechanism:** a recorded, bounded escape hatch that blocks the *next* PR when overdue.
- **Slash commands:** `/phase-done`, `/phase-review`, `/claim-feature`, `/framework-doctor`,
  `/framework-upgrade`.
- **Self-test suite:** the framework tests its own enforcement in CI.

## 2.3 Non-functional requirements

| NFR | Detail |
|---|---|
| **Cross-platform parity** | Every control ships twice (`.sh` + `.ps1`). Both must give identical verdicts. This has been the single largest source of defects. |
| **Fail closed** | Any control that cannot determine an answer must block, never allow. |
| **Performance** | Hooks run on *every* PreToolUse call. A hook that exceeds Claude Code's timeout is a hook that is not enforcing. (Drove finding `R1`.) |
| **No silent skips** | A check that skips must fail in CI. (`if [ -n "${CI:-}" ]; then bad …` pattern.) |
| **Zero runtime deps beyond POSIX + git** | `.sh` tooling uses `awk`, `sed`, `tr`, `grep`, `git` only. |
| **Honesty of claims** | Documented guarantees must match what the mechanism actually delivers. |

## 2.4 Assumptions

1. The adversary the framework must resist is **the AI agent itself** — a party with commit access
   running on the checked machine. This is why "a developer could defeat it" is *not* a valid excuse.
2. `git` is present and the project is a git repository.
3. CI is GitHub Actions with `ubuntu-latest` (pwsh preinstalled).
4. Windows is the framework author's primary platform; macOS/Linux users must swap hook commands.
5. macOS filesystems are case-insensitive (drove the case-fold findings).
6. Consuming projects copy files rather than depending on a package (copy-based distribution).

## 2.5 Constraints

- **Nothing that runs on the checked machine can stop a determined agent.** Accepted and now
  documented in `SECURITY.md`.
- **Copy-based distribution** means every upgrade is a file-replacement problem, not a version bump.
- **Only two stacks ship** (`dotnet-api`, `nextjs-trpc`) plus `stacks/TEMPLATE/`.
- **Public beta:** never installed by anyone but the author; never upgraded across a version.
- Evaluation was performed in a cloud sandbox; the user's repo is reached over a device bridge with
  a known staleness caveat (§15.5).

---

# 3. Technical Architecture

## 3.1 Overall architecture

The framework is a **three-layer document + behaviour model**:

| Layer | Contents | Reusability | Ships in | Installs to |
|---|---|---|---|---|
| **1. Process** | SDLC workflow, gates, reviews, DoD, conflict rules, exceptions | Any project, any stack | `process/core/`, `process/team/`, `process/optional/` | `docs/process/` |
| **2. Stack rules** | Architecture + coding rules for one technology stack | Any project on that stack | `stacks/<name>/` | `docs/stacks/<name>/` |
| **3. Project knowledge** | Domain rules, gotchas, external systems | **Never reusable** — starts empty | `tooling/project-docs/` (skeletons) | `docs/project/` |

**The rule that keeps it clean:** if a sentence names a specific product, domain, or system, it
belongs in layer 3 — never commit it to layers 1 or 2.

Cutting across the layers is **tooling** (`tooling/`), which ships *behaviour* rather than prose:
gate scripts, hooks, CI workflow, slash commands, CODEOWNERS, install manifest.

## 3.2 Components

| Component | Files | Responsibility |
|---|---|---|
| **Gate scripts** | `tooling/gate/gate-node.{sh,ps1}`, `gate-dotnet.{sh,ps1}` | Run build/lint/test, compute a tree fingerprint, write `.gate-result.json`. `--verify` / `-Verify` re-fingerprints and reports freshness. |
| **Stub ratchet** | `tooling/gate/check-stubs.{sh,ps1}` | Count unimplemented markers over source files; fail if the count rises above `.gate-stubs-baseline`. |
| **Package guard** | `tooling/claude/hooks/guard-packages.{sh,ps1}` | PreToolUse hook on `Edit\|MultiEdit\|Write\|NotebookEdit`. Blocks 86 manifest/lockfile patterns and the guard's own configuration. |
| **Install guard** | `tooling/claude/hooks/guard-installs.{sh,ps1}` | PreToolUse hook on `Bash`. Blocks 56 install command patterns plus mutation of the guard perimeter. |
| **Guard verifier** | `tooling/claude/hooks/verify-guard.{sh,ps1}` | Reads `settings.json`, resolves the *configured* hook command, and executes it against sample payloads. |
| **CI workflow** | `tooling/ci/gate.yml` | Pin the gate → marker-not-committed → stub ratchet → overdue exceptions → guards actually block → run the gate. |
| **Ownership** | `tooling/ci/CODEOWNERS` | Requires named review on the enforcement perimeter. |
| **Install manifest** | `tooling/claude/framework-manifest.template.json` | 23 entries mapping upstream → installed path + class (`copy` / `merge` / `local`). Makes `/framework-upgrade` mechanical. |
| **Slash commands** | `tooling/claude/commands/*.md` | Agent-facing procedures. |
| **Self-tests** | `tests/*.sh`, `tests/fixtures/*` | Four suites, 90 assertions. |

## 3.3 Services

**Not applicable.** No running services. All components are scripts executed synchronously by a
developer, by Claude Code's hook system, or by GitHub Actions.

## 3.4 APIs

**No network APIs exist.** See §7 for the three *contracts* that function as APIs.

## 3.5 Database

**Not applicable — no database.** Persisted state lives in four flat files. See §6.

## 3.6 External integrations

| Integration | Purpose | Notes |
|---|---|---|
| **git** | Fingerprinting (`read-tree`/`add -A`/`write-tree`), file enumeration (`ls-files`), approval attestation (`git log`), history checks. | Hard dependency. |
| **GitHub Actions** | Runs `tests/run-all.sh` (framework) and `gate.yml` (consuming projects). | `ubuntu-latest`; `fetch-depth: 0` required. |
| **GitHub CODEOWNERS + branch protection** | Enforces human review on the enforcement perimeter. | Cannot be verified locally; `/framework-doctor` reports it as unverifiable. |
| **`gh` CLI** | DoD item 6 evidence: `gh pr view --json reviews`. | Introduced in the round-2 fix for H2. |
| **Claude Code** | Hooks (`PreToolUse`), slash commands, permissions allowlist. | Hook exit code `2` = block; anything else = error and **fails open**. |
| **GitHub Spec Kit** (optional) | `specify init` scaffolding. | Referenced in `branch-strategy.md`. |

## 3.7 Authentication

**Not applicable in the conventional sense.** The framework's "authentication" concerns are:

- **Human approval attestation.** Two DoD items must be signed by a human. Both were originally
  strings in AI-writable files (finding `H2`); both now bind to objects outside the agent's reach:
  - Item 1 (spec approved): a **git object** — `git log -1 --format='%an <%ae> %aI' -- <spec path>`.
  - Item 6 (human review): a **PR approval** — `gh pr view --json reviews --jq '[.reviews[] | select(.state=="APPROVED")]'`.
- **Package-change approval:** presence of `.claude/allow-package-changes`, created only by a human.
  The guards now block writes to that marker on both the Edit/Write and Bash paths.

## 3.8 Deployment

The framework is **copied**, not installed as a dependency.

```
SETUP.md (9 steps, 24 sub-steps) →
  process/core/        → docs/process/
  process/team/        → docs/process/          (if Q5 ≥ 2 developers)
  process/optional/*   → docs/process/          (per Q2/Q4, file by file)
  stacks/<name>/       → docs/stacks/<name>/    (once per stack, n slots)
  process/templates/   → specs/_templates/
  tooling/gate/gate-<stack>.sh|ps1 → <repo>/gate.sh|gate.ps1
  tooling/gate/check-stubs.sh|ps1  → <repo>/check-stubs.sh|ps1
  tooling/ci/gate.yml  → .github/workflows/gate.yml
  tooling/ci/CODEOWNERS→ .github/CODEOWNERS
  tooling/claude/*     → .claude/
  tooling/project-docs/→ docs/project/          (skeletons, start empty)
  CLAUDE.md.template   → CLAUDE.md              (merge; fill placeholders)
  framework-manifest.template.json → .claude/framework-manifest.json
```

Then: `sha256sum gate.sh check-stubs.sh .gate-stubs-baseline > .gate-sha256`, enable branch
protection, run `/framework-doctor`, make the baseline commit.

**Realistic time-to-first-value:** *half a day* for a stack that already ships rules; a day or more
if authoring a new `stacks/` folder. (The original "~15 minutes" claim was finding `H11` and is fixed.)

## 3.9 Infrastructure

| Element | Detail |
|---|---|
| Framework repo | `D:\solutions\sdlc-framework` on device `mys227` |
| Framework CI | `.github/workflows/selftest.yml` → `sh tests/run-all.sh`, on PR and push to `main`, `fetch-depth: 0` |
| Consuming project CI | `.github/workflows/gate.yml` (copied from `tooling/ci/gate.yml`) |
| Release tags | `v1.0.0` … `v2.2.0` exist locally (15 tags). `v2.3.0` not yet tagged. |
| Evaluation environment | Anthropic cloud sandbox: Linux, git 2.43, node 22, PowerShell 7.4.6 installed at `/opt/pwsh/pwsh`, `/bin/sh` → `dash` |

---

# 4. Technology Stack

## 4.1 Backend

**Not applicable** — the framework has no backend. The *stack rules it ships for* target:

- **`stacks/dotnet-api/`** — ASP.NET Core Web API, EF Core, SQL Server. Rule IDs `B1`–`B36`,
  `DB1`–`DB13`, `BP2`–`BP3`.
- **`stacks/TEMPLATE/rules.md`** — contract for authoring a new stack folder (added round 2).

## 4.2 Frontend

**Not applicable to the framework itself.** Shipped rules target:

- **`stacks/nextjs-trpc/`** — Next.js App Router, tRPC, NextAuth, shadcn/ui, React Hook Form +
  `zodResolver`, TanStack-style data tables. Rule IDs `F8a`, `F8a-1`, `F8b`–`F8d`, `F11a`–`F11c`.

## 4.3 Database

**Not applicable.** See §6 for the flat-file state.

## 4.4 Infrastructure

- Git (fingerprinting, enumeration, attestation)
- GitHub (Actions, CODEOWNERS, branch protection, PR reviews)
- POSIX shell (`dash`-compatible), PowerShell 5.1+ / 7.x

## 4.5 CI/CD

| File | Runs |
|---|---|
| `.github/workflows/selftest.yml` | `sh tests/run-all.sh` — the framework's own gate |
| `tooling/ci/gate.yml` | Pin the gate · marker not committed · stub ratchet · no overdue exceptions · guards actually block · run the gate |

Toolchain blocks for Node and .NET are **both commented out** by default (fix for a round-1 finding);
the user uncomments exactly one.

## 4.6 Cloud

None. No cloud services are used or required by the framework.

## 4.7 Third-party libraries

The framework itself has **zero library dependencies**. Runtime dependencies are `git`, `awk`, `sed`,
`tr`, `grep` for `.sh`; PowerShell built-ins (`ConvertFrom-Json`, `Set-Content`) for `.ps1`.
CI additionally installs `pyyaml` for the YAML validity self-test.

## 4.8 Frameworks

Claude Code (hooks, slash commands, permissions). GitHub Spec Kit (optional).

## 4.9 Tools used during the evaluation

| Tool | Use |
|---|---|
| `device_bash` + tarball | **The only reliable way to pull a fresh snapshot** (see §15.5) |
| `device_stage_files` / `device_commit_files` | Transfer to/from the user's disk |
| Sandbox `bash`, `git`, `node`, `/opt/pwsh/pwsh` | Executing every reproduction |
| `Agent` subagents (opus) | Parallel adversarial passes; findings always re-verified by the main session |
| `dataviz` skill | Palette and mark specs for the HTML reports |

---

# 5. Folder Structure

Exact tree at the time of handover (81 files, `.git` excluded):

```
sdlc-framework/
├── .gitattributes                      # pins *.ps1 CRLF, *.sh LF (fix for H1)
├── .github/
│   ├── ISSUE_TEMPLATE/{bug_report.yml, config.yml, rule_proposal.yml}
│   ├── pull_request_template.md
│   └── workflows/selftest.yml          # framework's own CI
├── ADOPTION.md                         # adopting in an EXISTING project
├── CHANGELOG.md                        # ~46 KB; per-release upgrade tables
├── CLAUDE.md.template                  # generates the consuming project's CLAUDE.md
├── CONTRIBUTING.md
├── LICENSE                             # MIT
├── README.md
├── SECURITY.md                         # threat model; in-scope vulnerability classes
├── SETUP.md                            # 6-question guided setup, 9 steps
├── VERSION                             # 2.3.0
├── examples/minimal-node/              # a finished Small-tier solo install
│   ├── .gitignore
│   ├── CLAUDE.md
│   ├── README.md
│   └── specs/feature/001-note-tags/spec.md
├── modules/contracts/                  # OPTIONAL module
│   ├── auth-patterns.md
│   ├── external-api-contract-template.md
│   └── webhook-patterns.md
├── process/                            # LAYER 1
│   ├── core/                           # always installed
│   │   ├── branch-strategy.md
│   │   ├── definition-of-done.md       # the 6 DoD items
│   │   ├── exceptions.md               # bounded escape hatch (added round 2)
│   │   ├── gate-command.md             # the gate contract
│   │   ├── project-rules.md
│   │   ├── review-process.md
│   │   ├── rollback-process.md
│   │   └── source-artifacts.md         # authority + derivation rules
│   ├── optional/                       # installed conditionally
│   │   ├── deployment-standards.md
│   │   ├── orchestration.md            # multi-agent boundaries
│   │   └── repository-strategy.md
│   ├── team/team-workflow.md           # installed when developers ≥ 2
│   └── templates/
│       ├── ai-code-review-template.md
│       └── human-pr-review-template.md
├── stacks/                             # LAYER 2
│   ├── TEMPLATE/rules.md               # contract for a new stack (added round 2)
│   ├── dotnet-api/{architecture-rules, database-best-practices, database-rules}.md
│   └── nextjs-trpc/{compliance-checklist, forms, performance, rules, security,
│                    state-auth-style, tables, trpc}.md
├── tests/                              # the framework's own regression suite
│   ├── run-all.sh / run-all.ps1        # the framework's gate; CI runs run-all.sh
│   ├── framework-checks.sh             # ~40 KB, 34 static + behavioural checks
│   ├── receipt-contract.sh             # 22 assertions on the receipt contract
│   ├── gate-powershell.sh              # 13 assertions on .ps1 gate behaviour
│   ├── exceptions-check.sh             # 21 assertions on the CI exceptions awk
│   ├── run-guard-cases.ps1             # .ps1 side of behavioural guard parity
│   └── fixtures/
│       ├── guard-cases.tsv             # 112 payload rows, expected verdicts
│       ├── stub-lines.md               # 13 marker/exemption line cases
│       └── stub-paths.txt              # 46 path-classification cases
└── tooling/                            # ships BEHAVIOUR, not prose
    ├── ci/
    │   ├── CODEOWNERS                  # enforcement perimeter ownership
    │   └── gate.yml                    # consuming project's CI gate
    ├── claude/
    │   ├── commands/{claim-feature, framework-doctor, framework-upgrade,
    │   │             phase-done, phase-review}.md
    │   ├── framework-manifest.template.json   # 23 install entries
    │   ├── hooks/{guard-installs, guard-packages, verify-guard}.{sh,ps1}
    │   └── settings.json               # permissions + PreToolUse hook wiring
    ├── gate/{gate-node, gate-dotnet, check-stubs}.{sh,ps1}
    └── project-docs/{domain-rules.md, gotchas.md}   # LAYER 3 skeletons
```

### Installed layout in a consuming project

```
<project>/
├── CLAUDE.md                       # merged from CLAUDE.md.template
├── gate.sh / gate.ps1              # copied from tooling/gate/gate-<stack>.*
├── check-stubs.sh / check-stubs.ps1
├── .gate-sha256                    # pins gate.sh, check-stubs.sh, .gate-stubs-baseline
├── .gate-stubs-baseline
├── .gate-result.json               # the receipt — GITIGNORED, never committed
├── .claude/
│   ├── settings.json
│   ├── framework-manifest.json
│   ├── commands/, hooks/
│   └── allow-package-changes       # transient, human-created, never committed
├── .github/{workflows/gate.yml, CODEOWNERS}
├── docs/
│   ├── process/                    # layer 1
│   ├── stacks/<name>/              # layer 2, n slots
│   ├── project/                    # layer 3, starts EMPTY
│   ├── roadmap/{README.md, status.md}
│   ├── business/, prototypes/
│   └── exceptions.md               # the exceptions ledger
└── specs/
    ├── _templates/                 # review checklists
    └── feature/NNN-<name>/
        ├── spec.md, plan.md, tasks.md
        ├── status.md               # EXCLUDED from the fingerprint
        ├── ai-code-review.md       # EXCLUDED
        ├── human-pr-review.md      # EXCLUDED
        ├── contracts/, data-model.md, screenshots/
        └── rollback.md             # Large tier only
```

---

# 6. Database Design

**There is no database.** No tables, relationships, keys, indexes, views, stored procedures, or
triggers were designed or discussed for this project.

The nearest analogue — **persisted state files** — is documented here because the next AI will need it.

## 6.1 Persisted state files

| File | Format | Committed? | Purpose |
|---|---|---|---|
| `.gate-result.json` | JSON | **No** — must be gitignored | The gate receipt |
| `.gate-stubs-baseline` | Plain integer + newline | Yes, and **pinned** | Stub ratchet baseline |
| `.gate-sha256` | `sha256sum` output lines | Yes, and owned in CODEOWNERS | Integrity pin |
| `docs/exceptions.md` | Markdown table | Yes, and owned | Exceptions ledger |
| `.claude/framework-manifest.json` | JSON | Yes | Install record for `/framework-upgrade` |
| `.claude/allow-package-changes` | Empty marker file | **No** — CI fails if committed | Transient package-change approval |

## 6.2 Receipt schema (`.gate-result.json`)

```json
{
  "exit": 0,
  "mode": "full",
  "tree": "2a0364cb44cd604431873dc988aca164d400ce5f",
  "head": "5a92f2d01640b644f6a13918e453deca99d505b2",
  "utc": "2026-07-26T14:32:26Z"
}
```

| Field | Meaning | Constraint |
|---|---|---|
| `exit` | Exit code of the gate run | Must be `0` for `RECEIPT: valid` |
| `mode` | `"full"` or `"min"` | `"min"` is rejected by `--verify` |
| `tree` | Fingerprint of the working tree | Must equal the current fingerprint; the literal `"unknown"` is now rejected on **both** sides |
| `head` | `git rev-parse HEAD` at gate time | Informational |
| `utc` | Timestamp | Informational — **never** used for freshness |

## 6.3 Fingerprint algorithm (the closest thing to a schema constraint)

```sh
RECEIPT_EXCLUDES=".gate-result.json specs/*/status.md specs/*/ai-code-review.md \
                  specs/*/human-pr-review.md docs/roadmap/status.md"

fingerprint() {
    idx="${TMPDIR:-/tmp}/gate-index-$$"
    GIT_INDEX_FILE="$idx" git read-tree HEAD 2>/dev/null
    GIT_INDEX_FILE="$idx" git add -A 2>/dev/null
    set -f
    GIT_INDEX_FILE="$idx" git rm --cached -q -r --ignore-unmatch $RECEIPT_EXCLUDES 2>/dev/null
    set +f
    tree=$(GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null)
    rm -f "$idx"
    [ -n "$tree" ] || tree="unknown"
    echo "$tree"
}
```

**Critical invariants — do not "fix" these:**

1. The throwaway `GIT_INDEX_FILE` is what makes `--verify` a pure read that never disturbs the
   developer's real index. A self-test asserts this.
2. `RECEIPT_EXCLUDES` are **git pathspecs**, matched with `fnmatch` *without* `FNM_PATHNAME`, so `*`
   crosses `/`. `specs/*/status.md` therefore matches `specs/feature/001-x/status.md`. **Do not**
   "correct" these to `specs/feature/*/`. Getting it wrong un-excludes every status file and makes
   every receipt stale the moment `/phase-done` writes one.
3. Exclusions carry **status only, never requirements**. `tasks.md`, `spec.md`, `plan.md`, the
   roadmap definitions and `contracts/` are all fingerprinted. `receipt-contract.sh` asserts **both**
   directions. This was the v2.2.0 insight and it is the framework's best piece of design.
4. `-r` is kept on `git rm --cached` even though every pattern names a file: without it, a pattern
   that ever resolves to a directory aborts the whole call and applies **no** exclusions silently.

## 6.4 Exceptions ledger format

```markdown
| Date | Feature | Phase | Why | Authoriser | Remediate by |
|---|---|---|---|---|---|
| 2026-03-04 | 014 | 2 | Prod incident | A. Nkemi | 2026-03-11 |
| ~~2026-01-01~~ | 013 | 5 | resolved | B. Cheng | ~~2026-01-08~~ |
```

Parsed by an awk program in `gate.yml` (extracted and tested by `tests/exceptions-check.sh`):
header-name column detection, first-cell strikethrough = closed, real date validation (leap years,
month/day ranges), row-shape validation, per-table column rebinding.

---

# 7. APIs

**No network APIs exist.** Three contracts function as the project's interfaces.

## 7.1 Gate CLI contract

| Aspect | Detail |
|---|---|
| **Endpoint** | `./gate.sh` / `./gate.ps1` at the repository root |
| **Methods** | *(none)* full gate · `--min` / `-Min` build only · `--verify` / `-Verify` evidence read |
| **Request** | Command-line flag only |
| **Response** | stdout `EXIT: <code>`; writes `.gate-result.json`; process exit code equals the gate code |
| **`--verify` responses** | `RECEIPT: valid — full gate, EXIT: 0, tree <sha>` (exit 0)<br>`RECEIPT: missing — run ./gate.sh` (1)<br>`RECEIPT: stale — the working tree changed after the gate ran` (1)<br>`RECEIPT: min — only the minimum gate ran` (1)<br>`RECEIPT: failed — recorded EXIT: <n>` (1)<br>`RECEIPT: unverifiable — the working tree could not be fingerprinted` (1) |
| **Authentication** | None. Trusting the user to run the gate is deliberate; trusting a transcribed number is not. |
| **Validation** | Fingerprint equality, `mode == "full"`, `exit == 0`, and `tree != "unknown"` on both the recorded and current side. |
| **Error handling** | Fails closed. An unfingerprintable tree writes **no receipt** and exits 1. A step producing no exit code is treated as `127`. |

## 7.2 PreToolUse hook contract (Claude Code)

| Aspect | Detail |
|---|---|
| **Invocation** | Claude Code pipes a JSON payload on stdin before the matched tool runs |
| **Matchers** | `Edit\|MultiEdit\|Write\|NotebookEdit` → `guard-packages`; `Bash` → `guard-installs` |
| **Request** | `{"tool_name":"Write","tool_input":{"file_path":"package.json"}}` or `{"tool_name":"Bash","tool_input":{"command":"npm install left-pad"}}` |
| **Response** | Exit code only. `2` = **block**, stderr shown to Claude. `0` = allow. **Anything else = hook error, which fails OPEN.** |
| **Authentication** | `.claude/allow-package-changes` presence = human approval. The marker cannot authorise its own creation. |
| **Validation** | awk string-aware JSON walk. Exit `0` value found · `3` key absent (allow — not our call) · `4` key present but malformed (**block**). |
| **Error handling** | `guard-installs` blocks with an explanatory message when extraction fails. |

**Known contract gaps (open):** array values → `.sh` allows, `.ps1` blocks; duplicate keys → the two
take opposite values (`G8`).

## 7.3 Stub ratchet CLI contract

| Mode | Behaviour |
|---|---|
| *(none)* | Compare current count to `.gate-stubs-baseline`; exit 1 if higher |
| `--count` / `-Count` | Print the count |
| `--baseline` / `-Baseline` | Write the current count as the new baseline |
| `--classify <path>…` | Print `source <p>` or `skip <p>` per path (test support) |
| `--scan <file>…` | Print matching lines, ignoring `is_source` (test support) |

**Markers (9):** `TODO`, `FIXME`, `HACK`, `XXX`, `NotImplementedException`, `NotImplementedError`,
`not implemented`, `unimplemented`, `stub` (case-sensitive per the fixture).
**Exemption:** `approved-stub: <reason>` on the line — the reason is **required** and non-empty.

---

# 8. Features

Features are of the framework under evaluation. Status reflects the framework, not the engagement.

| Feature | Status | Description | Dependencies | Remaining work |
|---|---|---|---|---|
| **Gate receipt** | ✅ Completed | Content fingerprint of the working tree; `--verify` reports freshness. 22 assertions. | git | None. Forgeability is documented, not fixed (by design). |
| **Receipt status/requirements split** | ✅ Completed | Only status files excluded; requirements always fingerprinted. Asserted both directions. | Gate receipt | None |
| **PowerShell gate parity** | ✅ Completed | `$LASTEXITCODE`-is-null → 127; unfingerprintable tree fails closed. 13 assertions. | pwsh | None |
| **Package guard** | ✅ Completed | 86 patterns, case-insensitive, guards its own configuration. | Claude Code hooks | `.cargo/config.toml`-class patterns fixed round 4 |
| **Install guard** | ✅ Completed | 56 command patterns; perimeter block on the Bash path. | Claude Code hooks | `G6` (`cp -t`), `G9` (flags before subcommand) |
| **JSON extractor** | ✅ Completed | awk string-aware walk; fails closed; linear time. | awk | `G8` (arrays, duplicate keys) |
| **Guard verifier** | ⚠️ In progress | Executes the *configured* command against sample payloads. | settings.json | `G3` (no perimeter cases), `G4` (twin substitution), `G5` (samples 5/56, 15/86) |
| **Stub ratchet** | ⚠️ In progress | Marker count ratchet with `approved-stub:` exemption. | git, grep | `G1` **(critical, build-red)**, `G2` **(critical)**, `G7`, `G10`, `G11`, `G12` |
| **Exceptions mechanism** | ✅ Completed | Bounded escape hatch; overdue blocks the next PR. 21 assertions. | CI | `G14` (suite tests the awk, not the step dispatch) |
| **Gate pin (`.gate-sha256`)** | ✅ Completed | CI asserts the pin exists, verifies, **and names** its subjects. | CI | `G13` (`check-stubs.ps1`, `gate.ps1` not in `PINNED`) |
| **CODEOWNERS template** | ✅ Completed | Covers gate, pin, ratchet, workflows, `.claude/`, exceptions, `docs/stacks/`. | GitHub | None |
| **Install manifest** | ⚠️ In progress | 23 entries, lists itself, three classes. | SETUP | `G13` (two-repo hardcoding; `process/optional/` single entry) |
| **`<!-- LOCAL -->` preserved region** | 📋 Planned/untested | Upgrade preserves project-specific additions. | manifest | **Never exercised on a real upgrade** |
| **Three-layer model** | ✅ Completed | Enforced by four structural self-tests. | — | None |
| **Tier separation (`core`/`team`/`optional`)** | ✅ Completed | Small install ~7,000 words vs 15,252. | SETUP | None |
| **n-slot stack layout** | ✅ Completed | `docs/stacks/<name>/`, plus `stacks/TEMPLATE/`. | SETUP | None |
| **Behavioural parity harness** | ✅ Completed | 112 guard payloads + 46 stub paths + 13 stub lines, both implementations executed. | pwsh | `G11` (parity ≠ correctness) |
| **Self-test suite** | ⚠️ Red | 4 suites, 90 assertions. | — | `G1` makes it exit 1 |
| **Rule ID scheme** | ⚠️ Partial | 58 IDs defined; a resolver check enforces citations. | — | ~82% of layer-2 bullets still un-IDed |
| **`/framework-upgrade`** | 📋 Planned/untested | Manifest-driven drift detection and file operations. | manifest, tags | **No project has ever upgraded** |

---

# 9. Important Design Decisions

| # | Decision | Rationale |
|---|---|---|
| **D1** | Call it a **framework**, not a library/toolkit/methodology. | Control flow: a library is something *you call*; a framework *calls you*. This defines the workflow and the project fills slots. "Library" implies an importable API that doesn't exist. "Methodology"/"playbook" ignore the shipped enforcement. "Toolkit" loses the mandatory nature. "Template" implies one-time scaffolding, contradicted by VERSION + CHANGELOG + upgrade path. Suggested refinement: *"controlled-delivery framework"*, taken from the README's own first paragraph. |
| **D2** | **Correct the receipt claim rather than add an HMAC.** | Nothing running on the checked machine can stop an agent with shell access. An HMAC raises the bar but the honest fix is to state what the mechanism delivers — *freshness and non-transcription* — and name CI as the binding authority. Overstating the one hard guarantee teaches people to stop checking the others. |
| **D3** | Exclusion boundary is **status vs. requirements**, not paperwork vs. code. | Excluding `tasks.md` (v2.0–2.1) let requirements be rewritten after the gate to match what was built. Splitting status into its own file was the right fix rather than the easy one. |
| **D4** | **Fingerprint via a throwaway `GIT_INDEX_FILE`.** | `--verify` becomes a pure evidence read that never disturbs the developer's staged changes, and the receipt survives the phase commit. |
| **D5** | **Guard breadth over precision** (86 patterns, 56 commands). | "A guard that quietly ignores `go.mod` is worse than no guard, because it reports itself as verified." Guarding ecosystems the project doesn't use costs nothing. |
| **D6** | **Two guards, not one:** file guard on Edit/Write, install guard on Bash. | The file guard alone covers the *least* likely way an agent adds a dependency. |
| **D7** | **Guards guard their own configuration**, with no approval-marker escape. | The marker cannot authorise its own creation. `/framework-doctor` runs after setup and upgrade, never during phase work — so the block must be at the moment of the write. |
| **D8** | **`gate.sh` / `.gate-sha256` deliberately excluded from the guard perimeter.** | They are pinned by CI and owned in CODEOWNERS; blocking them locally would break `chmod +x gate.sh` during setup. *This delegation is only sound while the pin asserts its subject — which is why `N4` mattered.* |
| **D9** | **Bind DoD items 1 and 6 to git/PR objects, not file strings.** | A line of text inside a file is not evidence: a well-formed spec produces exactly the approval line the checklist looks for. |
| **D10** | **Stub ratchet, not a coverage threshold.** | Brownfield repos legitimately start with hundreds of markers; demanding zero would be ignored within a week. Forbid the number *rising*. |
| **D11** | **Exceptions must exist and must cost.** | A process with no escape hatch is not followed under pressure — it is *abandoned* under pressure, and abandonment leaves no record. An overdue exception blocks the *next* PR, charging the debt to whoever moves next. |
| **D12** | **Split `process/` into `core/` / `team/` / `optional/`.** | A Small install previously carried 3,299 words the tier disclaimed, including a file titled MANDATORY that the tier said to skip. |
| **D13** | **n-slot `docs/stacks/<name>/`** replacing fixed backend/frontend slots. | Two fixed slots made a Python CLI, Rust service, iOS app, or three-repo project unrepresentable. |
| **D14** | **Placeholders in the Node gate** (`{{BUILD_COMMAND}}` etc.). | An uncustomised Node gate previously passed `/framework-doctor` while running the framework author's own commands — and the shipped default `yarn check` is a Yarn 1 command that doesn't exist in the Yarn version the file's own corepack note implies. |
| **D15** | **Behavioural parity, not textual parity.** | Comparing pattern *strings* certified agreement that did not exist: `PASS … the same 9 markers` while the two ratchets disagreed 3×. Execute both implementations over a shared fixture and compare verdicts. |
| **D16** | **A check that skips must FAIL in CI.** | `if [ -n "${CI:-}" ]; then bad …` — otherwise the parity guarantee silently rests on `ubuntu-latest` continuing to ship pwsh. |
| **D17** | **Ship the tooling open-source; keep the process internal until it survives an upgrade.** | `tooling/gate/` + `receipt-contract.sh` is a novel five-file project adoptable in an afternoon. The 28,900 words of process are a different product; published now, people hit the friction and leave. |
| **D18** | **Write the fixture row before the fix, not after.** | Every round-3 finding that reopened a round-2 fix would have been caught by one new row in `guard-cases.tsv`. |
| **D19** | **Reports delivered as self-contained HTML**, committed into the repo. | User's explicit preference from round 1 onward. |

---

# 10. Coding Standards

## 10.1 Framework-wide design principles (from `README.md`)

1. **Ship behaviour over prose** — instructions degrade, scripts do not. Prefer a script/hook/command
   over a paragraph.
2. **One source of truth per fact** — never duplicate a rule in two files; link it.
3. **Every check exists because something failed silently once** — and its comment says what.
4. **Task→doc map over "required reading."**

## 10.2 Shell (`.sh`)

- POSIX / `dash`-compatible. No bashisms.
- Dependencies limited to `git`, `awk`, `sed`, `tr`, `grep`.
- `set -f` around any word-split of git pathspecs, so git's matcher does the matching.
- **Always terminate file lists with `--`** before user-controlled paths. *(Violation = finding `G2`.)*
- Prefer `git ls-files -z` + `read -r -d ''` over `for f in $(git ls-files)`.
- One `grep` over a file list, not one fork per file (Windows/MSYS fork cost).
- `wc -l`, not `grep -c ''`, when empty input must yield `0` with exit 0. *(Violation = `G1`.)*
- Name function-local variables distinctly (`_p`, `_b`) — `dash` has no `local`. *(Violation = `G15`.)*
- Fail closed: an unreadable input is a block, never a pass.

## 10.3 PowerShell (`.ps1`)

- **ASCII-only.** PowerShell 5.1 decodes UTF-8-without-BOM as ANSI; one em dash becomes three bytes,
  one of which is a quote, and the script dies. For a hook that means failing **open**.
- CRLF line endings, pinned by `.gitattributes`.
- Reset `$global:LASTEXITCODE = $null` before each native call; a still-null value means the command
  never ran → treat as `127`.
- Use `ConvertFrom-Json`, not regex, for payloads.
- Match `Set-Content` byte output to the `.sh` side when the file is pinned. *(Violation = `G12`.)*

## 10.4 Naming conventions

| Thing | Convention |
|---|---|
| Feature branches | `feat/NNN-<name>`, `fix/NNN-<name>`, `chore/NNN-<name>` |
| Spec directories | `specs/feature/NNN-<name>/` — **canonical, enforced by a self-test** |
| Phase commits | `feat(<feature>): complete phase <N>` |
| Claim commits | `chore(roadmap): claim NNN-<name> (<who>)` |
| Rule IDs | `B<n>` backend architecture · `DB<n>` database · `BP<n>` best practice · `F<n><letter>` frontend. **Stable — reviews cite them; never renumber.** |
| Installed stacks | `docs/stacks/<name>/`, keeping the upstream folder name |
| Fenced code regions | `# JSON-EXTRACT-BEGIN/END`, `# GUARDED-MANIFESTS-BEGIN/END`, `# EXCEPTIONS-AWK-BEGIN/END` — extracted by self-tests |

## 10.5 Process rules

- **One phase at a time.** The AI implements only the current approved phase.
- **Spec-first.** Implementation never starts from an unapproved spec.
- **On any artifact conflict: stop and report — never silently choose.**
- **Never invent a UI layout when screenshots exist.**
- **The gate scripts are the only place gate commands are defined.** Docs point at the scripts and
  never restate the command chains.
- **Upstream-first:** layer 1 and 2 files are never edited in a consuming project; project-specific
  content goes to `docs/project/` or a `<!-- LOCAL -->` region.
- **Do not edit enforcement inside a feature phase.** Changing the gate is its own `chore/` feature.

## 10.6 Self-test authoring rules

- Every check names the failure it prevents in a comment.
- Ratchets (`BASELINE=0`, marker counts, reference counts) encode "this was fixed, never regress."
- No silent skips: log what was dropped, and fail in CI.
- Guard against vacuity: assert the fixture is non-empty; assert an absolute truth, not only parity.

---

# 11. Testing Strategy

## 11.1 Suite layout

`tests/run-all.sh` is the framework's own gate; CI runs this exact script.

| Suite | Assertions | Covers |
|---|---|---|
| `framework-checks.sh` | 34 (33 pass, 1 fail, 1 skip) | Static consistency + behavioural guard/stub parity |
| `exceptions-check.sh` | 21 | The CI exceptions awk program |
| `receipt-contract.sh` | 22 | The receipt contract, both directions |
| `gate-powershell.sh` | 13 | `.ps1` gate behaviour |
| **Total** | **90** | |

## 11.2 Unit testing

Per-function behaviour: `is_source` classification (46 fixture paths), marker/exemption line matching
(13 fixture lines), the JSON extractor (subset of the 112 guard payloads), the exceptions awk
(21 table shapes).

## 11.3 Integration testing

Full gate lifecycle in throwaway repos: fresh green receipt, edited tracked/untracked source,
status-file exclusions, requirement-file inclusions, min-mode rejection, failed-gate rejection,
deleted receipt, lint/test step sequencing, index untouched by `--verify`.

## 11.4 UI testing

**Not applicable** — no UI in the framework. The *process* mandates a human manually running the app
and comparing each affected view against `specs/feature/NNN-<name>/screenshots/`.

## 11.5 Edge cases proven during the evaluation

- Toolchain absent → `127` on both platforms.
- Not a git repo / dubious ownership → `RECEIPT: unverifiable`, no receipt written.
- `git update-index --assume-unchanged` / `--skip-worktree` → correctly `RECEIPT: stale`.
- Merge-conflict index → fingerprint computed normally.
- Directory named after an excluded file → not swallowed.
- Basename near-misses (`docs/notes-package.json`, `vendor/Gemfile/readme.md`) → allowed.
- Path traversal (`src/../package.json`, `C:\proj\package.json`) → blocked.
- Symlinks (file, broken, directory) → both stub implementations agree.
- Leap years, `31 April`, `9999-99-99` → rejected by the exceptions parser.
- BOM, CRLF, non-ASCII UTF-8, 5-level nesting, escaped quotes → extractor handles correctly.

## 11.6 Security testing

Declared in-scope by `SECURITY.md`: receipt forgeability, package guard failing open, and
**"a repository file name … reaching a shell"** — which is exactly the class `G2` falls into.

Attack classes exercised across four rounds: receipt forgery and replay; fingerprint scope
(gitignored files, `.git/info/exclude`, submodules); gate-script tampering; guard self-unlock;
matcher rewiring; verifier substitution; command-injection through JSON payloads; shell-quoting and
option-injection bypasses; CI step evasion; baseline inflation.

## 11.7 Performance testing

Hook latency against payload size — the extractor must stay linear because it runs on every
PreToolUse call. Measured 800 KB: **11.7 s → 0.03 s** after the round-4 fix.

## 11.8 Validation rules

| Input | Rule |
|---|---|
| Receipt `tree` | Must not be `"unknown"` on either side |
| Receipt `mode` | Must be `"full"` |
| Receipt `exit` | Must be `0` |
| Hook payload | Key absent → allow; key present but unreadable → **block** |
| Baseline file | Must contain a bare integer |
| `.gate-sha256` | Must exist, verify, **and name** its subjects |
| Exceptions table | Exactly one deadline column; real calendar dates; row width matches header |
| `approved-stub:` | Non-empty reason required |

---

# 12. Known Issues

## 12.1 Bugs (all open, all reproduced)

| ID | Sev | Bug |
|---|---|---|
| **G1** | **Critical** | `count_stubs()` uses `grep -c '' \|\| echo 0`. `grep -c` prints `0` *and exits 1* on no match, so both fire and the function returns `"0\n0"`. **Makes the framework's own suite red**, corrupts `--baseline` output, and causes `[: Illegal number` (a failed `[` is false, so the ratchet passes inertly). Fires on any zero-stub tree — the state every new adopter starts in. |
| **G2** | **Critical** | A tracked file named `-q` is passed to `grep` as an option (no `--`, no `set -f`). sh count drops to 0 while ps1 reports 1. `-i` re-enables case-insensitive matching; `*.ts` triggers pathname expansion and double-counts. |
| **G3** | High | `verify-guard` reports `GUARD: verified` with the install guard's **entire perimeter block deleted**. CI's "package guards actually block" step runs only `verify-guard`. |
| **G4** | High | On the **shipped default** `settings.json`, Linux/macOS have no `powershell`, so `verify-guard` silently substitutes the `.sh` twin. Both `.ps1` hooks replaced with `exit 0` → still `GUARD: verified`, rc 0. |
| **G5** | High | `verify-guard` samples 5 of 56 install commands and 15 of 86 manifest patterns. Both lists can be gutted ~85% and still verify. In a consuming project this is the *only* mechanical check. |
| **G6** | High | `cp -t .claude/hooks/ src` and `--target-directory=` bypass the perimeter (the branch inspects only the last word). Also `awk -i inplace`. |
| **G7** | Med | Any basename containing `test` is excluded: `git mv src/ledger.ts src/latest-ledger.ts` takes the count 1 → 0 on both sides. |
| **G8** | Med | Array values: sh allows, ps1 blocks. Duplicate keys: sh first-wins, ps1 last-wins — opposite failures. |
| **G9** | Med | `npm --silent install x`, `npm --prefix ./app install x`, `yarn --cwd app add x`, `npm.cmd install x` all pass. |
| **G10** | Med | `src/my file.ts` invisible to sh; `src/café.ts` invisible to **both** (git's `core.quotePath=true`). |
| **G11** | Med | Gut `is_source` in both implementations and (after fixing G1) the suite goes fully green with a ratchet that counts nothing. |
| **G12** | Low | `--baseline` writes `1\n`; `-Baseline` writes `1` — different SHA-256 for the same count, on a **pinned** file. |
| **G13** | Low-Med | Manifest `files[]` hardcodes backend/frontend slots though `repos` is an array; `process/optional/` is one entry for three conditional files; `check-stubs.ps1` and `gate.ps1` are not in `PINNED` though two comments claim they are. |
| **G14** | Low | `exceptions-check.sh` tests the awk only; changing `exit 1` → `exit 0` in the surrounding step leaves all 21 passing. |
| **G15** | Low | `is_source()` clobbers the caller's loop variable, so `--classify` prints the normalised path. |

## 12.2 Limitations (accepted, by design)

- **The receipt is forgeable by hand.** Documented, not fixed. CI is the binding authority.
- **CI runs a script from the PR's head branch** — "not run by the checked party" holds for the
  *execution*, not the *definition*. Mitigated by `.gate-sha256` + CODEOWNERS.
- **Gitignored files are outside the fingerprint** (`.env` can be changed without staling a receipt).
- **A count ratchet permits one-for-one substitution.**
- **"Stop and report" is unfalsifiable** — a silent choice and no conflict are observationally identical.
- **Parity is necessary, not sufficient** (`G11`).

## 12.3 Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **No project has ever upgraded across a version** | Copy-based frameworks die at the first upgrade | Manifest + `<!-- LOCAL -->` shipped but untested — **do a real upgrade** |
| **Never installed by anyone but the author** | Latent onboarding bugs | Two or three real installs by non-authors |
| The suite is red | Contributors learn to ignore it | Fix `G1` today |
| `verify-guard` is a consuming project's only check | A gutted guard reads as healthy | `G3`–`G5` |
| Human attention | 72 checkbox evaluations per Medium frontend phase; ~288 per 4-phase feature | Cut the human template to what no machine can do |
| Rule IDs ~18% complete | Reviews cannot cite consistently | Number the rest or narrow the claim |

## 12.4 Technical debt

- 82% of layer-2 rule bullets carry no ID.
- Duplication ratchets *freeze* rather than reduce (peer-vs-solo in 12 files, tiers in 8).
- `sh` and `ps1` implement every control twice with no shared source.
- `stacks/dotnet-api` splits the `DB` namespace across two files with no principle.
- The example install is a fixture nobody has installed.

## 12.5 Workarounds in effect

- `_snap4.tgz` in the repo root (from the tarball transfer) — **safe to delete**.
- `device_bash` cannot delete files; unwanted files must be `mv`'d to a `_to_delete/` folder.
- pwsh must be added to `PATH` (`/opt/pwsh`) in the sandbox before running the full suite.

---

# 13. Open TODO List

## High priority

| # | Task | Why |
|---|---|---|
| H1 | **Fix `G1`**: `count_stubs() { all_stub_lines \| wc -l \| tr -d ' '; }` | The build is red; `--baseline` writes a corrupt pinned file; every new adopter starts on a zero-stub tree |
| H2 | **Fix `G2`**: `git ls-files -z` + `read -r -d ''` + `grep … --`; `git -c core.quotePath=false` on ps1 | Closes the `-q` attack **and** `G10` in one edit |
| H3 | **Fix `G3`**: add 5 perimeter cases to `verify-guard` | CI certifies a guard with no perimeter |
| H4 | **Fix `G4`**: stop printing `GUARD: verified` when the configured interpreter is absent | This is the shipped default state on macOS/Linux |
| H5 | **Fix `G5`**: assert list sizes, or ship `guard-cases.tsv` alongside the hooks | Consuming projects get only `verify-guard` |
| H6 | **Fix `G6`**: handle `cp -t` / `--target-directory`; drop `awk` from the read allowlist | Confirmed overwrite of a hook |
| H7 | **Upgrade one real project across a version boundary** | Unretired for four rounds; the most likely cause of death |

## Medium priority

| # | Task |
|---|---|
| M1 | `G7` — anchor test-file patterns to `*.test.*`, `*_test.*`, `*[Tt]ests.*`, `*[Ss]pec.*` + directory rules. Add `src/latest-ledger.ts` to `stub-paths.txt` **first** |
| M2 | `G8` — fail closed on non-string values; make both extractors last-wins |
| M3 | `G9` — match tool and subcommand independently, or strip `-`/`--` words before matching |
| M4 | `G11` — add one absolute assertion: a temp repo with a planted count, asserting both return that number |
| M5 | `G13` — per-repo manifest entries keyed off `repos[]`; split `process/optional/` into three; add `gate.ps1` and `check-stubs.ps1` to `PINNED` |
| M6 | `G14` — extend `exceptions-check.sh` to the whole `run:` block and assert step exit status |
| M7 | Two or three real installs by people who are not the author |

## Low priority

| # | Task |
|---|---|
| L1 | `G12` — `Set-Content … "$current`n" -NoNewline` on the ps1 side |
| L2 | `G15` — rename `is_source` locals to `_p` / `_b` |
| L3 | Number the remaining layer-2 rules, **or** narrow the README claim to "the backend rules are numbered" |
| L4 | Reduce the duplication baselines rather than freezing them |
| L5 | Cut the human review template from 18 boxes to ~5; move mechanically-checkable items into the gate |
| L6 | Ship the prototype capture script `docs/prototypes/` promises, or delete the promise |
| L7 | Tag `v2.3.0` — **only after H1–H7** |
| L8 | Delete `_snap4.tgz` from the repo root |

---

# 14. Important Files

## 14.1 Deliverables produced by this engagement

| File (in the repo root) | Purpose |
|---|---|
| `evaluation-2026-07-25.html` | **Round 1.** Design critique + red-team of v2.2.0. 5 Critical, 12 High, 17 Med/Low. Includes a "Corrections" section listing four false findings that did not survive verification. |
| `reevaluation-2026-07-26.html` | **Round 2.** 13/17 closed. 14 new findings (N1–N14). |
| `reevaluation-r3-2026-07-26.html` | **Round 3.** 4/14 closed, 10 untouched. 14 new (R1–R14). |
| `reevaluation-r4-2026-07-26.html` | **Round 4.** All 45 prior findings closed. 15 new (G1–G15). Build red. |
| `_snap4.tgz` | Transfer artifact — **safe to delete** |

## 14.2 Framework files that matter most

| File | Why it matters |
|---|---|
| `tooling/gate/gate-node.sh` | Reference implementation of the receipt. The other three gates must not diverge from its receipt machinery. |
| `tooling/gate/check-stubs.sh` | **Contains both open Criticals.** Fix here first. |
| `tooling/claude/hooks/guard-packages.sh` | 86 patterns + self-perimeter + the shared JSON extractor |
| `tooling/claude/hooks/guard-installs.sh` | 56 commands + Bash-path perimeter |
| `tooling/claude/hooks/verify-guard.sh` | **The only mechanical check a consuming project gets.** Three open Highs. |
| `tooling/ci/gate.yml` | Six CI steps; contains the exceptions awk |
| `tooling/ci/CODEOWNERS` | Enforcement perimeter ownership |
| `tooling/claude/settings.json` | Hook wiring; permissions allowlist |
| `tooling/claude/framework-manifest.template.json` | Makes `/framework-upgrade` mechanical |
| `tests/framework-checks.sh` | ~40 KB, 34 checks. Every check names the failure it prevents. |
| `tests/fixtures/guard-cases.tsv` | 112 rows. **Add a row before each fix.** |
| `tests/fixtures/stub-paths.txt` | 46 paths. Its own instruction: "add the path that disagreed here BEFORE fixing." |
| `process/core/definition-of-done.md` | The six DoD items; items 1 and 6 now bind to git/PR objects |
| `process/core/gate-command.md` | The gate contract |
| `process/core/exceptions.md` | The bounded escape hatch |
| `SECURITY.md` | Threat model. Now accurate on forgeability; still cites three claims `G2`/`G7`/`G10` undercut. |
| `CHANGELOG.md` | ~46 KB. Per-release upgrade tables — load-bearing for `/framework-upgrade`. |

---

# 15. Conversation Knowledge

## 15.1 User preferences (observed and repeated)

1. **Deliverable format: HTML.** Requested mid-round-1 ("could you delivery the evaluation as html
   file") and used for every round since. Self-contained, inline CSS, light/dark aware.
2. **Also commit reports into the repo** via `device_commit_files`. The user reads them from disk.
3. **Declined the persisted-artifact gallery** in round 1. Do not re-offer.
4. **Terse instructions.** Every follow-up was some form of *"could you please re-evaluation, I already
   fix them."* Expect no detail; go and verify.
5. **Wants proof, not opinion.** The value delivered has been reproductions with observed output.
6. **Fixes fast and broadly.** Each round closed most of what was reported, so the next round must
   re-test *everything*, not sample.
7. English is not the user's first language. Keep prose direct; do not mirror the phrasing.

## 15.2 Repeated decisions

- Every round: re-run the *original* reproduction for each prior finding, then adversarially attack
  the new code, then re-verify the subagent's findings before reporting.
- Always report what **held** as well as what broke — an evaluation that finds only faults is not
  credible, and the user has acted on both.
- Always correct false positives explicitly rather than dropping them (round 1 had four).

## 15.3 Business rules learned

- The framework was **extracted from a single .NET + Next.js warehouse-management system**. Residual
  vocabulary (`wms`, `dpointernational`, `featcher`, `purshase`, `poms`, "putaway zones") is ratcheted
  to zero in layers 1–2.
- Rollback rules were originally ERP/finance-specific: transactional records must not be physically
  deleted; permitted corrections are reversal, adjustment, void, cancellation, status change, each
  auditable and scoped per site and legal entity.
- Scope tiers are chosen by **"what does a mistake cost?"**, not team size.
- Solo developers self-approve their own PR — a deliberate, timestamped, out-of-band act.
- Feature numbers are **allocated** on a team, **computed** only when there is one writer.

## 15.4 Configuration values

| Key | Value |
|---|---|
| `VERSION` | `2.3.0` (unreleased) |
| Guard manifest patterns | 86 |
| Install command patterns | 56 |
| Stub markers | 9 |
| Guard fixture rows | 112 |
| Stub path fixture | 46 |
| Stub line fixture | 13 |
| Rule IDs defined | 58 |
| Internal references checked | 299, baseline 0 unresolved |
| Named-product refs in layer 1 | 13 (baselined) |
| Duplication baselines | peer-vs-solo 12 · CI-solo 4 · receipt rationale 2 · tiers 8 |
| Manifest entries | 23 |
| Receipt exclusions | 5 |
| Hook block exit code | `2` |
| Extractor exits | `0` found · `3` key absent · `4` malformed |
| Total assertions | 90 (89 pass, 1 fail) |

## 15.5 Environment information — **read this before pulling files**

> **The `device_stage_files` mount caches.** Re-staging a path that was staged earlier in the session
> returns the **old, read-only** copy while still reporting the new byte count. This silently invalidated
> an entire re-evaluation pass in round 2.
>
> **Always pull a fresh snapshot this way instead:**
> ```
> device_bash: cd /sessions/*/mnt/sdlc-framework &&
>   tar czf /tmp/sN.tgz --exclude=.git --exclude='*.html' --exclude='_snap*.tgz' . 2>/dev/null;
>   cp /tmp/sN.tgz ./_snapN.tgz
> device_stage_files: ["D:\\solutions\\sdlc-framework\\_snapN.tgz"]     # a NEW path, so not cached
> Bash: tar xzf /mnt/user-data/uploads/sdlc-framework/_snapN.tgz -C /tmp/fwN
> ```
> Use a **new** `N` each round. Verify a known file size after extracting.

Other environment facts:

- `tar czf` directly into the mounted folder fails with *"file changed as we read it"* — write to
  `/tmp` first, then `cp`.
- `device_bash` **cannot delete**; `mv` to `_to_delete/` and tell the user.
- pwsh: `export PATH=$PATH:/opt/pwsh` before running the full suite, or PowerShell checks skip.
- `/tmp/fwN` has no `.git`, so `check-stubs` (which uses `git ls-files`) sees nothing. `git init` +
  `git config --global --add safe.directory /tmp/fwN` + `git add -A` before testing it.
- `verify-guard.sh` parses `settings.json` **line-wise** — a single-line JSON test fixture produces a
  spurious `GUARD: BROKEN`. Use the shipped multi-line file with the hook commands swapped.
- `device_list_dir --recursive` on this repo exceeds the token cap; parse the saved JSON with python.

## 15.6 Assumptions carried by this document

- The four HTML reports remain in the repo root and are readable.
- The user continues to fix findings between rounds and to ask for re-evaluation with no detail.
- The framework remains unreleased until the red build and the two Criticals are resolved.

---

# 16. Timeline

| # | Milestone | Outcome |
|---|---|---|
| 1 | **Naming question** — "is it framework or library?" | **Framework**, on the control-flow argument. Suggested refinement: *controlled-delivery framework*. |
| 2 | **Scope agreed** via AskUserQuestion | Design critique + adversarial red-team; Markdown report |
| 3 | Round 1 executed on **v2.2.0** | Three parallel agents; all findings re-verified |
| 4 | **Deliverable changed to HTML** mid-round by the user | All subsequent reports are HTML |
| 5 | **Round 1 delivered** | 5 Critical, 12 High, 17 Med/Low. Receipt forged in 5 git commands. Four false findings corrected in a "Corrections" section. |
| 6 | Artifact-gallery save **declined** | Reports committed to the repo instead |
| 7 | **Round 2 requested** | Stale mount discovered mid-pass; that pass discarded and redone via tarball |
| 8 | **Round 2 delivered** — v2.3.0 | 13/17 closed. `SECURITY.md` forgeability correction singled out as the best change. 14 new findings. |
| 9 | **Round 3 requested** | |
| 10 | **Round 3 delivered** | Behavioural guard parity landed (top recommendation). 4/14 closed, 10 untouched, 14 new. Pattern named: *fixed at the reported layer, reopened one layer down*. |
| 11 | **Round 4 requested** | |
| 12 | **Round 4 delivered** | **All 45 prior findings closed.** Build red on `G1`. 15 new findings; 2 Critical. |
| 13 | **Handover requested** | This document |

### Findings ledger

| Round | Raised | Status |
|---|---|---|
| 1 | 17 Critical/High (+17 Med/Low) | ✅ All resolved |
| 2 | 14 (N1–N14) | ✅ All resolved |
| 3 | 14 (R1–R14) | ✅ All resolved |
| 4 | 15 (G1–G15) | ⬜ **All open** |

---

# 17. Next Steps

**Do this, in order.**

1. **Pull a fresh snapshot** using the tarball method in §15.5. Do not trust `device_stage_files` on
   a previously staged path.
2. **Reproduce the red build first.** In the extracted tree: `git init`, add the safe.directory
   config, `git add -A && git commit`, then `export PATH=$PATH:/opt/pwsh && sh tests/run-all.sh`.
   Expect `FAIL the two stub ratchets disagree on this tree: sh=0` and `EXIT: 1`. If it is now green,
   `G1` was fixed — confirm with `sh tooling/gate/check-stubs.sh --count` on a zero-stub repo, which
   must print exactly one line.
3. **Re-run every G-finding** with the reproduction recorded in §12.1. Do not sample; the user fixes
   broadly and past rounds closed most of what was reported.
4. **Adversarially attack whatever changed.** Diff against the previous snapshot to scope it. The
   recurring failure mode is *fixed at the reported layer, reopened one layer down* — so for each fix,
   ask what sits immediately beneath it.
5. **Check for vacuous new checks.** For every added assertion: can it pass while testing nothing?
   Empty fixture, baseline permitting the status quo, a grep that cannot match, parity without an
   absolute truth.
6. **Produce a round-5 HTML report** in the same structure: scorecard → per-finding verdicts on the
   prior round → new findings with observed output → what held → prioritised next steps. Deliver with
   `SendUserFile` **and** `device_commit_files` to `D:\solutions\sdlc-framework\reevaluation-r5-<date>.html`.
7. **Keep pressing on the upgrade.** If the user asks what else to do and the criticals are closed,
   the honest answer is unchanged: *upgrade one real project across a version boundary.*

---

# 18. Instructions for the Next AI

## 18.1 How this project is organised

You are the **evaluator**, not the author. The user owns `sdlc-framework`; you assess it, prove
findings by execution, and hand back minimal fixes. You have never had write access to the framework
source and should not take it — your deliverable is a report, committed alongside the code.

The loop is: *user says "I fixed them" → you pull a snapshot → re-run every prior reproduction →
attack whatever changed → report.*

## 18.2 What must never be changed

- **Do not edit the framework source.** Propose diffs in the report.
- **Do not "correct" the `RECEIPT_EXCLUDES` pathspecs.** `*` crosses `/` by design (§6.3).
- **Do not remove the throwaway `GIT_INDEX_FILE`.** It is what makes `--verify` a pure read.
- **Do not weaken the status-vs-requirements exclusion boundary.**
- **Do not re-report the receipt as forgeable.** It is documented as such by design; `SECURITY.md`
  states it plainly. Reporting it again wastes the user's attention.
- **Do not re-offer the artifact gallery.** It was declined.
- **Do not switch the deliverable away from HTML.**

## 18.3 Critical assumptions

1. The adversary is the AI agent itself — a party with commit access on the checked machine.
   "A determined developer could bypass it" is never a valid dismissal.
2. Every control ships twice (`.sh` + `.ps1`) and both must agree. Most defects live in the twin that
   was not brought along.
3. A hook exit code other than `0` or `2` is an **error**, and Claude Code fails **open**.
4. `verify-guard` is the only mechanical check a *consuming* project gets. The 112-row fixture lives
   in the framework repo, not theirs.
5. macOS filesystems are case-insensitive; Windows is the author's primary platform.

## 18.4 Current priorities

1. `G1` (red build) and `G2` (filename attack) — both in `check-stubs.sh`.
2. `G3`–`G6` — the `verify-guard` cluster and `cp -t`.
3. A real upgrade across a version boundary.

## 18.5 Recommended workflow

```
1. TaskCreate: snapshot → re-run prior findings → attack new code → report
2. device_bash tarball  →  stage the NEW .tgz path  →  extract to /tmp/fwN
3. diff -rq /tmp/fw<prev> /tmp/fwN   → scope what changed
4. git init + safe.directory + commit; export PATH=$PATH:/opt/pwsh
5. sh tests/run-all.sh                → record pass/fail per suite
6. Re-run EVERY prior reproduction    → verdict per finding
7. Spawn ONE opus subagent to attack the changed files; tell it explicitly
   what you have already confirmed so it does not re-report it
8. Re-verify the subagent's findings yourself before including any of them
9. Write the HTML report; SendUserFile; device_commit_files
10. Leave the snapshot tarball noted as safe to delete
```

## 18.6 Common pitfalls

| Pitfall | Avoid it by |
|---|---|
| **Stale staging mount** | Always tarball to a new filename (§15.5). This invalidated a whole pass. |
| **Reporting a subagent's finding unverified** | Re-run it yourself. Round 3 had a claim about parenthesised subshells that did not reproduce; round 4 had a `verify-guard` result that was an artifact of a single-line test fixture. |
| **Incomplete staging → false "missing file" findings** | Round 1 wrongly reported `LICENSE`, `.github/workflows/selftest.yml`, issue templates, git tags and the example `.gitignore` as absent. All existed. **List the repo before claiming anything is missing.** |
| **Testing `check-stubs` without a git repo** | It uses `git ls-files`; no repo means zero files and a meaningless result. |
| **Single-line JSON fixtures** | `verify-guard.sh` parses line-wise. |
| **Forgetting pwsh on PATH** | PowerShell checks skip and you will miss parity failures. |
| **Sampling instead of re-testing everything** | The user fixes broadly; round 4 closed all 45 prior findings at once. |
| **Only reporting faults** | The user has acted on "where it held" as much as on the bugs. Include it. |
| **Padding with theoretical issues** | A short list of proven findings beats a long list of maybes. Every finding needs a command and its observed output. |

---

# Project Memory

*Essential long-term context. ~1,150 words.*

## What this is

`sdlc-framework` (`D:\solutions\sdlc-framework`, VERSION `2.3.0`, unreleased) is a Claude-Code-first
framework the user authored that governs building software with an AI assistant: spec → plan → tasks
→ one phase at a time → user-run gate proven by a receipt → AI review → human review → merge. It ships
process documents (layer 1), stack rule sets (layer 2), empty project-knowledge skeletons (layer 3),
plus behaviour: gate scripts, PreToolUse hooks, a stub ratchet, CI workflow, CODEOWNERS, an install
manifest, and a 90-assertion self-test suite. Everything ships twice — `.sh` and `.ps1`.

**My role is evaluator, not author.** I do not edit the framework. I pull a snapshot, prove findings
by execution, and deliver an HTML report that is also committed into the repo.

## Where things stand

Four rounds done. **All 45 findings from rounds 1–3 are resolved and verified.** Round 4 raised 15
findings, all open: 2 Critical, 4 High, 6 Medium, 3 Low.

**The build is red.** `sh tests/run-all.sh` → `EXIT: 1`, 89 pass / 1 fail. Cause is `G1`:

```sh
count_stubs() { all_stub_lines | grep -c '' 2>/dev/null || echo 0; }   # returns "0\n0"
```

`grep -c` prints `0` *and exits 1* on no match, so `|| echo 0` fires too. Fires on any zero-stub tree
— the state every new adopter starts in. Fix: `wc -l | tr -d ' '`.

`G2` is the other Critical: a tracked file named `-q` reaches `grep` as an option (no `--`, no
`set -f`), zeroing the ratchet on the shell side only. `git ls-files -z` + `read -r -d ''` + `--`
fixes it and the space/non-ASCII path gaps together.

Then the `verify-guard` cluster (`G3`–`G5`): it reports `GUARD: verified` with the install guard's
entire perimeter block deleted; on the **shipped default** settings it silently tests the `.sh` twin
because Linux/macOS have no `powershell`, so neutered `.ps1` hooks still certify; and it samples only
5 of 56 install commands and 15 of 86 manifest patterns, so both lists can be gutted ~85%. This
matters more than it looks: `verify-guard` is the *only* mechanical check a consuming project gets.
`G6` is `cp -t .claude/hooks/ src` bypassing the perimeter.

## Design decisions that must survive

- **It is a framework**, not a library — it calls you, you don't call it.
- **The receipt is forgeable by hand and that is documented, not fixed.** Nothing on the checked
  machine can stop an agent with shell access; `SECURITY.md` now says so plainly and names CI as the
  binding authority. **Never re-report this.**
- The fingerprint excludes **status only, never requirements** — `tasks.md`, `spec.md`, `plan.md`,
  roadmap definitions and `contracts/` are always in.
- `RECEIPT_EXCLUDES` are git pathspecs where `*` crosses `/`. **Do not "correct" them.**
- The throwaway `GIT_INDEX_FILE` makes `--verify` a pure read. Do not remove it.
- Guard breadth beats precision: a guard that quietly ignores `go.mod` is worse than none.
- Exceptions must exist and must cost — an overdue one blocks the *next* PR.
- **Behavioural parity, not textual.** Comparing pattern strings certified agreement that did not
  exist. But parity is necessary, not sufficient (`G11`).
- **Write the fixture row before the fix.**

## How to work

The loop: user says *"I already fix them"* with no detail → pull a snapshot → re-run **every** prior
reproduction (do not sample; they fix broadly) → attack whatever changed → report.

**Pull snapshots via tarball, never by re-staging a known path** — the staging mount returns cached
read-only copies while reporting the new byte count. This invalidated an entire pass:

```
device_bash: cd /sessions/*/mnt/sdlc-framework &&
  tar czf /tmp/sN.tgz --exclude=.git --exclude='*.html' --exclude='_snap*.tgz' . 2>/dev/null;
  cp /tmp/sN.tgz ./_snapN.tgz
stage the NEW path → tar xzf … -C /tmp/fwN
```

Then `git init` + `git config --global --add safe.directory /tmp/fwN` + `git add -A && commit`
(check-stubs needs a repo), and `export PATH=$PATH:/opt/pwsh` (or PowerShell checks skip silently).
`verify-guard.sh` parses `settings.json` line-wise, so never test it with single-line JSON.

Use one opus subagent per round to attack the changed files, tell it explicitly what you have already
confirmed so it does not re-report it, and **re-verify its findings yourself** before including any.
Two subagent claims across four rounds did not reproduce.

## User preferences

Deliverables are **self-contained HTML**, sent with `SendUserFile` *and* committed to the repo root as
`reevaluation-rN-<date>.html`. The artifact gallery was declined — do not re-offer. Instructions are
terse; expect no detail. The user wants reproductions with observed output, not opinion. Always
include what **held** — they have acted on that as much as on the bugs. Correct false positives
explicitly rather than dropping them.

## The unretired risk

Four reports have closed with the same line: **no project has ever installed this framework other
than its author, and none has ever upgraded across a version.** The install manifest, the
`<!-- LOCAL -->` preserved-region convention and `/framework-upgrade` are all designed and all
untested against reality. Copy-based frameworks die at the first upgrade. Once `G1` and `G2` are
closed, that is the highest-value thing the user can do — higher than any remaining finding.

## Immediate next actions

1. Fix `G1` (one line) — the build is red and `--baseline` writes a corrupt pinned file.
2. Fix `G2` in the same edit (`git ls-files -z`, `--`).
3. Fix the `verify-guard` cluster `G3`–`G5` and `cp -t` (`G6`).
4. Then `G7`–`G15` per §13.
5. Do not tag `v2.3.0` until the build is green and the criticals are closed.
