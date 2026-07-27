# Frontend Compliance Checklist (MANDATORY)

Every frontend phase MUST pass this checklist before it is marked complete. It is
part of Definition of Done item 5 (AI review) — see
`docs/process/definition-of-done.md`. The AI completes it and records the result in
the phase's review notes; any FAIL blocks the phase.

> Surfaces built before this checklist was adopted are brought into compliance as
> they are touched; the checklist applies to ALL new work immediately.

## Structure

- [ ] New files follow the Project Shape in `docs/stacks/<frontend>/rules.md`
      (`src/` layout; schemas in `src/schema/<domain>.ts`; tRPC client `api` from
      `@/trpc/react`).
- [ ] Component files are kebab-case; exported components PascalCase; props
      interfaces defined above components.
- [ ] `'use client'` only where state/effects/hooks/browser APIs/event handlers
      require it.

## Data Flow

- [ ] No direct backend fetches from UI code (no `fetch(<backend URL>)`, no axios,
      no `NEXT_PUBLIC_API*` reads in components/pages).
- [ ] Client data access uses `api.<router>.<procedure>` hooks; mutations
      invalidate/refetch affected queries via `api.useUtils()`.
- [ ] tRPC procedures validate input with Zod and call the injected backend
      fetch helper(s) on `ctx` (one per backend service, e.g. `ctx.<service>Fetcher`);
      anything requiring a session uses `protectedProcedure`.

## Forms (`docs/stacks/<frontend>/forms.md`)

- [ ] Every data-entry form uses React Hook Form + `zodResolver` — no `useState`
      field state, no manual validation guards.
- [ ] Form UI uses shadcn/ui `Form` components; required fields show the red `*`;
      errors render via `<FormMessage />`.
- [ ] Success/error feedback uses Sonner `toast` — no `alert()`, no silently
      swallowed errors.
- [ ] Dual create/update via `data` prop where the entity supports both.
- [ ] Forms live in `components/forms/`; schemas in `src/schema/<domain>.ts`.

## Tables (`docs/stacks/<frontend>/tables.md`)

- [ ] No hand-rolled `<table>` for data lists. Server-paged lists compose
      `QueryDataTable`; matrix grids may compose `BaseDataTable` directly.
- [ ] Columns live in `columns.tsx` (never inline in pages/components);
      `id: 'actions'` last; `id: 'select'` first when present.
- [ ] Feature tables live in `components/tables/{feature}-tables/`.
- [ ] Server-paged lists drive page/limit/search/sortBy/sortDir from URL params.

## State, Auth, Styling

- [ ] Server state in tRPC/React Query only — not duplicated into context/Redux
      (Redux holds only session-scoped state: the project's global scope
      selections and permissions).
- [ ] Permission gating uses the project's permission hooks/components as UX
      hints; writes rely on backend enforcement (e.g. a `useHasPermission` hook and
      a `RequirePermission` wrapper component).
- [ ] Tailwind utilities + `cn()`; theme CSS variables from `styles/globals.css`;
      no hardcoded hex colors; layout matches screenshots when they exist.

## Security & Performance

- [ ] No secrets or backend tokens reach the client bundle; no auth data in
      `localStorage`.
- [ ] No new `dangerouslySetInnerHTML` with dynamic content.
- [ ] Lists are paginated or justified-bounded; loading/empty/error states exist;
      search inputs debounced.
- [ ] No new packages beyond those approved in the feature's `plan.md` (or
      `spec.md` at Small tier, which ships no `plan.md`).

## Process

- [ ] Only the approved phase's files changed (`git diff --stat` reviewed).
- [ ] The gate receipt reports `RECEIPT: valid` for the current tree. A pasted
      exit code does not satisfy this, and neither does a stale, `min`, or missing
      receipt — see `docs/process/definition-of-done.md` item 3.

## Project-Specific Rules (define per project in docs/project/)

- Global scope selector policy: which scope values come exclusively from a global header selector, with feature pages displaying (never re-selecting) that scope.
