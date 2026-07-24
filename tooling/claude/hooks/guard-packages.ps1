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
try { $data = $inputJson | ConvertFrom-Json } catch { exit 0 }

$filePath = $data.tool_input.file_path
if (-not $filePath) { exit 0 }

# Split-Path handles backslashes but not forward slashes in every PowerShell
# version, and Claude Code reports both. Take the last segment either way.
$name = ($filePath -split '[\\/]')[-1]
if (-not $name) { exit 0 }

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
    'mix.lock'
# GUARDED-MANIFESTS-END
)

foreach ($pat in $guarded) {
    if ($name -like $pat) {
        if (Test-Path '.claude/allow-package-changes') { exit 0 }
        [Console]::Error.WriteLine("BLOCKED: '$filePath' is a package manifest/lockfile. Adding or changing packages requires approval in the feature's plan.md (or spec.md on Small-tier projects, which have no plan.md). If the approved spec covers it, ask the user to create .claude/allow-package-changes and retry.")
        exit 2
    }
}
exit 0
