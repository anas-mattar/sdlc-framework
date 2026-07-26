# PreToolUse hook: blocks package-INSTALLING shell commands.
#
# guard-packages.* watches Edit|Write against manifest FILES. That is the least
# likely way an agent adds a dependency. `npm install left-pad`, `yarn add`,
# `dotnet add package`, `pip install`, `go get`, `cargo add` all rewrite the
# manifest and the lockfile through a Bash call the file guard never sees -- so a
# project could run with GUARD: verified while every real install path stood open.
#
# Approval is the same as the file guard's: the file .claude/allow-package-changes
# exists. Same exit codes: 2 blocks the tool call and shows stderr to Claude,
# 0 allows it.
#
# The identical list lives in guard-installs.sh; tests/framework-checks.sh fails
# the build if the two drift apart.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". A hook that dies fails OPEN.

$inputJson = [Console]::In.ReadToEnd()
try { $data = $inputJson | ConvertFrom-Json } catch { exit 0 }

# Only Bash calls carry a command. Anything else is not ours to judge.
$cmd = $data.tool_input.command
if (-not $cmd) { exit 0 }

# Match whole word sequences, not substrings: `npm i` must block `npm i left-pad`
# without blocking `npm info`. Collapsing whitespace and padding both ends means
# a single -like does that, and it survives `cd app && npm install` chains.
$norm = ($cmd -replace '\s+', ' ').Trim()
$hay = " $norm "

$installCommands = @(
# INSTALL-COMMANDS-BEGIN
    'npm install', 'npm i', 'npm add', 'npm ci', 'npm update', 'npx --package',
    'yarn add', 'yarn install', 'yarn up', 'yarn upgrade',
    'pnpm add', 'pnpm install', 'pnpm update', 'bun add', 'bun install',
    'deno add', 'deno install', 'dotnet add package', 'dotnet package add',
    'nuget install', 'paket add', 'pip install', 'pip3 install', 'pip download',
    'uv add', 'uv pip install', 'poetry add', 'pipenv install', 'conda install',
    'go get', 'go install', 'cargo add', 'cargo install',
    'composer require', 'composer install', 'composer update',
    'gem install', 'bundle add', 'bundle install',
    'mvn dependency:get', 'gradle --refresh-dependencies',
    'swift package resolve', 'pod install', 'mix deps.get',
    'flutter pub add', 'dart pub add'
# INSTALL-COMMANDS-END
)

foreach ($p in $installCommands) {
    if ($hay -like "* $p *") {
        if (Test-Path '.claude/allow-package-changes') { exit 0 }
        [Console]::Error.WriteLine("BLOCKED: this command installs or updates packages ('$p'). Adding or changing dependencies requires approval in the feature's plan.md (or spec.md on Small-tier projects, which have no plan.md). If the approved spec covers it, ask the user to create .claude/allow-package-changes and retry -- do not create it yourself.")
        exit 2
    }
}
exit 0
