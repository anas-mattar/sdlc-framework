# Frontend tRPC Rules

## BFF Pattern

The frontend defines both `publicProcedure` and **`protectedProcedure`**
(`src/server/api/trpc.ts`). tRPC is the **only data path** — the browser never
calls the backend REST APIs directly:

- Procedures call the injected backend fetch helper(s) on `ctx`, one per backend,
  targeting a server-side env-var base URL with its session access token; the
  shared wrapper provides Bearer auth, retry-with-backoff for GETs only
  (mutations are never retried), and per-endpoint timeouts.
  > Example: `ctx.<service>Fetcher` → `<SERVICE>_API_URL`, one per backend service,
  > all wrapping a single shared fetch utility. Record this project's helper and
  > env-var names in `docs/project/`.
- Authorization is additionally enforced by the **backend** on every call via the project's permission service; the frontend permission checks are UX hints.
- The browser never holds the backend tokens; tRPC procedures run server-side.

## Router Organization

Recommended structure:

```text
server/api/
  root.ts
  trpc.ts
  routers/
    <domain>.ts
    <domain>/
      list.ts
      cancel.ts
      confirm.ts
```

## Procedure Rules

- Use `protectedProcedure` for anything requiring a session — all writes and
  user-specific reads.
- Use `publicProcedure` only for genuinely public, safe reads (rare).
- Validate input with Zod (`.input(schema)`) on every procedure that takes input.
- Procedures call the injected `ctx.<backendFetcher>` helpers;
  never `fetch` ad hoc inside a procedure.
- Do not call random external URLs directly from components.

## Router Example

```ts
// `ctx.fetcher` stands for the project's injected backend fetch helper
export const myFeatureRouter = createTRPCRouter({
  list: protectedProcedure
    .input(myFeatureListSchema)
    .query(async ({ ctx, input }) => {
      return ctx.fetcher<MyFeatureListResponse>('MyFeature/list', {
        method: 'POST',
        body: JSON.stringify(input),
      });
    }),

  add: protectedProcedure
    .input(myFeatureCreateSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.fetcher<MyFeature>('MyFeature', {
        method: 'POST',
        body: JSON.stringify(input),
      });
    }),

  update: protectedProcedure
    .input(myFeatureUpdateSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.fetcher<MyFeature>(`MyFeature/${input.id}`, {
        method: 'PUT',
        body: JSON.stringify(input),
      });
    }),
});
```

## Error Handling

- Use the project's existing fetch wrapper behavior.
- Do not expose raw backend stack traces to users.
- Forms should show toast errors.
- Tables should show loading, empty, and error states.
