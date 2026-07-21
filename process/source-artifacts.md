# Source Artifacts — Guides, Prototypes, Roadmaps

Business source artifacts are the inputs that specs are **derived from**. They are
always project-specific content (layer 3), but the rules in this file about how
they are used are framework process (layer 1).

## One Dimension of Authority Each

Each artifact type is the source of truth for exactly one question. They do not
compete with each other:

| Artifact | Location | Is the truth for… | Never the truth for… |
|---|---|---|---|
| **Roadmap** | `docs/roadmap/` | scope, sequencing, delivery status | behavior or layout |
| **Guide / manual / requirement doc** | `docs/business/` | business behavior and rules | layout or delivery order |
| **HTML prototype → feature screenshots** | `docs/prototypes/` → `specs/<feature>/screenshots/` | UI layout, component placement, flow | business rules or scope |

- A conflict **within** a dimension (e.g. `spec.md` and the manual disagree about
  behavior) → **stop and report**; the user decides.
- A perceived conflict **across** dimensions is usually not a conflict — e.g. the
  prototype showing a control the roadmap schedules for a later phase is
  sequencing, not contradiction. Check the table before reporting.

## The Derivation Rule

**Specs are derived; sources are upstream.**

- `spec.md` snapshots behavior *from* the business docs.
- `specs/<feature>/screenshots/` snapshot layout *from* the prototype.
- `tasks.md` reflects sequencing *from* the roadmap.

When a source artifact changes **after** a feature derived from it, the feature's
artifacts do not auto-update. Report the divergence; the user decides whether the
feature re-baselines. Never silently absorb an upstream change mid-phase.

Never copy source artifacts into feature folders — reference them by path. The
only permitted frozen derivative is `specs/<feature>/screenshots/`.

## Per-Type Rules

### Guides and manuals (`docs/business/`)

- Binary originals (`.docx`, `.pdf`) are opaque to diffs and poorly readable by
  AI. Keep the original, but extract an **AI-readable markdown version** beside
  it and declare the markdown the working authority. Stamp it with the source
  version (e.g. `> Extracted from <document> v1.1, June 2026`).
- When the original updates, regenerate the markdown — that regeneration diff is
  the change review.

### HTML prototypes (`docs/prototypes/`)

- The prototype is a **living** file; per-feature `screenshots/` are its frozen
  derivative, captured with the capture script checked into `docs/prototypes/`
  (screenshot generation must be reproducible, not tribal knowledge).
- Capture one full-page screenshot per view, **in the prototype's own sequence**,
  named with a numeric prefix (`01-…`, `02-…`).
- Record in the feature's `notes.md` which prototype commit the screenshots were
  captured from.
- If the prototype changes after capture, regenerated screenshots are a **change
  request to the spec** — stop and report; do not silently re-capture mid-phase.

### Roadmaps (`docs/roadmap/`)

- The roadmap is the **delivery source of truth**: consult it before starting any
  feature; if it conflicts with a feature's `spec.md`, stop and report.
- Living document: keep its statuses in sync with `specs/<feature>/tasks.md`
  phase markers as work merges. `/phase-done` includes this sync as a checked
  item.
