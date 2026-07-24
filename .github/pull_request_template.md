<!-- This framework requires evidence, not assertions, from the projects that use
     it. The same applies to changes to the framework itself. -->

## What changes, and what failure does it prevent?

<!-- One paragraph. If the answer is "it makes the docs clearer", say that plainly —
     clarity fixes are welcome and do not need to pretend to be more. -->

## Downstream impact

- [ ] **Nothing to re-copy** — this touches only repo-internal files (tests, CI,
      CONTRIBUTING, README).
- [ ] **Projects must re-copy files** — listed below, and recorded in the
      `CHANGELOG.md` entry:

<!-- e.g. process/definition-of-done.md → docs/process/ -->

## Checklist

- [ ] `sh tests/run-all.sh` (or `.\tests\run-all.ps1`) prints `EXIT: 0`.
- [ ] **Layer discipline** — no product, domain, or system name added to
      `process/`, `stacks/`, or `modules/`.
- [ ] **One source of truth** — no rule restated in a second file; cross-references
      link instead of duplicating.
- [ ] Behavior changes are covered by a test in `tests/`.
- [ ] `VERSION` bumped and `CHANGELOG.md` updated, if this is a releasable change.
      A new version heading stays marked `(unreleased)` until its tag is pushed.

## Self-test output

```text
[paste the EXIT: line and any FAIL lines]
```
