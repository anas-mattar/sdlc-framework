# Azure DevOps — code ownership and required checks

Azure DevOps has **no `CODEOWNERS` file**. Everything GitHub expresses in one
tracked, diffable, reviewable file is expressed here as portal configuration
stored outside the repository. That is a real weakening and it is worth naming:
the settings below cannot be reviewed in a pull request, cannot be diffed, and
leave no trace in git when someone changes them. Record in `CLAUDE.md` who is
allowed to change branch policies, because the repository cannot enforce it.

There is nothing to copy into the repository from this file. Configure the two
policies below once, then confirm them after every `/framework-upgrade`.

## 1. Build Validation — make the gate mandatory

Without this, `azure-pipelines.yml` runs and reports, and nothing stops a merge.
The `pr:` trigger in the pipeline file schedules the run; it does not require it.

> Repos → Branches → `main` → **⋯** → Branch policies → **Build Validation** → **+**
>
> | Setting | Value |
> |---|---|
> | Build pipeline | the pipeline created from `azure-pipelines.yml` |
> | Path filter | *(leave empty — the gate covers the whole repo)* |
> | Trigger | Automatic |
> | Policy requirement | **Required** |
> | Build expiration | Immediately when `main` is updated |

*Build expiration* matters more than it looks. Set to "Never", a green build from
before the gate script was edited still satisfies the policy after it was edited —
which is the same staleness the local receipt exists to prevent, reintroduced at
the merge boundary.

## 2. Automatically included reviewers — the CODEOWNERS substitute

This is the closest equivalent to path-scoped ownership. Add one policy per group
of paths below.

> Repos → Branches → `main` → **⋯** → Branch policies →
> **Automatically included reviewers** → **+**
>
> Set **Required** (not Optional), add `{{OWNER}}` and `{{REVIEWER}}`, and paste
> the path filter.

| Policy | Path filter | Why |
|---|---|---|
| Gate definition | `/gate.sh;/gate.ps1;/.gate-sha256;/check-stubs.sh;/check-stubs.ps1;/.gate-stubs-baseline` | These decide what "the gate passed" means |
| Whether the gate runs | `/azure-pipelines.yml;/tooling/ci/` | The pipeline file is a wrapper; every check lives in `tooling/ci/gate-ci.sh`. Owning the wrapper and not the script would leave the gate editable in silence |
| Whether the guards exist | `/.claude/settings.json;/.claude/settings.local.json;/.claude/hooks/` | `settings.json` wires the guards; the hooks are the guards |
| What the gate may let through | `/docs/exceptions.md` | Editing a remediation date is how an exception becomes permanent |
| The rules themselves | `/docs/process/;/docs/stacks/` | Layer 1 and 2 are upstream-owned — see `CONTRIBUTING.md` |

Also set **Minimum number of reviewers = 1** with *"Prohibit the most recent
pusher from approving their own changes"* enabled. On a solo project, leave the
minimum at 1 and approve deliberately: it is still a timestamped, out-of-band act,
and it is the difference between a review that happened and a file that says one
did.

## 3. What this does not give you

- **No git-visible record.** A GitHub project can see its `CODEOWNERS` change in a
  diff. Here, someone with *Edit policies* permission can remove a required
  reviewer and the repository looks identical. Restrict that permission and audit
  it: Project settings → Repositories → Security → **Edit policies**.
- **Path filters are not gitignore patterns.** They are literal path prefixes
  separated by `;`. A trailing `/` matches a folder; there is no `*` globbing. A
  filter naming a path that does not exist is silently inert, exactly as a stale
  `CODEOWNERS` line is.
- **`/framework-doctor` cannot verify any of this.** It reports the policy as
  unverifiable rather than pretending otherwise.
