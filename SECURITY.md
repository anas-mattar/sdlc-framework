# Security Policy

## What this project is

The framework ships documentation plus a small amount of executable tooling:
gate scripts, Claude Code hooks (including the package guard), a CI workflow, and
a permissions template. It has no runtime, no network access, and no dependencies.
The security surface is therefore narrow but not empty — the tooling runs on
developer machines and in CI with repository write access.

## Supported versions

Security fixes land on the latest minor release only. There are no long-term
support branches while the project is in beta (see the version policy in
`README.md`).

| Version | Supported |
|---|---|
| 2.x | Yes |
| 1.x | No — upgrade via `/framework-upgrade` |

## Reporting a vulnerability

**Do not open a public issue.** Report privately via GitHub's
[private vulnerability reporting](https://docs.github.com/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository (Security → Report a vulnerability).

Please include what the issue is, how to reproduce it, and which files or
commands are involved. You will get an acknowledgement within 7 days and an
assessment within 30. This is a small project maintained alongside other work —
that is the honest response time, not a target it will beat.

## What counts as a vulnerability here

In scope:

- A gate script, hook, or CI workflow that can be made to execute attacker-supplied
  content — for example a repository file name or branch name reaching a shell.
- The **package guard failing open**: any way to make
  `.claude/hooks/guard-packages.*` permit an unapproved dependency change while
  appearing to be active. Claude Code treats an unrunnable hook as an error rather
  than a block, so anything that silently breaks the hook is a real bypass. This is
  why `verify-guard.*` exists and why `/framework-doctor` checks it.
- The **gate receipt failing open**: any way to make `--verify` report
  `RECEIPT: valid` for a tree the gate did not actually pass — a stale receipt
  accepted as fresh, an unfingerprintable tree treated as a match, a step whose
  failure is swallowed, or a receipt written when no step ran. These are the
  bugs that matter, because they defeat Definition of Done item 3 without anyone
  intending to.

  The receipt is **not** claimed to be unforgeable by hand. The fingerprint is a
  plain `git write-tree` over a documented exclusion list, computed on the
  developer's own machine — anyone who can run `git` can reproduce one, and the
  agent is a party with commit access running on that machine. Reports of the
  form "I wrote a receipt by hand" describe the design, not a vulnerability. What
  makes the gate binding is CI, which runs the check the author does not.
- The shipped `.claude/settings.json` permission allowlist granting materially more
  than it appears to.

Out of scope:

- Vulnerabilities in a *consuming* project's own code. The framework does not
  review your dependencies.
- The claim-commit exemption allowing direct pushes to `main`
  (`process/team-workflow.md` §2a). This is a documented, deliberate trade-off
  limited to a single roadmap line; if your organization forbids it, use the
  tracker-ID scheme instead.
- A developer choosing not to run the gate. The framework's answer to that is CI
  (`tooling/ci/gate.yml`), which is a backstop, not a guarantee.

## A note on trust

The receipt mechanism and the package guard defend against **mistakes and
overconfident automation** — an AI claiming a build passed, a dependency added
without approval. They are not designed to withstand a developer with commit
access who is deliberately trying to defeat them. Nothing that runs on the
machine being checked can do that. CI on a clean checkout is the only check the
checked party does not control, which is why the framework requires it even on
solo projects.
