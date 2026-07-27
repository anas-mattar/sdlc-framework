# AI Orchestration (OPTIONAL — governance, not a recommendation)

**The default is a single AI session. The framework never requires
orchestration**, and most phases never benefit from it. This file exists because
users of AI tooling will eventually run multiple agents (subagents, background
agents, parallel sessions) — and improvised orchestration is precisely what
breaks the framework's guarantees. If you orchestrate, these are the boundaries.

> The framework doesn't tell you to orchestrate — it tells you what
> orchestration is allowed to mean here.

## The Principle: Orchestrate Inside the Boundaries, Never Across Them

The framework's unit of control is the **phase with a human gate**.
Orchestration multiplies what happens *within* a controlled boundary; it must
never dissolve the boundary.

## Hard Rules (non-negotiable whenever agents are multiplied)

1. **No agent chain crosses a gate.** Fan out freely inside a phase; the gate is
   a hard synchronization point where everything stops for the human. An
   orchestrator that starts phase N+1 while phase N is ungated has deleted the
   framework's central control.
2. **Human gates are not delegable.** Agents may run builds and checks at will,
   but only a valid receipt from the **user's** gate run plus human approval
   satisfy the Definition of Done. An agent may run `--verify` (it reads
   evidence, it does not produce it); an agent running the gate itself proves
   nothing. An agent confirming another agent's work is AI review — never human
   review.
3. **One writer, many readers.** Any number of agents may read (research,
   explore, verify) concurrently; exactly **one** agent writes to a given repo
   within a phase. Parallel writers in one feature shred the `git diff --stat`
   scope guard. Parallel *writing* happens at the **feature** level through the
   existing machinery: claims are the scheduler, worktrees are the isolation
   (`docs/process/team-workflow.md`).
4. **Output lands in artifacts, not chat.** Research fan-out writes into
   `research.md`; review fan-out into the feature's `ai-code-review.md`.
   Orchestrated work must leave the same reviewable trail as solo work.

## Sanctioned Patterns by Stage

| Stage | Pattern | Why it's safe/valuable |
|---|---|---|
| Research / spec | **Fan-out → synthesize**: parallel readers over business docs, prototype, existing code; one synthesis into `spec.md` | Read-only — parallelism is free; specs need wide coverage |
| Planning | **Judge panel**: 2–3 independent plan drafts from different angles, scored; best synthesized into `plan.md` | Wide solution spaces reward independent attempts; human approval still follows |
| Implementation | **Single writer** per repo per phase; orchestrator may fan out read-only helpers ("find all callers", "how is X done elsewhere") | Keeps the diff attributable to one intent |
| AI review | **Fan-out by dimension → adversarial verify**: parallel reviewers (stack compliance, security, DB rules, spec/screenshot match), then skeptics that try to *refute* each finding | Deepens `/phase-review` at zero extra human cost — the human sees only verified findings |
| Cross-feature parallelism | **Claims + worktrees** — each feature is one human-owned lane | Already in the framework; orchestration never merges lanes |
| Mechanical sweeps (migrations, renames) | **Pipeline**: discover → transform in isolation → verify each; the whole sweep is still **one phase, one gate** | Scale without losing the single sign-off |

## Rejected Patterns

- **Autonomous multi-phase pipelines** ("agent A specs, agent B implements all
  phases, agent C approves") — optimizes away exactly what the framework
  guarantees. Speed comes from parallelism *within* phases and features, never
  from removing gates.
- **Agent-to-agent approval as review.** "The agents reviewed each other" never
  satisfies human review.
- **Orchestration as default.** Reach for fan-out when the work is genuinely
  wide (research, review, sweeps) — not because it's available.

One line to remember:

> **Parallelize reading and judging freely; serialize writing and approving
> always.**
