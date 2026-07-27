# Frontend Rules

Core architecture rules for a Next.js App Router + tRPC + NextAuth + Redux Toolkit + Tailwind/shadcn frontend.

> **MANDATORY**: every frontend phase must pass
> `docs/stacks/<frontend>/compliance-checklist.md` before it is marked complete.
> The checklist is part of Definition of Done item 5 (AI review).

## Stack

- Next.js with App Router.
- TypeScript strict mode.
- tRPC API layer.
- NextAuth with the project's identity provider where the project uses it.
- Redux Toolkit + React Query where already used.
- Tailwind CSS + shadcn/ui where already used.
- Package manager as declared in the `packageManager` field — do not switch it.

## Project Shape

Authoritative shape for the frontend repository:

```text
<frontend-repo>/
  src/
    app/                  # App Router pages/layouts
    components/
      ui/                 # primitives (shadcn/ui style)
      forms/              # data-entry forms (Rule F8d)
      tables/
        base/             # BaseDataTable + QueryDataTable
        {feature}-tables/ # feature table folders (Rule F11c)
      layout/             # app shell, header, nav
      dropdowns/          # dropdowns shared across features
      <feature>/          # feature-scoped domain components (non-form, non-table)
    server/
      api/
        root.ts           # composes all routers
        trpc.ts           # context + injected backend fetch helper(s) + protectedProcedure
        routers/          # one router per domain
      auth/               # next-auth config (config.ts)
    trpc/                 # tRPC React client (react.tsx exports `api`)
    schema/               # Zod schemas, one file per domain
    types/                # TypeScript shapes per domain
    lib/                  # store.ts, hooks.ts, features/ (Redux slices), helpers
    utils/                # backend fetch wrapper
    styles/               # globals.css (theme CSS variables)
```

Notes:

- Zod schemas are **domain-scoped** in the top-level `src/schema/` directory
  (e.g. `schema/<domain>.ts`), with types in `src/types/`.
- The tRPC React client is `api` from `@/trpc/react`; server-side callers use
  `@/trpc/server`.
- Path alias `@/*` → `src/*`.
- Keep existing directory names consistent even when misspelled — no parallel
  corrected dirs. A directory misspelled at creation keeps that spelling; record
  it in `docs/project/gotchas.md` so nobody "fixes" it later.

## App Router Rules

- Use `app/[route]/page.tsx` for pages.
- Use `layout.tsx` for section layout.
- Use dynamic route folders like `[code]`.
- Server Components by default.
- Add `'use client'` only when using state, effects, browser APIs, event handlers, React Hook Form, tRPC client hooks, or Redux hooks.

## Component Rules

- File names use kebab-case.
- Exported components use PascalCase.
- Define props interfaces above components.
- Compose existing components from `components/ui/`.
- Do not invent duplicate primitives.
- Do not introduce a new UI library without approval in `plan.md`.

## Data Flow

Standard project flow:

```text
Browser
 -> Next.js App Router page
 -> tRPC procedure
 -> backend API fetch wrapper
 -> backend API
 -> database/external services
```

Rules:
- UI must not call backend URLs directly.
- Use `api.<router>.<procedure>` from `@/trpc/react` on the client.
- Use the server caller from `@/trpc/server` where the project pattern supports it.
- tRPC procedures call the injected backend fetch helper(s) on `ctx` — one per
  backend service (e.g. `ctx.<service>Fetcher`), each wrapping a single shared
  fetch utility. Record this project's helper names in `docs/project/`.
- Business entities live in the backend API unless the project plan says otherwise.

## Forms

Forms must follow `docs/stacks/<frontend>/forms.md`.

Key rules:
- React Hook Form.
- Zod resolver.
- shadcn/ui Form components.
- Sonner toast.
- tRPC mutations.
- Forms live in `components/forms/`.
- Schemas live in `src/schema/<domain>.ts`.
- Dual create/update mode through `data` prop (where the entity supports both).

## Tables

Tables must follow `docs/stacks/<frontend>/tables.md`.

Key rules:
- Use `QueryDataTable` for server-paged lists; `BaseDataTable` alone is allowed
  only for matrix-style grids with no server paging (see `tables.md`).
- Do not duplicate pagination/search/sort/URL state logic.
- Feature table folder contains `table.tsx`, `columns.tsx`, and `cell-action.tsx`
  (`cell-action.tsx` only when rows have actions).
- Columns live in `columns.tsx`.
- Actions column is last.
- Selection column is first when used.

## State

- Use Redux Toolkit for global UI/session state only when already present.
- Use tRPC/React Query for server state.
- Use React Hook Form for form state.
- Do not duplicate server state in Redux.
- Invalidate/refetch after mutations.

## Auth

- Server pages should check session using the existing auth helper.
- Client components use `useSession()` only when needed.
- Permission data should follow the existing session/Redux pattern.
- Protected writes must use protected tRPC procedures.

## Styling

- Use Tailwind utilities.
- Use the project `cn()` helper when combining classes.
- Follow existing CSS variables and theme.
- Do not invent colors, spacing, or layout when screenshots exist.
- Follow mobile-first responsive design.

## Types and Schemas

- `types/` holds TypeScript shapes per domain (plus ambient files like `next-auth.d.ts`).
- `schema/<domain>.ts` holds Zod schemas and their inferred types.
- Prefer `z.infer` for form data.
- Avoid `any`.
- Keep request and response types explicit.

## Forbidden

- Inline table columns in page files.
- Inline large Zod schemas in forms.
- Direct backend fetches from UI components.
- New UI library without approved plan.
- Duplicated form/table boilerplate.
- `alert()` for production flows.
- Hiding validation or API errors.
