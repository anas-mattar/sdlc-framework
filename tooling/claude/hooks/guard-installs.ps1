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
# the build if the two drift apart, and tests/fixtures/guard-cases.tsv runs BOTH
# implementations over the same payloads so the code around the list is compared
# too. Every rule below is written to be behaviourally identical to the .sh twin,
# not merely similar -- a divergence here is a platform-specific hole.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". A hook that dies fails OPEN.

$inputJson = [Console]::In.ReadToEnd()
# Fail CLOSED when the payload names a command this hook cannot read. `catch { exit 0 }`
# treated a malformed payload as nothing to judge, which is the same silent pass the
# .sh hook's `|| exit 0` gave -- see the JSON-EXTRACT block there. A payload with no
# `command` at all is still allowed: that is a tool this hook does not judge.
$data = $null
try { $data = $inputJson | ConvertFrom-Json } catch {
    if ($inputJson -match '"command"') {
        [Console]::Error.WriteLine("BLOCKED: the install guard could not read the command out of the hook payload, so it cannot tell whether this installs packages. This is a bug in the guard, not in your command -- report it with the command you ran.")
        exit 2
    }
    exit 0
}

# Only Bash calls carry a command. Anything else is not ours to judge.
$cmd = $data.tool_input.command
if (-not $cmd) { exit 0 }

# Match whole word sequences, not substrings: `npm i` must block `npm i left-pad`
# without blocking `npm info`. Collapsing whitespace and padding both ends means
# a single -like does that, and it survives `cd app && npm install` chains.
#
# Shell metacharacters are collapsed to whitespace too, and that is not cosmetic:
# the MATCHER used to treat a quote as an ordinary word character, so the padded
# match never fired on `sh -c "npm install evil"` -- the character before `npm`
# was a quote, not a space. `\x27` is the single quote and `\x60` the backtick.
# `>` and `<` are deliberately left alone; the perimeter block below reads them.
#
# ONE normalisation, two views of it, exactly as in the .sh twin:
#   $base  case-folded, quotes gone, backslashes folded to `/`, whitespace
#          squeezed; shell separators and redirections still present
#   $hay   $base with the separators collapsed to spaces, for the install match
#   the perimeter loop below splits $base INTO simple commands at those separators
$base = ((($cmd -replace '[\s"\x27]+', ' ') -replace '\\', '/') -replace '/+', '/').ToLowerInvariant().Trim()
$hay = ' ' + ($base -replace '[\s;&|(){}\x60]+', ' ') + ' '

# --- the guard guards itself, on this path too ------------------------------
# guard-packages.* blocks WRITES to the approval marker, the hook configuration and
# the hook scripts, and its comment explains why the block has to be there, at the
# moment of the write: /framework-doctor runs after setup and after upgrade, never
# during phase work. That argument applies verbatim here. Without this block
# `touch .claude/allow-package-changes`, `printf {} > .claude/settings.json` and
# `rm .claude/hooks/guard-packages.sh` all reach the shell untouched, and the file
# guard never sees them. There is deliberately NO approval marker escape hatch,
# matching the file guard: the marker cannot authorise its own creation.
#
# `gate.sh`, `.gate-sha256`, `check-stubs.*` and `.gate-stubs-baseline` are
# deliberately absent: they are pinned by CI (the pin step now asserts the pin
# NAMES them) and owned in CODEOWNERS, and blocking them here would block
# `chmod +x gate.sh` during setup.
#
# TWO structural rules, both learned from bypasses, both mirrored from the .sh:
#
#   1. The command is split into simple commands at the shell separators FIRST.
#      Inspecting only the text before the FIRST occurrence of the path let a
#      read earlier in the same command move the window off the write:
#      `ls .claude/settings.json && printf {} > .claude/settings.json` was
#      ALLOWED, and so was `cat .claude/hooks/g.sh; rm .claude/hooks/g.sh`.
#
#   2. The verb test is an ALLOWLIST. A blocklist of mutating verbs missed the
#      most ordinary ones -- `sed -i`, `/bin/rm`, `git checkout --`, `perl -pi`,
#      `xargs rm`, `find -delete` -- so the next tool nobody thought of is now
#      blocked rather than allowed.
$readOnly = @('cat', 'ls', 'grep', 'egrep', 'fgrep', 'diff', 'cmp', 'head', 'tail',
              'wc', 'stat', 'file', 'test', '[', 'od', 'xxd', 'realpath', 'readlink',
              'basename', 'dirname', 'sha256sum', 'shasum', 'md5sum', 'awk')
$shellVerbs = @('sh', 'bash', 'dash', 'zsh', 'ksh', 'pwsh', 'powershell')
$gitReads = @('diff', 'status', 'log', 'show', 'ls-files', 'grep', 'blame', 'cat-file')
$perimeterHit = ''
foreach ($rawSeg in ($base -split '[;&|()\x60]')) {
    $seg = $rawSeg.Trim()
    if ($seg -eq '') { continue }
    # The specific paths first, so the block message can name the one that was
    # touched; bare `.claude` last, as the catch-all. Without it `git clean -fd
    # .claude` named the DIRECTORY and matched none of the three files inside it.
    foreach ($gp in @('.claude/allow-package-changes', '.claude/settings', '.claude/hooks/', '.claude')) {
        if (-not $seg.Contains($gp)) { continue }
        # A redirection whose target is the perimeter path is a write whatever the
        # leading verb is. Everything before the LAST occurrence is inspected, so
        # `cat .claude/a > .claude/b` is caught while
        # `cat .claude/settings.json > /tmp/copy.json` (a read) is not.
        if ($seg.Substring(0, $seg.LastIndexOf($gp)).Contains('>')) { $perimeterHit = $gp; break }
        $w = $seg.Split(' ')[0]
        $slash = $w.LastIndexOf('/')
        if ($slash -ge 0) { $w = $w.Substring($slash + 1) }
        $padded = " $seg "
        if ($readOnly -contains $w) { continue }
        if ($shellVerbs -contains $w) {
            # `sh .claude/hooks/verify-guard.sh` is how the doctor verifies.
            # `sh -c "rm .claude/hooks/x"` is not: the payload is another command,
            # and this loop never gets to see it as one.
            if ($padded.Contains(' -c ') -or $padded.Contains(' -command ')) { $perimeterHit = $gp; break }
            continue
        }
        if ($w -eq 'git') {
            $gitOk = $false
            foreach ($sub in $gitReads) { if ($padded.Contains(" $sub ")) { $gitOk = $true } }
            if ($gitOk) { continue }
            $perimeterHit = $gp; break
        }
        if ($w -eq 'cp') {
            # Copying the file OUT is a read; copying something ONTO it is not,
            # and the destination is the last argument.
            $words = $seg.Split(' ')
            if ($words[$words.Count - 1].Contains($gp)) { $perimeterHit = $gp; break }
            continue
        }
        $perimeterHit = $gp
        break
    }
    if ($perimeterHit -ne '') { break }
}
if ($perimeterHit -ne '') {
    [Console]::Error.WriteLine("BLOCKED: this command writes to '$perimeterHit', which is part of the package guard itself (its approval marker, its configuration, or its hook scripts). Only a human creates or edits these. If package changes are genuinely approved in the feature's plan.md (or spec.md at Small tier), ask the user to create the marker -- do not create it yourself. Reading these files is not blocked: cat, ls, grep, diff, head, tail, stat, test, git diff, running a hook with sh, and copying one OUT with cp all pass.")
    exit 2
}

$installCommands = @(
# INSTALL-COMMANDS-BEGIN
    'npm install', 'npm i', 'npm add', 'npm ci', 'npm update', 'npx', 'npx --package',
    'yarn add', 'yarn install', 'yarn up', 'yarn upgrade', 'yarn dlx',
    'pnpm add', 'pnpm install', 'pnpm update', 'pnpm dlx',
    'bun add', 'bun install', 'bunx', 'bun x',
    'deno add', 'deno install', 'dotnet add package', 'dotnet package add',
    'dotnet tool install',
    'nuget install', 'paket add', 'pip install', 'pip3 install', 'pip download',
    'pipx install', 'pipx run',
    'uv add', 'uv pip install', 'uv tool install', 'uvx',
    'poetry add', 'pipenv install', 'conda install',
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
