# Exceptions

The Definition of Done has no waiver. That is correct as a default and wrong as an
absolute, because the alternative to a bounded exception is not compliance — it is
**silent abandonment**. Under a real deadline, with a production incident open, a
process with no escape hatch does not get followed more carefully. It gets dropped,
by one person, at 11pm, and it leaves no artifact saying so. Six weeks later nobody
can tell which phases were gated and which were not.

An exception makes that moment **recorded instead of invisible**. It is not
permission to skip the process; it is the process for skipping the process.

## When an exception is legitimate

Only when all three hold:

1. **Time-critical and externally forced** — a production incident, a security
   patch, a contractual deadline that moved. "We are behind" is not an exception,
   it is a plan problem.
2. **A named human decides** — never the AI, and never the person under the
   deadline acting alone if anyone else is available.
3. **The unmet items are known and few.** If you cannot list which Definition of
   Done items are unmet, you do not need an exception — you need to find out.

An exception is never available for item 3 (the gate) on a change that ships to
users. A build you have not run is not a risk you have accepted; it is a risk you
have not measured.

## How to record one

Append a row to `docs/exceptions.md` in the project, in the same commit as the work
it covers. Never retroactively.

```markdown
| Date | Feature / phase | DoD items unmet | Why | Authorised by | Remediate by |
|---|---|---|---|---|---|
| 2026-03-04 | 014-payment-retry ph2 | 5, 6 | Prod incident: retries dropping. Fix verified manually against staging. | A. Nkemi | 2026-03-11 |
```

Every column is required, and every one is doing work:

- **DoD items unmet** — by number. "Some of the review" is not a row.
- **Why** — the external forcing function, in one sentence. If it does not name
  something outside the team, it is not an exception.
- **Authorised by** — a person's name, not a role and not "the team".
- **Remediate by** — a date, not "soon". This is the column the whole mechanism
  rests on.

## The cost that makes it work

**CI fails every subsequent pull request while an open exception is past its
remediation date.** Not the PR that opened the exception — the next one, and the
one after, until the row is closed.

An exception path with no cost is just the process, and it will be used for
convenience within a month. An exception that blocks the *next* piece of work is
one a team actually pays down, because the debt is charged to whoever tries to
move next rather than to whoever incurred it. That is deliberate: it makes the
whole team's throughput depend on closing it, which is the only pressure that
reliably beats the pressure that created it.

Close a row by striking it through and adding the commit that remediated it:

```markdown
| ~~2026-03-04~~ | ~~014-payment-retry ph2~~ | ~~5, 6~~ | ~~Prod incident~~ | ~~A. Nkemi~~ | **closed 2026-03-09, a1b2c3d** |
```

`tooling/ci/gate.yml` ships the check. It reads `docs/exceptions.md`, ignores rows
whose first cell is struck through, and fails when any remaining row's *Remediate
by* date is in the past. Six details are worth knowing before you edit the table,
and they have one thing in common: **anything this check cannot read, it fails on.**
A row it skipped would be an exception with no deadline, which is the outcome the
whole mechanism exists to prevent.

- It finds the deadline by the **column header**, not by position, so you can add
  or reorder columns. The header must be exactly *Remediate by* or *Due by*
  (spacing, case and punctuation are ignored; nothing else matches). A column
  called *Remediation notes* is not the deadline column and will not be mistaken
  for one. A table with no such header fails the build rather than passing
  silently — a check that cannot find its input is not a passing check.
- **One deadline column per table.** Two of them fail the build rather than the
  check guessing which is binding.
- The header is the **first row of its table**, and each table is read on its own.
  A second table with different columns is fine. A header written below its own
  data rows is not.
- **Every row must be the same width as its header.** A missing cell, or a stray
  `|` inside a *Why* cell, moves the deadline into a different column — so it
  fails rather than being skipped. If a cell needs a pipe, escape it as `\|`.
- The date must be a **real calendar date**: `2026-13-45`, `9999-99-99` and
  `2026-02-29` all fail. They used to be accepted and compared as text, which
  turned a typo into an exception that never came due.
- Only the **first cell** decides whether a row is closed. Strike the whole row
  through by all means, but `~~` elsewhere in an open row does not close it.
- **Deleting the file fails the build** once it has ever existed. Close rows by
  striking them through; the history of what was accepted, by whom, is the record.
  A file with **no table at all** is fine — if you close the last exception by
  removing its rows and leaving a sentence saying so, the check passes.

## What an exception never covers

- Committing the package-guard override (`.claude/allow-package-changes`).
- Weakening `gate.sh`, the CI workflow, or `CODEOWNERS` to make a check pass.
- Skipping human review on a change that touches money, permissions, or data
  migration. If it is important enough to rush, it is important enough to look at.

If the thing you need is on this list, you do not need an exception. You need to
stop and report.
