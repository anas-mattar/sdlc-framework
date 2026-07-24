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

### Guides, manuals, requirement docs (`docs/business/`) — many sources, one contract

The working authority for spec derivation is always a **versioned markdown
snapshot in `docs/business/`** — never the live external source. The source type
only changes how the snapshot is produced and refreshed:

| Source | Upstream truth | How to freeze | Provenance (frontmatter in the snapshot) |
|---|---|---|---|
| File in the repo (docx/pdf) | the original file | markdown extraction beside it | document version + extraction date |
| GitHub / GitLab (repo or wiki) | the source repo | copy the file(s) at a **pinned commit/tag** | repo URL + commit SHA + date |
| Notion (or similar wiki SaaS) | the page | export the page(s) to markdown | page URL + export date |
| Loose file (shared drive, email) | the issuing party's document | copy the original in + markdown extraction | origin, stated version, date received |

Rules common to all sources:

- **Snapshot before deriving.** A document does not exist for spec purposes until
  its markdown snapshot is in `docs/business/` with provenance recorded. "The
  spec is based on the PDF someone mailed in March" must never be true.
- **Pin, don't track.** For git-hosted sources, snapshot at a specific commit or
  tag — never a branch. A branch reference mutates under the specs with nothing
  forcing a review, same as a live Notion page.
- **Refresh = re-export, and the git diff of the snapshot is the change review.**
  This is what makes the derivation rule enforceable uniformly: upstream changes
  become visible diffs regardless of source type. An upstream change after a
  feature derived from the doc is a change request — stop and report.
- **Access.** Live sources (Notion, private repos) may be unreachable for the AI,
  CI, or a new teammate exactly when needed; the snapshot guarantees the doc is
  always readable. Automate the export where the source has an API.
- **Confidentiality check before copying.** Snapshotting pulls external content
  into a repo that may have wider access than the source did. Ask "is this doc
  safe to commit here?" first; if not, keep only a reference + version record,
  note that the doc must be consulted manually, and accept the weaker guarantee.
- Binary originals (`.docx`, `.pdf`) kept in the repo are opaque to diffs and
  poorly readable by AI — the markdown extraction beside them is the working
  authority, stamped with the source version (e.g. `> Extracted from <document>
  v1.1, June 2026`).

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
- Living document: keep its statuses in sync with `specs/<feature>/status.md`
  phase markers as work merges. `/phase-done` includes this sync as a checked
  item.

#### Scope and status are separate files

`docs/roadmap/status.md` holds the mutable delivery board — one line per feature:
number, name, owner, current status. Everything else under `docs/roadmap/` holds
**scope and sequencing**, which is not status: what is in the release, in what
order, and what has been descoped.

The split exists because the gate receipt fingerprints the roadmap definitions
but not `status.md` (`docs/process/gate-command.md`). Marking a feature "done"
after the gate is bookkeeping and must not invalidate a receipt; *descoping* an
item after the gate changes what was promised, and must. Keeping both in one file
would force the framework to choose one behavior for both.

The same split applies per feature: `tasks.md` defines the phases, and
`specs/<feature>/status.md` records which are complete.

#### Roadmap structure

- A roadmap is never **derived from** guides: guides own behavior ("what the
  system must do"), the roadmap owns prioritization ("what gets built when") — a
  human decision. Roadmap items **reference** the guide sections they implement;
  the two slice the project along different axes (behavior domains vs. delivery
  streams) and must not be forced to align.
- **Default: one roadmap per project.** Split into one roadmap per delivery
  stream/module only when a single file gets unwieldy — never split by guide.
- **Every feature belongs to exactly one roadmap.** A feature's status must
  never be trackable in two places.
- If more than one roadmap exists, keep a thin index (`docs/roadmap/README.md`:
  one line per roadmap — stream, owner, status) so "consult the roadmap" has an
  unambiguous entry point.
- On multi-developer projects, roadmap items carry an **owner** — see
  `docs/process/team-workflow.md`.
