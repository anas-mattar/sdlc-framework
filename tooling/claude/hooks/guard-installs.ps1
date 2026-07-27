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
# A command that is not a STRING is a command neither implementation can judge.
# `{"command":["npm","install","x"]}` used to be flattened by PowerShell's string
# coercion here and skipped entirely by the .sh parser -- blocked on one platform,
# allowed on the other, for the same payload. Fail closed on both, with the same
# message the .sh hook prints when its parser gives up.
if ($cmd -isnot [string]) {
    [Console]::Error.WriteLine("BLOCKED: the install guard could not read the command out of the hook payload, so it cannot tell whether this installs packages. This is a bug in the guard, not in your command -- report it with the command you ran.")
    exit 2
}

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
# ONE normalisation, several views of it, exactly as in the .sh twin:
#   $base  case-folded, quotes gone, backslashes folded to `/`, whitespace
#          squeezed; shell separators and redirections still present
#   $hay   $base with the separators collapsed to spaces, for the install match
#   $hay2  $hay with OPTION words, DIRECTORY prefixes and Windows executable
#          suffixes removed, so a tool and its subcommand separated by a flag end
#          up adjacent
#   $hay3  the same, except each option word takes the word AFTER it with it --
#          which is what an option with an ARGUMENT looks like
#   the perimeter loop below splits $base INTO simple commands at those separators
#
# WHY THREE HAYSTACKS.
# `npm --silent install x`, `npm --prefix ./app install x`, `npm -g install x`,
# `yarn --cwd app add zod`, `/usr/bin/npm install x` and `npm.cmd install x` are
# documented forms, and every one was ALLOWED. One rule cannot cover both option
# shapes -- dropping the following word is required for `--cwd app` and wrong for
# `--silent` -- so a pattern matching ANY of the three haystacks is a hit.
# Stripping into COPIES also keeps `gradle --refresh-dependencies` and
# `npx --package` matchable in $hay itself.
$base = ((($cmd -replace '[\s"\x27]+', ' ') -replace '\\', '/') -replace '/+', '/').ToLowerInvariant().Trim()
$hay = ' ' + ($base -replace '[\s;&|(){}\x60]+', ' ') + ' '
function Squeeze([string]$s) {
    ' ' + (((($s -replace '[^ ]*/', '') -replace '\.(cmd|exe|bat) ', ' ') -replace '\s+', ' ').Trim()) + ' '
}
$hay2 = Squeeze ($hay -replace ' -[^ ]*', ' ')
$hay3 = Squeeze ($hay -replace ' -[^ ]* [^ ]*', ' ')

# Three MORE views, with quotes and backslashes DELETED rather than translated.
#
# $base maps a quote to a SPACE. That is right for a quote at a word boundary --
# `npm "install" x` squeezes back to `npm install x` -- and exactly wrong for a
# quote INSIDE a word, which the shell removes rather than treating as a separator.
# `npm in"stall" x` became `npm in stall x`, so the word `install` never existed in
# any haystack and no pattern could match. A backslash had the same problem from
# the other direction: $base maps it to `/` for path stripping, so `n\pm install x`
# became `n/pm install x` and the `[^ ]*/` rule then deleted the whole word.
#
# Both are ordinary shell:
#     sh -c 'echo npm in"stall" x'   ->  npm install x
#     sh -c 'echo n\pm install x'    ->  npm install x
#
# Deleting cannot create a false positive that translating avoids: it only joins
# words the shell also joins. Six views total, and a pattern found in any is a hit.
# This MUST stay in step with guard-installs.sh, which builds hay4/hay5/hay6 the
# same way; the guard-cases fixture runs both implementations over the same
# payloads so a divergence here fails the build.
$joined = (($cmd -replace '[\s]+', ' ') -replace '["\x27\\]', '').ToLowerInvariant().Trim()
$hay4 = ' ' + ($joined -replace '[\s;&|(){}\x60]+', ' ') + ' '
$hay5 = Squeeze ($hay4 -replace ' -[^ ]*', ' ')
$hay6 = Squeeze ($hay4 -replace ' -[^ ]* [^ ]*', ' ')

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
# `gate.*`, `.gate-sha256`, `check-stubs.*` and `.gate-stubs-baseline` are
# deliberately absent: they are pinned by CI (the pin step asserts the pin NAMES
# every one of them that exists -- it named only the POSIX halves for one release,
# so the .ps1 ratchet was covered by nothing) and owned in CODEOWNERS, and blocking
# them here would block `chmod +x gate.sh` during setup.
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
              'basename', 'dirname', 'sha256sum', 'shasum', 'md5sum')
$shellVerbs = @('sh', 'bash', 'dash', 'zsh', 'ksh', 'pwsh', 'powershell')
$gitReads = @('diff', 'status', 'log', 'show', 'ls-files', 'grep', 'blame', 'cat-file')
$perimeterHit = ''
# Segments from BOTH normalisations, for the same reason the install matcher needs
# six haystacks: $base maps a quote to a space, so `rm -rf .cl'a'ude` became
# `rm -rf .cl a ude` and no segment contained the literal `.claude`. $joined deletes
# the quote instead, which is what the shell does. A hit in either is a hit.
foreach ($rawSeg in (($base -split '[;&|()\x60]') + ($joined -split '[;&|()\x60]'))) {
    $seg = $rawSeg.Trim()
    if ($seg -eq '') { continue }

    # A GLOB NEVER CONTAINS THE STRING IT MATCHES, so the .Contains() test below is
    # blind to `rm -rf .cla*` -- which removes the whole perimeter while never
    # mentioning `.claude`, and is ordinary shell rather than evasion syntax. Look
    # for a word carrying a glob metacharacter whose non-glob PREFIX is a prefix of
    # a perimeter path: `.cla*` -> `.cla` is a prefix of `.claude` (hit); `dist/*`
    # -> `dist/` is not (allowed). A bare `*` has an empty prefix, which is a prefix
    # of everything, so it is treated as a hit -- `rm -rf *` at the project root
    # really would take the perimeter, and over-blocking is this guard's documented
    # direction of failure. Kept in step with the `_glob_hit` block in the .sh twin.
    if ($seg -match '[*?\[]') {
        $globWord = $null
        foreach ($gw in ($seg -split ' ')) {
            if ($gw -eq '' -or $gw.StartsWith('-')) { continue }
            if ($gw -notmatch '[*?\[]') { continue }
            $pre = ($gw -split '[*?\[]')[0]
            if ($pre.StartsWith('./')) { $pre = $pre.Substring(2) }
            foreach ($pp in @('.claude', '.git/hooks')) {
                if ($pp.StartsWith($pre)) { $globWord = $pp; break }
            }
            if ($globWord) { break }
        }
        if ($globWord) {
            $gv = ($seg -split ' ')[0]
            if ($gv.Contains('/')) { $gv = $gv.Substring($gv.LastIndexOf('/') + 1) }
            if ($readVerbs -notcontains $gv -and $gv -ne 'find') {
                $perimeterHit = "$globWord (matched by a glob: $seg)"
                break
            }
        }
    }

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
        if ($w -eq 'awk') {
            # `awk` reads -- the doctor reads settings.json with it -- but gawk's
            # `-i inplace` WRITES, so any `-i` option disqualifies it from the
            # read allowlist. `awk '/matcher/' .claude/settings.json` still reads.
            if ($padded -match ' -i') { $perimeterHit = $gp; break }
            continue
        }
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
            # and the destination is the last argument -- UNLESS an option named
            # it. `cp -t DIR SRC...` and `cp --target-directory=DIR SRC...` put
            # the destination FIRST, so the last word is a source file and this
            # test inspected the wrong argument: `cp -t .claude/hooks/ /tmp/x`
            # overwrote a hook script and returned 0.
            # ENUMERATING OPTION SPELLINGS LOSES. The list above was `-t`,
            # `--target-directory` and `-*t `, and GNU cp also accepts the directory
            # ATTACHED to the short option, plus any unambiguous long-option
            # abbreviation. Both of these overwrote a hook:
            #     cp -t.claude/hooks /tmp/guard-packages.sh
            #     cp --targ=.claude/hooks/ /tmp/guard-packages.sh
            # So the test is inverted: ANY option at all means treat the perimeter
            # path as a destination wherever it sits. The cost is that
            # `cp -v <perimeter> /tmp/out` is now blocked too, which is the
            # direction this guard is documented to fail in; `cp <perimeter>
            # /tmp/out` with no options still reads fine, and that is the form the
            # block message advertises. Kept in step with the .sh twin.
            $hasOpt = $false
            foreach ($cw in ($seg -split ' ')) { if ($cw.StartsWith('-')) { $hasOpt = $true; break } }
            if ($hasOpt) { $perimeterHit = $gp; break }
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
    'npm install', 'npm i', 'npm add', 'npm ci', 'npm update', 'npx', 'npx --package', 'npm exec', 'npm x',
    'yarn add', 'yarn install', 'yarn up', 'yarn upgrade', 'yarn dlx',
    'pnpm add', 'pnpm install', 'pnpm update', 'pnpm dlx',
    'bun add', 'bun install', 'bunx', 'bun x',
    'deno add', 'deno install', 'dotnet add package', 'dotnet package add',
    'dotnet tool install', 'dotnet restore', 'dotnet tool restore',
    'nuget install', 'paket add', 'pip install', 'pip3 install', 'pip download',
    'pipx install', 'pipx run',
    'uv add', 'uv pip install', 'uv tool install', 'uvx',
    'poetry add', 'pipenv install', 'conda install',
    'go mod tidy', 'go mod download',
    'go get', 'go install', 'cargo add', 'cargo install', 'cargo fetch',
    'composer require', 'composer install', 'composer update',
    'gem install', 'bundle add', 'bundle install',
    'mvn dependency:get', 'gradle --refresh-dependencies',
    'swift package resolve', 'pod install', 'mix deps.get',
    'flutter pub add', 'dart pub add'
# INSTALL-COMMANDS-END
)

foreach ($p in $installCommands) {
    if (($hay  -like "* $p *") -or ($hay2 -like "* $p *") -or ($hay3 -like "* $p *") -or
        ($hay4 -like "* $p *") -or ($hay5 -like "* $p *") -or ($hay6 -like "* $p *")) {
        if (Test-Path '.claude/allow-package-changes') { exit 0 }
        [Console]::Error.WriteLine("BLOCKED: this command installs or updates packages ('$p'). Adding or changing dependencies requires approval in the feature's plan.md (or spec.md on Small-tier projects, which have no plan.md). If the approved spec covers it, ask the user to create .claude/allow-package-changes and retry -- do not create it yourself.")
        exit 2
    }
}
exit 0
