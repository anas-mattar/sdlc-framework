# Rollback Process

Prefer `git revert`.

## Rollback Checklist

- Can this phase be reverted by commit?
- Did it change persistent schema?
- Is the schema change additive or destructive?
- Are data migrations reversible?
- Are deployment rollback steps documented?

## Schema

Do not drop tables, columns, or their equivalent without explicit approval.
Additive changes are revertible; destructive ones are not, whatever the migration
tool claims.

## Irreversible Records

**Some records cannot be un-made.** Once a record has been observed by something
outside this system — a downstream service, an audit trail, a regulator, a
customer — deleting it does not undo the event, it only removes the evidence.

The rule:

- **Never delete an irreversible record as a rollback mechanism.** Correct it with
  a **reversal, adjustment, void, cancellation, or status change** — each itself
  auditable, and scoped the way the domain requires.
- Reverting code or a migration MUST NOT cascade into physical deletion of such
  records. If a rollback would require touching them, **stop and report**; resolve
  it with a correcting entry.
- A rollback that cannot preserve their immutability is not approved.

**Which records these are is a layer-3 fact, and this document does not know it.**
It varies completely by domain: posted ledger entries and completed shipments in
one system; sent messages, issued credentials, published versions, or dispatched
webhooks in another; nothing at all in a compiler or a static site. A project that
has none can mark this section N/A and move on.

> **List this project's irreversible records in `docs/project/domain-rules.md`** —
> what they are, what "posted"/"finalized"/"issued" means for each, and which
> correction is permitted. Until that list exists, the AI must treat any record a
> downstream system has consumed as irreversible and stop and report.

This section used to be written entirely in one domain's vocabulary — ledger
entries, movements, per-legal-entity scoping — inside a layer-1 document delivered
unchanged to every project. Half of a mandatory checklist reading as inapplicable
teaches people to skim the half that isn't.
