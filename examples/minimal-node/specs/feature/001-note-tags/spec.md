# 001 — Note Tags

> Small-tier spec. There is no `plan.md` and no `tasks.md`: the technical approach
> and the task list live in this file. Everything the gate, the AI review, and the
> acceptance review need is here or it does not exist.

| Field | Value |
|---|---|
| Branch | `feature/001-note-tags` |
| Owner | solo |
| Status | Approved — implementation may start |
| Approved by | (developer), 2026-07-20 |
| Design source | None — spec layout section + design system govern |

## 1. Problem

Notes accumulate faster than they can be found. Search covers note *content*, but
users group notes by things the content never says: "work", "reading", "later".
Today they fake it with a prefix in the title.

## 2. Behavior

- A note has zero or more tags. A tag is 1–24 characters, lowercase, no spaces
  (hyphens allowed).
- Tags are created by typing them on a note. There is no separate tag-management
  screen — that is deliberate scope removal, not an oversight.
- Removing the last note carrying a tag removes the tag entirely. No orphans.
- The note list can be filtered to one tag at a time. Multi-tag filtering is out
  of scope for this feature.
- Tags are per-user. A user never sees another user's tags.

**Out of scope:** renaming a tag, merging tags, tag colours, multi-tag filters,
tag suggestions. Each is a separate feature if it is ever wanted.

## 3. Layout

No prototype or Figma exists for this feature, so this section is the layout
authority (`docs/process/source-artifacts.md`).

- **Note editor** — a tag input sits directly under the title field. Existing tags
  render as removable chips before the input. Enter or comma commits a tag.
- **Note list** — each row shows its tags as small non-interactive chips after the
  title, truncated to three with a `+N` indicator.
- **Filter** — a single-select tag dropdown in the list toolbar, next to search,
  with an "All tags" default. Selecting a tag also puts it in the URL as
  `?tag=<name>` so a filtered view is linkable.

Everything else follows the existing design system. Do not invent a new component
where a shadcn/ui one exists.

## 4. Technical approach

<!-- At Medium/Large this section would be plan.md. -->

- **Data model** — `Tag { id, name, userId }` with a unique index on
  `(userId, name)`, and a `NoteTag` join table. Cascade-delete `NoteTag` rows with
  the note. The "no orphans" rule is enforced in the mutation that detaches a tag,
  not by a background job.
- **API** — extend the existing `notes` tRPC router: `notes.setTags(noteId, tags[])`
  and `notes.list({ tag? })`. No new router. Both procedures authorize on
  `session.user.id` server-side; `userId` is never accepted from the client.
- **Frontend** — one new `TagInput` client component; the note list stays a server
  component and reads the filter from `searchParams`.
- **Migration** — additive only: two new tables, no changes to `Note`. Reversible
  by dropping them.

**No new packages.** If implementation appears to need one, stop — that is a
change to this spec, and the package guard will block it until this file approves
it explicitly.

## 5. Tasks

<!-- The task list Medium/Large would keep in tasks.md. At Small tier the gate
     runs once, over the whole feature, so these are an ordering aid rather than
     gate boundaries. -->

- [ ] Migration: `Tag` and `NoteTag` tables + unique index.
- [ ] `notes.setTags` procedure, with authorization and orphan cleanup.
- [ ] `notes.list` accepts an optional `tag` filter.
- [ ] `TagInput` component + chips in the editor.
- [ ] Tag chips in the note list, truncated at three.
- [ ] Filter dropdown wired to `?tag=`.
- [ ] Tests: orphan cleanup, cross-user isolation, tag-name validation.

## 6. Acceptance

- Adding two tags to a note and reloading shows both.
- Removing a tag from its only note removes it from the filter dropdown.
- A second user's tags never appear in the first user's dropdown, and requesting
  another user's tag by URL returns their own notes only — verified by hand, not
  only by test.
- `./gate.sh` prints `EXIT: 0`, and `./gate.sh --verify` prints `RECEIPT: valid`
  against the tree that is about to be committed.
