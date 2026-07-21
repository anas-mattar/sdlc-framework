# Frontend Security Rules

## Purpose

This file defines mandatory frontend security rules for the project.

Frontend security does not replace backend security. The backend remains the authority. The frontend must avoid exposing secrets, leaking data, or misleading users about permissions.

## 1. No Secrets in Frontend

Never expose secrets to browser code.

Forbidden:

- API keys
- client secrets
- database connection strings
- private tokens
- backend service credentials

Only variables intended for browser exposure may use public environment prefixes.

## 2. Protected Routes

Protected pages must check session using the project-approved auth pattern.

Frontend route protection improves UX, but backend must still enforce authorization.

## 3. Permission-Based UI

Hide or disable actions the user cannot perform — any privileged domain action.

> Example (from the WMS project): receive purchase order, finalize discrepancy,
> approve put-away, cancel shipment, export report, manage permissions, manage
> integrations.

Do not rely on UI permissions only. Backend must enforce the same rule.

## 4. Input Validation

Frontend forms must validate using Zod/React Hook Form patterns.

Frontend validation is for user experience. Backend validation is authoritative.

## 5. Unsafe HTML

Do not use `dangerouslySetInnerHTML` unless explicitly approved and sanitized.

If rich text is required:

- sanitize content
- document source
- review XSS risk

Approved `dangerouslySetInnerHTML` usages must be tracked per project (in
`docs/project/`); adding one requires explicit approval per this section,
recorded in the feature's `plan.md`.

## 5a. Content Security Policy

The project's CSP posture is an explicit, documented decision (in
`docs/project/`), never an ad hoc addition inside an unrelated feature:

- A hash/nonce CSP has a high blast radius (it can break every page) and deserves
  its own feature with dedicated testing across all routes.
- Until a CSP ships, the mitigations above stand: no unapproved inline scripts
  and no unsanitized `dangerouslySetInnerHTML`.

## 6. File Upload UI

If upload exists:

- restrict accepted file types in UI
- show file size limits
- validate before upload
- show upload result clearly
- backend must still validate

## 7. Error Messages

Do not show raw stack traces or sensitive backend errors.

Show user-safe messages.

Good:

```text
Unable to submit. Please check the data and try again.
```

Bad:

```text
SQL exception at connection string...
```

## 8. External Links

External links should open safely.

Use:

```tsx
target="_blank"
rel="noopener noreferrer"
```

## 9. Authentication State

Do not store sensitive tokens manually in localStorage unless the project auth design explicitly requires it.

Use the project-approved session/auth provider.

## 10. Data Leakage

Do not render data outside the user's authorized entity scope.

Do not keep sensitive data in global state longer than needed.

Be careful with console logs, browser storage, exported files, cached query data, and screenshots/debug tools.

## 11. Export Security

For export buttons:

- check permissions
- show scope being exported
- avoid exporting hidden unauthorized data
- backend should generate or authorize export

## 12. Frontend Security Review Checklist

Before completing a frontend phase, check:

- [ ] No secrets exposed to browser.
- [ ] Protected routes check session.
- [ ] Permission UI matches backend permissions.
- [ ] Forms validate input.
- [ ] No unsafe HTML.
- [ ] Upload UI has restrictions if relevant.
- [ ] Error messages are safe.
- [ ] External links are safe.
- [ ] Sensitive data is not logged.
- [ ] Export actions are permission-aware.

## Project-Specific Rules (define per project in docs/project/)

- The list of privileged actions requiring permission gating.
- Current CSP status and its roadmap item.
- The registry of approved `dangerouslySetInnerHTML` usages (if any).
