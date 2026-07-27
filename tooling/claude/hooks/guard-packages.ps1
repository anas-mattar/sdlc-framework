# PreToolUse hook: blocks edits to package manifests/lockfiles unless package
# changes have been approved for the current feature.
#
# Approval = the file .claude/allow-package-changes exists (create it when the
# feature's plan.md approves new packages; delete it after the phase commits).
#
# Exit 2 blocks the tool call and shows stderr to Claude; exit 0 allows it.
#
# The pattern list below is DELIBERATELY broader than the stacks this framework
# ships rules for. A guard that only knows package.json and *.csproj installs
# cleanly on a Python or Go project, reports GUARD: verified, and then permits
# every dependency change silently -- an enforcement gap that looks like
# enforcement. Guarding a manifest costs nothing on a project that has none.
#
# The identical list lives in guard-packages.sh; tests/framework-checks.sh fails
# the build if the two drift apart.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". A hook that dies fails OPEN.

$inputJson = [Console]::In.ReadToEnd()
# Fail CLOSED when the payload names a target this hook cannot read. `catch { exit 0 }`
# treated a malformed payload as nothing to judge, which is the same silent pass the
# .sh hook's `|| exit 0` gave -- see the JSON-EXTRACT block there. A payload with no
# path at all is still allowed: that is a tool this hook does not judge.
$data = $null
try { $data = $inputJson | ConvertFrom-Json } catch {
    if ($inputJson -match '"(file_path|notebook_path)"') {
        [Console]::Error.WriteLine("BLOCKED: the package guard could not read the target path out of the hook payload, so it cannot tell whether this edits a package manifest. This is a bug in the guard, not in your edit -- report it with the path you were editing.")
        exit 2
    }
    exit 0
}

# NotebookEdit is in this hook's matcher and reports its target as `notebook_path`,
# so file_path alone made every NotebookEdit call invisible to the guard.
$filePath = $data.tool_input.file_path
if (-not $filePath) { $filePath = $data.tool_input.notebook_path }
if (-not $filePath) { exit 0 }
# A path that is not a STRING is a path neither implementation can judge.
# `{"file_path":["package.json"]}` used to be flattened by PowerShell's string
# coercion here and skipped entirely by the .sh parser -- blocked on one platform,
# allowed on the other, for the same payload.
if ($filePath -isnot [string]) {
    [Console]::Error.WriteLine("BLOCKED: the package guard could not read the target path out of the hook payload, so it cannot tell whether this edits a package manifest. This is a bug in the guard, not in your edit -- report it with the path you were editing.")
    exit 2
}

# Split-Path handles backslashes but not forward slashes in every PowerShell
# version, and Claude Code reports both. Take the last segment either way.
$name = ($filePath -split '[\\/]')[-1]
if (-not $name) { exit 0 }

# --- the guard guards itself ------------------------------------------------
# Everything this control depends on lives inside the perimeter the agent
# controls: the approval marker, the hook configuration, and the hook script. None
# of them is a package manifest, so without this block a blocked agent can simply
# Write `.claude/allow-package-changes` -- whose exact filename the block message
# below helpfully supplies -- and the guard is permanently open in one tool call.
# /framework-doctor check 5 finds the residue afterwards, but it runs after setup
# and after upgrade, never during phase work, and the marker can be deleted once
# the edit has landed. So the block has to be here, at the moment of the write.
# Claude Code reports Windows paths with backslashes, and they may arrive doubled,
# so fold and then squeeze the repeats -- otherwise none of the patterns below
# match on the platform this guard is shipped configured for.
$norm = ($filePath -replace '\\', '/') -replace '/+', '/'
foreach ($self in @('*.claude/allow-package-changes', '*.claude/settings*.json', '*.claude/hooks/*')) {
    if ($norm -like $self) {
        [Console]::Error.WriteLine("BLOCKED: '$filePath' is part of the package guard itself (its approval marker, its configuration, or its hook script). Only a human creates or edits these. If package changes are genuinely approved in the feature's plan.md (or spec.md at Small tier), ask the user to create the marker -- do not create it yourself.")
        exit 2
    }
}

$guarded = @(
# GUARDED-MANIFESTS-BEGIN
    'package.json', 'package-lock.json', 'npm-shrinkwrap.json', 'yarn.lock',
    'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'bun.lockb', 'bun.lock', 'deno.json', 'deno.jsonc',
    'deno.lock', '*.csproj', '*.fsproj', '*.vbproj', '*.nuspec', 'packages.config',
    'Directory.Packages.props', 'Directory.Build.props', 'paket.dependencies', 'paket.lock',
    'pyproject.toml', 'requirements*.txt', '*-requirements.txt', 'Pipfile', 'Pipfile.lock',
    'poetry.lock', 'uv.lock', 'setup.py', 'setup.cfg', 'environment.yml', 'go.mod', 'go.sum',
    'Cargo.toml', 'Cargo.lock', 'pom.xml', 'build.gradle', 'build.gradle.kts', 'settings.gradle',
    'settings.gradle.kts', 'libs.versions.toml', 'build.sbt', 'composer.json', 'composer.lock',
    'Gemfile', 'Gemfile.lock', '*.gemspec', 'Package.swift', 'Package.resolved', 'Podfile',
    'Podfile.lock', 'Cartfile', 'Cartfile.resolved', 'pubspec.yaml', 'pubspec.lock', 'mix.exs',
    'mix.lock',
    '.npmrc', '.yarnrc', '.yarnrc.yml', '.pnpmfile.cjs', 'bunfig.toml', 'nuget.config', 'NuGet.Config',
    'packages.lock.json', 'global.json', '.netconfig', 'go.work', 'go.work.sum', 'requirements.in',
    'constraints.txt', 'pip.conf', '.piprc', 'poetry.toml', '.cargo/config.toml', 'Cargo.lock.orig',
    '.bundle/config', '.gemrc', 'gradle.properties', 'gradle-wrapper.properties',
    'maven-settings.xml', '.npmignore', 'Dockerfile', 'Dockerfile.*', 'docker-compose.yml',
    'docker-compose.yaml', 'devcontainer.json'
# GUARDED-MANIFESTS-END
)

foreach ($pat in $guarded) {
    # A pattern that NAMES a directory is matched against the PATH, not the
    # basename. `.cargo/config.toml` and `.bundle/config` were in this list for
    # three releases and could never fire: the basename of the first is
    # `config.toml` and of the second `config`, so neither ever equalled its own
    # pattern. Those two files decide where every package in the project comes
    # from, which is the case this list calls worse than a manifest edit.
    if ($pat.Contains('/')) {
        if (-not ($norm -like $pat -or $norm -like "*/$pat")) { continue }
    } elseif (-not ($name -like $pat)) {
        continue
    }
    if (Test-Path '.claude/allow-package-changes') { exit 0 }
    [Console]::Error.WriteLine("BLOCKED: '$filePath' is a package manifest/lockfile. Adding or changing packages requires approval in the feature's plan.md (or spec.md on Small-tier projects, which have no plan.md). If the approved spec covers it, ask the user to create .claude/allow-package-changes and retry.")
    exit 2
}
exit 0
