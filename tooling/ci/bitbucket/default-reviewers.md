# Bitbucket — code ownership and required checks

Bitbucket Cloud has **no path-scoped code ownership**. Of the four platforms this
framework supports, it has the weakest ownership story, and the honest summary is:
you can require *a* reviewer, but you cannot require *the right* reviewer for the
enforcement perimeter. Say so in `CLAUDE.md` rather than assuming coverage that
does not exist.

There is nothing to copy into the repository from this file. Configure the
settings below once, then confirm them after every `/framework-upgrade`.

## 1. Make the gate mandatory

Defining a `pull-requests:` pipeline does not make it a merge requirement.

> Repository settings → **Branch restrictions** → add or edit the rule for `main`
>
> | Setting | Value |
> |---|---|
> | Branch | `main` |
> | Prevent a direct push | on |
> | Prevent rewriting history | on |
> | Prevent deletion | on |
> | Minimum number of approvals | 1 |
> | **Minimum number of successful builds for the last commit** | **1** |
> | Reset approvals when new changes are pushed | on |

The build requirement is the one that matters, and *"for the last commit"* is the
part that makes it meaningful: without it a green build from before the gate
script was edited still satisfies the rule after it was edited — the same
staleness the local receipt exists to prevent, reintroduced at the merge boundary.

"Reset approvals when new changes are pushed" matters for the same reason. An
approval given before someone rewrote `gate.sh` should not survive the rewrite.

## 2. Default reviewers — the partial CODEOWNERS substitute

> Repository settings → **Default reviewers** → add `{{OWNER}}` and `{{REVIEWER}}`

This adds those people to **every** pull request in the repository, not to the
ones touching particular paths. It over-includes rather than under-includes, which
is the correct direction to fail, but it means reviewers see many changes that do
not need them and habituate to approving — a real cost, and the reason path
scoping exists elsewhere.

Bitbucket has no built-in way to require approval only for
`gate.sh`, `tooling/ci/`, `.claude/hooks/` or `docs/exceptions.md`.

## 3. Closing the gap you cannot close with settings

Pick one and record it in `CLAUDE.md`:

1. **A Marketplace code-owners app.** Several add path-scoped reviewers. This
   moves the trust anchor to a third party with write access to your repository —
   a real trade, worth making deliberately rather than by default.
2. **Split the perimeter into its own repository.** Keep `gate.sh`,
   `check-stubs.sh`, `tooling/ci/` and the hooks in a repo with a stricter branch
   restriction, and consume them as a submodule. The submodule pointer change is
   then visible in the diff, and the framework's `.gate-sha256` pin still covers
   the copies in the working tree. Costs an extra repository and an extra step in
   `/framework-upgrade`.
3. **Accept it and write it down.** With a single required approval, a reset on
   push, and a required build on the last commit, an agent still cannot land a
   weakened gate *silently* — the `pin` step forces a visible one-line diff in
   `.gate-sha256`. What is missing is the guarantee that a *specific* human sees
   it. For a small team where every reviewer knows the perimeter, that may be
   enough. State the decision so the next person does not have to infer it.

## 4. What `/framework-doctor` can and cannot see

It checks that `bitbucket-pipelines.yml` exists and invokes every step of
`tooling/ci/gate-ci.sh`. It cannot read your branch restrictions or default
reviewers, and reports both as unverifiable rather than pretending otherwise.
