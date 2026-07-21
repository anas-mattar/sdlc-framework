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
| **Design prototype (any source) → feature screenshots** | `docs/prototypes/` → `specs/<feature>/screenshots/` | UI layout, component placement, flow | business rules or scope |

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

### Prototypes (`docs/prototypes/`) — many sources, one contract

The design source varies per feature (HTML, Figma, AI-generated, or none), but
the contract downstream is always the same: **if `specs/<feature>/screenshots/`
exists, it is the frozen layout authority**, with provenance recorded in the
feature's `notes.md`. Implementation and review never care about the source
format.

| Design source | Upstream truth | How to freeze | Provenance in `notes.md` |
|---|---|---|---|
| HTML prototype | `docs/prototypes/*.html` | Playwright capture, in prototype sequence | prototype git commit |
| Figma | the Figma file | export frames as sequence-numbered PNGs into `screenshots/` | Figma file URL + version/date |
| AI-generated design | the generated HTML **after human approval** | promote to `docs/prototypes/`, then the HTML pipeline | approval date + commit |
| No design | `spec.md` layout section + the app's design system | none — `screenshots/` is absent | one line: "no design — spec + design system govern" |

Rules common to all sources:

- Screenshots are one full-page image per view, **in the source's own sequence**,
  named with a numeric prefix (`01-…`, `02-…`). The capture/export method must be
  reproducible — the capture script lives in `docs/prototypes/`.
- If the upstream design changes after capture, regenerated screenshots are a
  **change request to the spec** — stop and report; never silently re-capture
  mid-phase. This applies doubly to Figma, which mutates outside git with no
  diff: the exported snapshot is the contract, not the live file.
- **AI-generated designs require human approval before becoming authority.**
  Without approval the "never invent a UI layout" rule is circular — the AI would
  be treating its own invention as truth. Approval is what promotes a generated
  mock from *proposal* to *source artifact*.
- **No design is legitimate, not a violation.** Layout authority falls to the
  next level: the `spec.md` layout description (wireframe-level words required
  for any non-trivial screen), then the app's design system and stack rules. For
  features with meaningful UI, the AI should *offer* a quick generated mock
  (converting "no design" into the AI-generated path); do not force it for
  trivial UI. Never demand screenshots that cannot exist.

### Roadmaps (`docs/roadmap/`)

- The roadmap is the **delivery source of truth**: consult it before starting any
  feature; if it conflicts with a feature's `spec.md`, stop and report.
- Living document: keep its statuses in sync with `specs/<feature>/tasks.md`
  phase markers as work merges. `/phase-done` includes this sync as a checked
  item.
