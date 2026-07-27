# CI — the platform matrix

The gate's enforcement logic lives in **`gate-ci.sh`**, once. The folders beside
it hold thin per-platform wrappers that check out the repository and invoke that
script's steps. A new platform is a wrapper, not a port.

This is deliberate. Every control in this framework already ships twice (`.sh` and
`.ps1`) and that pair has been the single largest source of defects — the bug is
always in the twin nobody remembered to bring along. Four platforms would have
been four twins of a 250-line exceptions parser that has had five separate bugs,
every one of which made it pass silently. `tests/framework-checks.sh` asserts that
every wrapper invokes every step, because a wrapper that quietly drops one is the
obvious failure mode of this arrangement.

## What to install

Pick the row for your platform. Everything in `Copy to` goes into the consuming
repository; `gate-ci.sh` is copied for **every** platform.

| Platform | Copy to | Also copy | Ownership |
|---|---|---|---|
| GitHub | `.github/workflows/gate.yml` | `tooling/ci/gate-ci.sh` | `tooling/ci/github/CODEOWNERS` → `.github/CODEOWNERS` |
| GitLab | `.gitlab-ci.yml` | `tooling/ci/gate-ci.sh` | `tooling/ci/gitlab/CODEOWNERS` → `CODEOWNERS` **(Premium only)** |
| Azure DevOps | `azure-pipelines.yml` | `tooling/ci/gate-ci.sh` | portal settings — `tooling/ci/azure-devops/branch-policy.md` |
| Bitbucket | `bitbucket-pipelines.yml` | `tooling/ci/gate-ci.sh` | portal settings — `tooling/ci/bitbucket/default-reviewers.md` |

`gate-ci.sh` is installed at `tooling/ci/gate-ci.sh` inside the consuming repo,
not at the root, because the wrappers invoke it by that path and because it must
be covered by the same ownership rule as the wrapper. Owning the wrapper and not
the script it calls leaves the whole gate editable in silence.

## Terminology

`docs/process/review-process.md` holds the canonical definitions. Repeated here
only as a lookup:

| This framework says | GitHub | GitLab | Azure DevOps | Bitbucket |
|---|---|---|---|---|
| change request | pull request | merge request | pull request | pull request |
| protected-branch rules | branch protection | protected branches | branch policies | branch restrictions |
| code ownership | CODEOWNERS | CODEOWNERS (Premium) | automatically included reviewers | default reviewers |

## The review-evidence command

Definition of Done item 6 requires proof that a human approved the change request,
recorded somewhere the agent cannot write. Each platform exposes it differently,
so the command is chosen at setup and written into `CLAUDE.md` — layer 1 refers to
"the review-evidence command recorded in CLAUDE.md" rather than naming a vendor's
CLI it cannot assume is installed.

| Platform | Command | Needs |
|---|---|---|
| GitHub | `gh pr view --json reviews --jq '[.reviews[] \| select(.state=="APPROVED") \| .author.login]'` | `gh`, authenticated |
| GitLab | `glab mr view --output json \| jq '[.approved_by[].user.username]'` | `glab`, authenticated |
| Azure DevOps | `az repos pr show --id <id> --query "reviewers[?vote==\`10\`].displayName"` | `az` + `azure-devops` extension |
| Bitbucket | `curl -sn "$BB_API/pullrequests/<id>" \| jq '[.participants[] \| select(.approved) \| .user.display_name]'` | API token in `~/.netrc` |

Any of these is acceptable. What is not acceptable is a tick in a markdown file:
the agent wrote the file, so it can write the tick. The point of every command in
that table is that its output comes from outside the working tree.

**A fallback that works everywhere**, if no CLI is available:

```
git log -1 --format='%(trailers:key=Reviewed-by,valueonly)' <phase commit>
```

Weaker — a trailer is written by whoever makes the commit — but still an artifact
with an author and a timestamp, which a checkbox is not.

## What none of this fixes

The pipeline definition is read from the change request's own head branch on every
one of these platforms. So a change request can weaken its own required check, and
the only thing standing against that is code ownership plus a human who reads the
diff. `gate-ci.sh` says the same thing at more length; `SECURITY.md` holds the
threat model.
