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

## Which of these has actually run

Read this before you pick a row. The four wrappers are **not** equally proven.

| Platform | Status |
|---|---|
| GitHub | **Run repeatedly on real runners.** Has caught real defects — a CRLF-only bug invisible on a local checkout, and a `.sh`/`.ps1` divergence in `guard-packages` that five rounds of review missed. |
| GitLab | **Never executed.** Syntax reviewed, step coverage asserted by the test suite. |
| Azure DevOps | **Never executed.** Same. |
| Bitbucket | **Never executed.** Same. |

What the test suite proves about all four is narrow and worth stating exactly: that
each wrapper invokes all six steps, that none of them marks a step as
allowed-to-fail, and that each platform ships an ownership file or a written
procedure. That is a check on the *text* of the wrapper. It says nothing about
whether the runner accepts the YAML, whether the image has `sha256sum` and `awk`,
whether the checkout is deep enough for `git write-tree` to produce the same
fingerprint, or whether the job is wired up as a *required* check rather than an
advisory one.

So on the three unexecuted platforms, the first thing to do after installing is
**prove the gate can fail**. Push a branch that breaks it deliberately — add a
`// TODO` to a source file so the stub ratchet trips — and confirm the pipeline goes
red *and* that the change request cannot be merged. A gate that runs and reports
without blocking is worse than no gate, because it produces evidence of a check
that isn't there. If the wrapper needs a fix to get that far, the fix belongs
upstream in this folder, not only in your repo.

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

### Two places, two forms — and the manifest needs escaping

The command goes in **two** files, and only one of them takes it verbatim:

- **`CLAUDE.md`** — paste it exactly as written above. It is markdown; nothing to escape.
- **`.claude/framework-manifest.json`** — it is a **JSON string value**, so every
  double quote in the command must be written `\"`.

Three of the four commands above contain double quotes. Pasting one of those into
`review_evidence_cmd` verbatim produces **invalid JSON**, and `/framework-doctor`
reads that file — so the install fails at its last step for a reason nothing warned
about. This was found by the first fresh-install rehearsal, and it broke on GitHub,
Azure DevOps and Bitbucket. Only the GitLab command is quote-free.

JSON-escaped forms, ready to paste into the manifest:

| Platform | `review_evidence_cmd` value |
|---|---|
| GitHub | `gh pr view --json reviews --jq '[.reviews[] \| select(.state==\"APPROVED\") \| .author.login]'` |
| GitLab | `glab mr view --output json \| jq '[.approved_by[].user.username]'` |
| Azure DevOps | `az repos pr show --id <id> --query \"reviewers[?vote==`10`].displayName\"` |
| Bitbucket | `curl -sn \"$BB_API/pullrequests/<id>\" \| jq '[.participants[] \| select(.approved) \| .user.display_name]'` |

If you would rather not hand-escape, put the command in `CLAUDE.md` first and derive
the manifest value from it:

```sh
python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))' <<'CMD'
gh pr view --json reviews --jq '[.reviews[] | select(.state=="APPROVED") | .author.login]'
CMD
```

That prints the value **with** its surrounding quotes, ready to drop in whole.
`tests/framework-checks.sh` asserts the manifest template still parses as JSON with
each of the four escaped forms substituted in, so a command added to the table
without an escaped twin fails the build.

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
