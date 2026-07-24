# Contributing

This framework imposes a process on other projects. It follows that process
itself — a framework that exempts itself from its own rules is telling you what
its author really thinks of them.

## Before you open a PR

Run the self-tests. They are the framework's own gate:

```sh
sh tests/run-all.sh        # macOS, Linux, WSL, Git Bash
```

```powershell
.\tests\run-all.ps1        # Windows — locates Git's sh.exe and runs the same suite
```

The suite must print `EXIT: 0`. CI runs the identical script, so a green local run
means a green CI run. `SKIP` is not a failure — it means an optional tool (pwsh,
python, pyyaml) is absent on your machine; CI has them.

## What the tests actually protect

Each check exists because something failed silently once:

| Check | The failure it prevents |
|---|---|
| `.ps1` files are ASCII-only | Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI. One em dash turns into three bytes, one of which is a quote, and the script dies with "string is missing the terminator". For the package-guard hook that means failing **open** — the guard is gone and nothing says so. |
| Shell / PowerShell parse | A gate script that cannot start is a gate that never runs. |
| JSON / YAML validity | A malformed `settings.json` disables every hook in it, silently. |
| Every tag has a CHANGELOG entry | Downstream cannot tell what an upgrade changes. |
| VERSION has a git tag | `/framework-upgrade` diffs a project's copy against the tagged upstream tree. An untagged release is unreachable by every consumer. |
| Internal links resolve | A rule that points at a missing file is a rule nobody reads. |
| Layer discipline (baseline 0) | Layers 1 and 2 carried the original project's vocabulary for twelve releases — a mandatory checklist told every project to call `ctx.featcher`. Any reintroduction now fails the build. |
| Self-contained authority (baseline 0) | Layer 1 used to cite constitution principle numbers for a document the framework never ships, making the rules defer to an authority that did not exist. |

The last two are **ratchets**: the baseline is 0 and only ever moves down. If you
fork this for your own product, add your own product's terms to the pattern in
`tests/framework-checks.sh`.

## The rules that matter when editing

1. **Layer discipline.** If a sentence names a specific product, domain, or system,
   it belongs in layer 3 (`docs/project/` in a consuming project) — never in
   `process/`, `stacks/`, or `modules/`. This is enforced, not requested.
2. **One source of truth per fact.** The gate is defined in `gate.ps1`/`gate.sh` and
   nowhere else. Never restate a rule in a second file — link to it. Most review
   comments on this repo are some form of "you just created a second copy of this."
3. **Ship behavior over prose.** A script, hook, or slash command transfers between
   projects with zero editing and does not degrade the way instructions do. Prefer
   adding one over adding a paragraph. If your PR is only prose, ask whether the
   thing it describes could be checked instead.
4. **Every behavior change needs a test.** New gate or receipt behavior goes in
   `tests/receipt-contract.sh`; new structural rules go in
   `tests/framework-checks.sh`.

## Versioning and the changelog

`VERSION` is semver: patch = wording, minor = new rules/modules, major = process
changes that alter how phases are gated or reviewed.

Every bump needs a `CHANGELOG.md` entry that answers the only question a consuming
project has: **what must I re-copy?** Entries that describe the change but not its
downstream action are incomplete.

Releases are tagged `vX.Y.Z`. While a version is in progress and untagged, mark its
changelog heading `## X.Y.Z (unreleased)` — the self-test recognises that and stands
down until the tag lands.

## Scope of contributions

Most welcome:

- Additional `stacks/<stack>/` rule sets, following the numbered-rule convention.
- Enforcement that replaces prose — hooks, checks, commands.
- Fixes where the docs and the tooling disagree.

Discuss first (open an issue):

- New layer-1 process rules. The bar is high: every rule added is a rule every
  consuming project must follow forever, and the framework's biggest risk is
  becoming a pile of rules nobody reads.
- Adapters for other AI assistants. Wanted, but the boundary between portable
  process and tool-specific enforcement needs to be settled first.

## Reporting a security issue

Do not open a public issue — see `SECURITY.md`.
