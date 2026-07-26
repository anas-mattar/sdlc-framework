# Review Process

## After Each Phase

1. User runs the gate script (`docs/process/gate-command.md`).
2. User checks:

```bash
git diff --stat
```

3. Fix only current phase issues.
4. Revert unrelated changes.
5. Commit successful phase.
6. Do not start next phase without approval.

## AI Review

Check:
- Spec match
- Screenshot match
- Backend rules
- Frontend rules
- Security
- Tests
- Migrations
- Unrelated changes
- Rollback safety

## Human Review

AI review alone is insufficient. **Human review is required before merge**, and a
change MUST NOT be merged until a human approves it
(`docs/process/definition-of-done.md` item 6). On a team that human is a peer other
than the feature's owner; solo, it is the developer's own acceptance review — but
it is never the AI, and never skipped.

Human reviewer checks:
- Actual UI vs screenshots
- Business behavior
- Financial / domain correctness
- Security implications
- Architectural compliance
- Code diff
- Gate result
- No unrelated changes

## Merge

Merge only after the human reviewer approves. See the consolidated gates in
`docs/process/definition-of-done.md`.
