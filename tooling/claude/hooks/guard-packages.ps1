# PreToolUse hook: blocks edits to package manifests/lockfiles unless package
# changes have been approved for the current feature.
#
# Approval = the file .claude/allow-package-changes exists (create it when the
# feature's plan.md approves new packages; delete it after the phase commits).
#
# Exit 2 blocks the tool call and shows stderr to Claude; exit 0 allows it.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". A hook that dies fails OPEN.

$inputJson = [Console]::In.ReadToEnd()
try { $data = $inputJson | ConvertFrom-Json } catch { exit 0 }

$filePath = $data.tool_input.file_path
if (-not $filePath) { exit 0 }

$guarded = @('package.json', 'yarn.lock', 'package-lock.json', 'pnpm-lock.yaml',
             'packages.config', 'Directory.Packages.props')
$name = Split-Path $filePath -Leaf

if ($guarded -contains $name -or $name -like '*.csproj') {
    if (Test-Path '.claude/allow-package-changes') { exit 0 }
    [Console]::Error.WriteLine("BLOCKED: '$filePath' is a package manifest/lockfile. Adding or changing packages requires approval in the feature's plan.md. If the plan approves it, ask the user to create .claude/allow-package-changes and retry.")
    exit 2
}
exit 0
