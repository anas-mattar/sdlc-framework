# Rollback Process

Prefer `git revert`.

## Rollback Checklist

- Can this phase be reverted by commit?
- Did it change database schema?
- Is schema change additive or destructive?
- Are data migrations reversible?
- Are deployment rollback steps documented?

## Database

Do not drop tables/columns without explicit approval.

## Transactional Data

Transactional business records MUST NOT be physically deleted to roll back a change.

- Never `DELETE` or `DROP` posted transactional records as a rollback mechanism.

  > Examples: posted ledger entries, completed movements or shipments, finalized
  > adjustments — anything a downstream system or audit trail has already
  > consumed. List this project's cases in `docs/project/domain-rules.md`.

- Finalized records are append-only. Correct them with a **reversal or adjustment**;
  do not edit or delete the original.
- Permitted corrections: **reversal, adjustment, void, cancellation, or status
  change** — each itself auditable and correctly scoped (e.g. per site and legal
  entity, where the domain requires it).
- Reverting code or a migration MUST NOT cascade into physical deletion of
  transactional records. If a rollback would require touching posted transactional
  data, **stop and report**; resolve it through a correcting entry, not a delete.
- A rollback that cannot preserve transactional-data immutability is not approved.
