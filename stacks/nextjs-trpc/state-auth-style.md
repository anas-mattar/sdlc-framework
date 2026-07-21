# Frontend State, Auth, and Style Rules

## State

Use the right state owner:
- React local state: small component UI state.
- React Hook Form: form state.
- tRPC/React Query: server state.
- Redux Toolkit: global UI/session/permission state.

Do not store backend list data in Redux unless the existing project already does so for a clear reason.

## Redux

Redux Toolkit is used for **session-scoped client state only** — the user's
selected global scope and permissions, deliberately kept out of the NextAuth
session (example from the WMS project: selected warehouse/legal entity):

- Store lives in `src/lib/store.ts`.
- Slices live in `src/lib/features/`.
- Use the typed hooks in `src/lib/hooks.ts`.
- Do not dispatch from server components.
- All server data goes through tRPC + React Query — never duplicated into Redux.

## Auth

- NextAuth handles session.
- The project's identity provider (e.g. Entra ID) is used where configured.
- Server pages should redirect unauthenticated users.
- Client components should render permission-safe UI.
- Permissions must follow the existing session/Redux pattern.

## Styling

Use:
- Tailwind CSS
- shadcn/ui primitives
- `cn()` helper
- Existing theme variables

Do not:
- Add new design system.
- Hardcode random colors.
- Replace existing components.
- Break screenshot layout.

## UI Components

- `components/ui/` contains primitives.
- Domain components should compose primitives.
- Data-entry forms go to `components/forms/` (Rule F8d).
- Data tables go to `components/tables/{feature}-tables/` over the shared base in
  `components/tables/base/` (Rule F11c).
- Other feature-scoped domain components (boards, trees, panels, modal shells)
  go to `components/<feature>/`. Keep existing directory names consistent even
  when misspelled rather than creating a parallel dir (WMS example: the
  existing `purshase-order` directory keeps its name).
- Dropdowns shared across features go to `components/dropdowns/`.
