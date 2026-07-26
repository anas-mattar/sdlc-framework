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
  `.claude/hooks/guard-packages.*` or `.claude/hooks/guard-installs.*` permit an
  unapproved dependency change while appearing to be active. Claude Code treats an
  unrunnable hook as an error rather than a block, so anything that silently breaks
  a hook is a real bypass. This is why `verify-guard.*` exists, why CI runs it, and
  why `/framework-doctor` checks it. Both hooks are in scope: the file guard sees
  `Edit`/`Write` against manifests, the install guard sees the `Bash` commands
  (`npm i`, `dotnet add package`, `pip install`, `go get`) that rewrite the same
  files without an editor ever touching them.
- The **guards' own perimeter opening**: a way to write `.claude/settings.json`,
  `.claude/hooks/` or `.claude/allow-package-changes` from a tool call, which
  disables the guards for good in a single step. Both guards block writes to those
  paths; a command that gets a write past that block is a report worth making.
- **A control that can be weakened without the change being visible.** The
  framework's answer to "everything the gate rests on lives inside the perimeter
  the checked party controls" is not prevention — nothing in-repo can prevent it —
  it is that a weakening must be *impossible to land silently*. Three mechanisms
  carry that, and a defect in any of them is in scope:
  `.gate-sha256` (pins `gate.sh`, `check-stubs.sh` and `.gate-stubs-baseline`, and
  the CI step asserts the pin names them rather than verifying whatever list it
  happens to contain), `CODEOWNERS` (makes editing those files, the workflow, the
  hook configuration and `docs/exceptions.md` require a named human), and the
  `check-stubs` ratchet (stops unimplemented code from growing).
- **The exception mechanism becoming permanent silently**: any way for a row in
  `docs/exceptions.md` to outlive its *Remediate by* date without CI failing — a
  header the check does not bind to, a row it skips, a date it accepts that is not
  a date. Every past defect in that check made it pass rather than fail, which is
  the property that makes this class worth reporting.
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
  (`process/team/team-workflow.md` §2a). This is a documented, deliberate trade-off
  limited to a single roadmap line; if your organization forbids it, use the
  tracker-ID scheme instead.
- A developer choosing not to run the gate. The framework's answer to that is CI
  (`tooling/ci/gate.yml`), which is a backstop, not a guarantee.

## A note on trust

The receipt mechanism and the package guards defend against **mistakes and
overconfident automation** — an AI claiming a build passed, a dependency added
without approval. They are not designed to withstand a developer with commit
access who is deliberately trying to defeat them. Nothing that runs on the
machine being checked can do that.

CI on a clean checkout is the only check the checked party does not **execute**,
which is why the framework requires it even on solo projects. It is not the only
one they do not **control**, and saying so was misleading: CI runs `gate.sh`,
`check-stubs.sh` and the workflow file itself from the pull request's own head
branch, all three of which the author can edit in the same PR as the work they
would excuse. What closes that is not the execution environment but the
*visibility* of the change — `.gate-sha256` turns a weakened gate into a one-line
diff nobody can miss, and `CODEOWNERS` turns that diff into a named human's
approval, out of band. Both are in `tooling/ci/`, both are installed by SETUP, and
neither works unless branch protection is on and "Require review from Code Owners"
is ticked. An unenforced check is decoration; that is the honest boundary.
