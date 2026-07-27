#!/usr/bin/env sh
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
# The identical list lives in guard-installs.ps1; tests/framework-checks.sh fails
# the build if the two drift apart, and tests/fixtures/guard-cases.tsv runs both
# implementations over the same payloads so the code AROUND the list is compared
# too.

input=$(cat)

# JSON-EXTRACT-BEGIN
# Read one JSON string value out of the hook payload. This block is byte-identical
# in guard-installs.sh and guard-packages.sh and tests/framework-checks.sh fails
# the build if it drifts.
#
# It replaces `sed -n 's/.*"command"...\([^"]*\)"...'`, which was defeated by any
# command containing a double quote: `[^"]*` stops at the first one and nothing
# un-escapes `\"`, so the guard inspected a truncated string and
# `echo "installing deps" && npm install left-pad` -- ordinary shell, not an
# evasion technique -- was ALLOWED. A literal tab or newline did the same. The
# .ps1 twin used ConvertFrom-Json and was never affected, so this was also a
# platform split on exactly the hook macOS and Linux users are told to run.
#
# awk, not python3/node: this runs on every Bash call, awk is POSIX and present
# wherever the .sh hooks run, and one awk replaces the two forks (`tr` + `sed`)
# it removes. On Windows/MSYS, where fork is expensive, that matters.
#
# COST. The first string-aware version walked the payload one character at a time
# and built each string with `s = s c`. Appending to a string in awk copies it, so
# that is O(n^2): 200KB took 0.5s, 800KB took 11.7s and 1MB took 21.8s -- and a
# hook that exceeds Claude Code's timeout is a hook that is not enforcing, which
# is the same open door the rewrite was written to close, reached by a different
# route. This version does ONE `split()` on the quote character -- a single pass
# in C -- and then walks SEGMENTS. String bodies are skipped by index, never by
# character and never by concatenation, so only the structure (braces, colons)
# is inspected per character and only the one value we asked for is decoded.
#
# SCOPE. The value must be `tool_input.<key>`, matching what the .ps1 twin reads.
# Taking the first `command` key ANYWHERE in the payload made the two guards
# disagree on any payload that mentioned the key at another level, and the .sh
# hook -- the one macOS and Linux users are pointed at -- was the one that allowed.
#
# Exit status is the contract, and it is what makes failure closed:
#   0  value printed on stdout
#   3  no such key inside tool_input -- not a call this hook judges
#   4  key present but the payload is malformed, truncated, or undecodable
#
# Fail-closed details worth keeping: an unterminated string, a `\u` escape that does
# not decode, a value over 64KB, and ANY unbalanced brace at the end of the
# payload all exit 4. The last one is why a payload truncated after a readable
# value still blocks: the .ps1 twin's ConvertFrom-Json rejects all four truncation
# shapes, and a guard that fails closed on three of four is a guard with a shape.
JSON_EXTRACT='
function endesc(s,   L, k) {
  L = length(s); k = 0
  while (L - k >= 1 && substr(s, L - k, 1) == "\\") k++
  return k % 2
}
function cp2utf8(v) {
  if (v < 32) return " "
  if (v < 128) return sprintf("%c", v)
  if (v < 2048) return sprintf("%c%c", 192 + int(v / 64), 128 + v % 64)
  if (v >= 55296 && v < 57344) { bad = 1; return "" }
  return sprintf("%c%c%c", 224 + int(v / 4096), 128 + int(v / 64) % 64, 128 + v % 64)
}
function unesc(s,   out, L, p, q, e, u, d, v, x) {
  out = ""; L = length(s); p = 1
  while (p <= L) {
    q = p
    while (q <= L && substr(s, q, 1) != "\\") q++
    out = out substr(s, p, q - p)
    if (q > L) return out
    e = substr(s, q + 1, 1)
    if (e == "") { bad = 1; return "" }
    if (e == "u") {
      u = substr(s, q + 2, 4)
      if (length(u) < 4) { bad = 1; return "" }
      v = 0
      for (x = 1; x <= 4; x++) {
        d = index("0123456789abcdef", tolower(substr(u, x, 1)))
        if (d == 0) { bad = 1; return "" }
        v = v * 16 + d - 1
      }
      if (v == 0) { bad = 1; return "" }
      out = out cp2utf8(v)
      if (bad) return ""
      p = q + 6
      continue
    }
    if (e == "n" || e == "t" || e == "r" || e == "b" || e == "f") out = out " "
    else out = out e
    p = q + 2
  }
  return out
}
{ buf = buf $0 "\n" }
END {
  m = split(buf, seg, "\"")
  depth = 0; ti = 0; pend = ""; pdepth = -1; hit = 0; got = 0; got2 = 0
  k = 1
  while (1) {
    t = seg[k]; L = length(t)
    for (p = 1; p <= L; p++) {
      c = substr(t, p, 1)
      if (c == "{" || c == "[") {
        depth++
        if (c == "{" && pend == "tool_input" && pdepth == depth - 1) ti = depth
        pend = ""
      } else if (c == "}" || c == "]") {
        if (ti == depth) ti = 0
        depth--
        if (depth < 0) exit 4
        pend = ""
      } else if (c == ",") pend = ""
    }
    if (k >= m) break
    k++; st = k
    while (k < m && endesc(seg[k])) k++
    if (k >= m) exit 4
    nx = seg[k + 1]
    if (nx ~ /^[ \t\r\n]*:/) {
      if (st == k && length(seg[st]) <= 64) {
        pend = seg[st]
        if (index(pend, "\\")) { pend = unesc(pend); if (bad) exit 4 }
      } else pend = ""
      pdepth = depth
      # `hit` means the payload NAMES this key inside tool_input. Whether a
      # readable string comes back is decided below; if none does, the END block
      # exits 4 and the hook BLOCKS. It used to require the value to begin with a
      # quote (`r == ""`), so a NON-STRING value fell through to exit 3 -- "not a
      # call this hook judges" -- and `{"command":["npm","install","x"]}` was
      # ALLOWED here while the .ps1 twin blocked it. A value this parser cannot
      # read is a value it cannot judge, whatever its type.
      if (ti > 0 && depth == ti && (pend == key || (key2 != "" && pend == key2))) hit = 1
    } else {
      # No `got == 0` guard: the LAST occurrence of a duplicated key wins, which
      # is what ConvertFrom-Json does on the .ps1 side. First-wins here and
      # last-wins there meant a payload with two `command` keys was judged on a
      # different string per platform, so each implementation failed open in one
      # direction: `{"command":"npm install evil","command":"ls"}` was read as the
      # install by one and as `ls` by the other.
      if (ti > 0 && depth == ti && pdepth == depth && \
          (pend == key || (key2 != "" && pend == key2))) {
        v = seg[st]
        for (x = st + 1; x <= k; x++) v = v "\"" seg[x]
        if (length(v) > 65536) exit 4
        v = unesc(v)
        if (bad) exit 4
        if (pend == key) { val = v; got = 1 } else { val2 = v; got2 = 1 }
      }
      pend = ""
    }
    k++
  }
  if (depth != 0) exit 4
  if (got) { print val; exit 0 }
  if (got2) { print val2; exit 0 }
  exit hit ? 4 : 3
}
'
# JSON-EXTRACT-END

# LC_ALL=C so `substr` and `length` count BYTES. Under a UTF-8 locale some awks
# decode the whole payload to wide characters on every substr, which reintroduces
# the quadratic cost this block was rewritten to remove.
cmd=$(printf '%s' "$input" | LC_ALL=C awk -v key=command "$JSON_EXTRACT")
case $? in
    0) ;;
    3) exit 0 ;;
    *)  # The key is there and could not be read, or awk is missing. Either way the
        # guard cannot see what it is being asked to allow, and the old code's
        # `|| exit 0` is what turned that into a silent pass.
        echo "BLOCKED: the install guard could not read the command out of the hook payload, so it cannot tell whether this installs packages. This is a bug in the guard, not in your command -- report it with the command you ran. (If this machine has no \`awk\`, the .sh hooks cannot run at all; use the .ps1 hooks.)" >&2
        exit 2 ;;
esac
[ -n "$cmd" ] || exit 0

# Match whole word sequences, not substrings: `npm i` must block `npm i left-pad`
# without blocking `npm info`. Collapsing whitespace and padding both ends means
# a single glob does that, and it survives `cd app && npm install` chains.
#
# Shell metacharacters are collapsed to whitespace too, and that is not cosmetic.
# The parser rewrite above stopped quotes from truncating the extracted string,
# but the MATCHER still treated `"` and `'` as ordinary word characters, so the
# padded glob never fired on `sh -c "npm install evil"` or `eval "pip install x"`:
# the character before `npm` was a quote, not a space. The quote defeated the
# guard one layer below the parser that had just been fixed. `>` and `<` are
# deliberately left alone -- the perimeter block below reads them.
#
# ONE normalisation, several views of it. This hook runs on every Bash call and
# each avoided process is paid back thousands of times -- on Windows/MSYS a fork
# costs more than everything this script does with the result.
#
#   base   case-folded, quotes gone, backslashes folded to `/`, whitespace
#          squeezed. Shell separators (`;&|()` and the backtick) and redirections
#          (`>` `<`) are still there.
#   hay    base with the separators collapsed to spaces, for the install match.
#   hay2   hay with OPTION words, DIRECTORY prefixes and Windows executable
#          suffixes removed, so a tool and its subcommand separated by a flag
#          end up adjacent.
#   hay3   the same, except each option word takes the word AFTER it with it --
#          which is what an option with an ARGUMENT looks like.
#   psegs  base split INTO simple commands at those separators, for the
#          perimeter block, which has to judge each one on its own.
#
# Case is folded because PowerShell's `-like` is case-insensitive by nature and
# this hook's `case` is not, so `NPM INSTALL x` was blocked on Windows and allowed
# on macOS and Linux -- the platform split this pair keeps producing.
#
# (`\047` is the single quote and `\140` the backtick, spelled in octal so these
# lines do not have to be quoted three different ways to say them.)
#
# WHY THREE HAYSTACKS. The patterns are word SEQUENCES and real invocations put
# things between the words. `npm --silent install left-pad`, `npm --prefix ./app install x`,
# `npm -g install x`, `yarn --cwd app add zod`, `/usr/local/bin/npm install x` and
# `npm.cmd install x` are documented, ordinary forms -- not evasion syntax -- and
# every one of them was ALLOWED by both implementations.
#
# One stripping rule cannot cover both option shapes: dropping the following word
# is required for `--cwd app` and wrong for `--silent`. So there are two stripped
# haystacks and a pattern matching ANY of the three is a hit. Stripping into COPIES
# rather than in place is also what keeps `gradle --refresh-dependencies` and
# `npx --package` matchable -- those patterns contain the option, so they are
# found in `hay` itself.
base=$(printf '%s' "$cmd" | tr 'A-Z\t\n\r"\047\\' 'a-z     /' | tr -s ' /')
hay=" $(printf '%s' "$base" | tr -s ';&|(){}\140' ' ') "
STRIP_PATHS='s/[^ ]*\///g; s/\.cmd / /g; s/\.exe / /g; s/\.bat / /g'
hay2=" $(printf '%s' "$hay" | sed "s/ -[^ ]*/ /g; $STRIP_PATHS" | tr -s ' ') "
hay3=" $(printf '%s' "$hay" | sed "s/ -[^ ]* [^ ]*/ /g; $STRIP_PATHS" | tr -s ' ') "

# --- the guard guards itself, on this path too ------------------------------
# guard-packages.* blocks WRITES to the approval marker, the hook configuration
# and the hook scripts, and its comment explains why the block has to be there,
# at the moment of the write: /framework-doctor runs after setup and after
# upgrade, never during phase work. That argument applies verbatim here. Without
# this block `touch .claude/allow-package-changes`, `printf {} >
# .claude/settings.json` and `rm .claude/hooks/guard-packages.sh` all reach the
# shell untouched, and the file guard never sees them -- so the Bash hook this
# framework added to close the install path left the guard's own perimeter open.
#
# There is deliberately NO approval marker escape hatch, matching the file
# guard: the marker cannot authorise its own creation.
#
# `gate.*`, `.gate-sha256`, `check-stubs.*` and `.gate-stubs-baseline` are
# deliberately absent: they are pinned by CI (the `Pin the gate` step asserts that
# the pin NAMES every one of them that exists, which is what makes that delegation
# real -- it named only the POSIX halves for one release, so the .ps1 ratchet a
# Windows developer runs was covered by nothing) and owned in CODEOWNERS. Blocking
# them here would also block `chmod +x gate.sh` during setup.
#
# TWO structural rules, both learned from bypasses:
#
#   1. The command is split into simple commands at the shell separators FIRST.
#      The previous version inspected `${lnorm%%"$gp"*}` -- the text before the
#      FIRST occurrence of the path -- so reading the file earlier in the same
#      command moved the inspected window onto a prefix with no verb in it:
#      `ls .claude/settings.json && printf {} > .claude/settings.json` was
#      ALLOWED, and so was `cat .claude/hooks/g.sh; rm .claude/hooks/g.sh`.
#      Per segment, a read is its own command and shelters nothing after it.
#
#   2. The verb test is an ALLOWLIST. A blocklist of mutating verbs has to
#      enumerate every way to edit a file, and it missed the most ordinary ones:
#      `sed -i`, `/bin/rm` (the old test required a literal space before `rm`),
#      `git checkout --`, `perl -pi`, `python -c "open(...,'w')"`, `xargs rm`,
#      `find -delete` and `git clean -fd`. Inverting it means the next tool
#      nobody thought of is blocked rather than allowed, which is the direction
#      a guard is supposed to fail in.
#
# Reads still pass: `cat`, `grep -r`, `ls`, `diff`, `git diff`, `test -f`,
# `sh .claude/hooks/verify-guard.sh` and `cp .claude/settings.json /tmp/backup`
# are all allowed, because the doctor and every ordinary inspection need them.
psegs=$(printf '%s' "$base" | tr ';&|()\140' '\n\n\n\n\n\n')

perimeter_hit=""
# A here-doc redirect, not a pipe: the loop must run in THIS shell or
# `perimeter_hit` does not survive it.
while IFS= read -r seg; do
    # Trim the one leading/trailing space a separator leaves behind, so the first
    # word and the LAST word (which is what decides `cp`) are both readable.
    seg=${seg# }; seg=${seg% }
    [ -n "$seg" ] || continue
    # The specific paths first, so the block message can name the one that was
    # touched; bare `.claude` last, as the catch-all. Without it `git clean -fd
    # .claude` and `rm -rf .claude` named the DIRECTORY and matched none of the
    # three files inside it -- the whole perimeter removed in one command that
    # never mentioned a single guarded path.
    for gp in .claude/allow-package-changes .claude/settings .claude/hooks/ .claude; do
        case "$seg" in *"$gp"*) ;; *) continue ;; esac
        # A redirection whose target is the perimeter path is a write whatever
        # the leading verb is -- `cat x > .claude/settings.json` starts with a
        # verb on the allowlist. Everything before the LAST occurrence is
        # inspected, so `cat .claude/a > .claude/b` is caught while
        # `cat .claude/settings.json > /tmp/copy.json` (a read) is not.
        case "${seg%"$gp"*}" in *">"*) perimeter_hit=$gp; break ;; esac
        w=${seg%% *}; w=${w##*/}
        case "$w" in
            cat|ls|grep|egrep|fgrep|diff|cmp|head|tail|wc|stat|file|test|'['|od|xxd|\
            realpath|readlink|basename|dirname|sha256sum|shasum|md5sum)
                continue ;;
            awk)
                # `awk` is on the read allowlist because the doctor reads
                # settings.json with it -- but gawk's `-i inplace` WRITES, and
                # `awk -i inplace 's/a/b/' .claude/settings.json` therefore walked
                # straight through the allowlist. Any `-i` option disqualifies it;
                # `awk '/matcher/' .claude/settings.json` still reads.
                case " $seg " in *" -i"*) perimeter_hit=$gp; break ;; esac
                continue ;;
            sh|bash|dash|zsh|ksh|pwsh|powershell)
                # `sh .claude/hooks/verify-guard.sh` is how the doctor verifies.
                # `sh -c "rm .claude/hooks/x"` is not: the payload is another
                # command, and this loop never gets to see it as one.
                case " $seg " in *" -c "*|*" -command "*) perimeter_hit=$gp; break ;; esac
                continue ;;
            git)
                case " $seg " in
                    *" diff "*|*" status "*|*" log "*|*" show "*|*" ls-files "*|\
                    *" grep "*|*" blame "*|*" cat-file "*) continue ;;
                esac
                perimeter_hit=$gp; break ;;
            cp)
                # Copying the file OUT is a read, and backing up the hook config
                # before an upgrade is exactly what /framework-upgrade would do.
                # Copying something ONTO it is not, and the destination is the
                # last argument -- UNLESS the destination was named by an option,
                # which is the whole point of `cp -t DIR SRC...` and
                # `cp --target-directory=DIR SRC...`. With those, the last word is
                # a SOURCE file, so the test below inspected the wrong argument
                # and `cp -t .claude/hooks/ /tmp/x` overwrote a hook script while
                # returning 0. Any target-directory option means the destination
                # is not where this test looks, so judge it a write.
                #
                # Word by word, not one glob over the segment: `*" -"[!-]*"t "*`
                # spans spaces, so `cp -v .claude/settings.json /tmp/out.txt` --
                # an ordinary read -- matched on the `t ` ending an unrelated
                # argument. `-T` reads as `-t` here because the whole command was
                # case-folded upstream; that over-blocks `cp -T <perimeter> /tmp/x`
                # and over-blocking is the direction this guard fails in.
                _tflag=0
                set -f
                for _w in $seg; do
                    case "$_w" in
                        -t|--target-directory|--target-directory=*) _tflag=1; break ;;
                        --*) ;;
                        -*t) _tflag=1; break ;;
                    esac
                done
                set +f
                [ "$_tflag" = 0 ] || { perimeter_hit=$gp; break; }
                case "${seg##* }" in *"$gp"*) perimeter_hit=$gp; break ;; esac
                continue ;;
        esac
        perimeter_hit=$gp; break
    done
    [ -z "$perimeter_hit" ] || break
done <<EOF
$psegs
EOF

if [ -n "$perimeter_hit" ]; then
    echo "BLOCKED: this command writes to '$perimeter_hit', which is part of the package guard itself (its approval marker, its configuration, or its hook scripts). Only a human creates or edits these. If package changes are genuinely approved in the feature's plan.md (or spec.md at Small tier), ask the user to create the marker -- do not create it yourself. Reading these files is not blocked: cat, ls, grep, diff, head, tail, stat, test, git diff, running a hook with sh, and copying one OUT with cp all pass." >&2
    exit 2
fi

# INSTALL-COMMANDS-BEGIN
INSTALL_COMMANDS="npm install
npm i
npm add
npm ci
npm update
npx
npx --package
yarn add
yarn install
yarn up
yarn upgrade
yarn dlx
pnpm add
pnpm install
pnpm update
pnpm dlx
bun add
bun install
bunx
bun x
deno add
deno install
dotnet add package
dotnet package add
dotnet tool install
nuget install
paket add
pip install
pip3 install
pip download
pipx install
pipx run
uv add
uv pip install
uv tool install
uvx
poetry add
pipenv install
conda install
go get
go install
cargo add
cargo install
composer require
composer install
composer update
gem install
bundle add
bundle install
mvn dependency:get
gradle --refresh-dependencies
swift package resolve
pod install
mix deps.get
flutter pub add
dart pub add"
# INSTALL-COMMANDS-END

# Read the list line by line so patterns may contain spaces. A here-doc redirect
# (not a pipe) keeps the loop in this shell, so `hit` survives it.
hit=""
while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$hay" in
        *" $p "*) hit=$p; break ;;
    esac
    case "$hay2" in
        *" $p "*) hit=$p; break ;;
    esac
    case "$hay3" in
        *" $p "*) hit=$p; break ;;
    esac
done <<EOF
$INSTALL_COMMANDS
EOF

[ -n "$hit" ] || exit 0

[ -f ".claude/allow-package-changes" ] && exit 0

echo "BLOCKED: this command installs or updates packages ('$hit'). Adding or changing dependencies requires approval in the feature's plan.md (or spec.md on Small-tier projects, which have no plan.md). If the approved spec covers it, ask the user to create .claude/allow-package-changes and retry -- do not create it yourself." >&2
exit 2
