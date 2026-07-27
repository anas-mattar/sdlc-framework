# Frontend Performance Rules

## Purpose

This file defines mandatory frontend performance rules for the project.

Screens may include large tables, work-queue lists, dashboards, filters, and forms. Frontend performance must be considered during implementation, not after users complain.

## 1. General Principles

- Server Components by default.
- Client Components only when needed.
- Avoid unnecessary global state.
- Avoid loading large datasets into the browser.
- Keep forms responsive.
- Keep tables paginated.
- Keep bundles small.
- Use loading, empty, and error states.

## 2. Server vs Client Components

Use Server Components for static page layout, server-side reads, pages that do not need interactivity, and initial report rendering when appropriate.

Use Client Components only for forms, filters, modals, dropdown interactions, table interactions, stateful UI, and browser APIs.

Do not add `'use client'` at the top of a large page unless required.

## 3. Data Loading

Do not fetch unnecessary data.

Use pagination, filtering, sorting, search, and backend projection.

Avoid loading all rows, loading all details for list screens, loading dropdowns repeatedly, and duplicate API calls.

## 4. Tables

All large tables must use server-side pagination.

Tables must follow:

- `docs/stacks/<frontend>/tables.md`

Required:

- loading state
- empty state
- error state
- pagination
- search
- sorting
- filtering

Do not implement client-side pagination over thousands of rows.

## 5. Forms

Forms must avoid unnecessary re-renders.

Use React Hook Form patterns from:

- `docs/stacks/<frontend>/forms.md`

Rules:

- Keep form state inside React Hook Form.
- Use `watch()` carefully.
- Avoid expensive calculations on every keystroke.
- Debounce server-side validation/search fields when needed.
- Disable submit during submission.

## 6. Bundle Size

Avoid adding new packages.

If a new package is needed:

- it must be approved in `plan.md`
- explain why existing tools cannot solve it
- consider bundle impact

Use dynamic import for heavy optional components.

## 7. Rendering

Avoid rendering huge lists without pagination/virtualization, expensive calculations inside JSX, unnecessary `useEffect`, unnecessary Redux updates, and unstable callbacks passed to many children.

Consider memoized derived values when needed, stable query keys, and splitting heavy components.

## 8. Dashboard and Report Screens

Dashboards should:

- load summary data first
- avoid blocking entire page for one slow widget
- show skeleton/loading state per section
- allow refresh/refetch
- avoid repeated identical queries

## 9. Images and Assets

- Optimize images.
- Avoid large uncompressed assets.
- Use appropriate formats.
- Lazy-load non-critical visuals.

## 10. Frontend Performance Review Checklist

Before completing a frontend phase, check:

- [ ] Are Client Components limited to where needed?
- [ ] Are tables server-paginated?
- [ ] Are large datasets avoided?
- [ ] Are loading/empty/error states present?
- [ ] Are duplicate API calls avoided?
- [ ] Are heavy components lazy-loaded if needed?
- [ ] Are new packages approved?
- [ ] Is global state usage justified?
- [ ] Are forms responsive during input and submit?
