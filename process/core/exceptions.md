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

`tooling/ci/gate.yml` ships the check. It reads `docs/exceptions.md`, ignores
struck-through rows, and fails when any remaining row's *Remediate by* date is in
the past.

## What an exception never covers

- Committing the package-guard override (`.claude/allow-package-changes`).
- Weakening `gate.sh`, the CI workflow, or `CODEOWNERS` to make a check pass.
- Skipping human review on a change that touches money, permissions, or data
  migration. If it is important enough to rush, it is important enough to look at.

If the thing you need is on this list, you do not need an exception. You need to
stop and report.
