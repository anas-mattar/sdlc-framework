#!/usr/bin/env sh
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
# It covers RESOLUTION as well as declaration: .npmrc, .yarnrc.yml, nuget.config,
# pip.conf, .bundle/config and friends decide WHERE packages come from. A registry
# redirect is worse than a manifest edit -- it repoints every dependency in the
# project at once while the manifest and the lockfile still look pristine, so the
# diff a reviewer reads says nothing changed. go.work, global.json and
# packages.lock.json pin resolution the same way. Dockerfiles install packages
# outside every package manager the rest of this list knows about.
#
# The identical list lives in guard-packages.ps1; tests/framework-checks.sh fails
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
      if (ti > 0 && depth == ti && (pend == key || (key2 != "" && pend == key2))) {
        r = nx; sub(/^[ \t\r\n]*:[ \t\r\n]*/, "", r)
        if (r == "") hit = 1
      }
    } else {
      if (ti > 0 && depth == ti && pdepth == depth && \
          ((pend == key && got == 0) || (key2 != "" && pend == key2 && got2 == 0))) {
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

# ONE pass for both keys. NotebookEdit is in this hook's matcher and reports its
# target as `notebook_path`, so file_path alone made every NotebookEdit call
# invisible to the guard -- but running the extractor twice meant a payload with
# no file_path (every Write of a notebook) was scanned end to end twice.
# `file_path` wins when both are present, matching the .ps1 twin.
#
# LC_ALL=C so `substr` and `length` count BYTES. Under a UTF-8 locale some awks
# decode the whole payload to wide characters on every substr, which reintroduces
# the quadratic cost the extractor was rewritten to remove.
file_path=$(printf '%s' "$input" | LC_ALL=C awk -v key=file_path -v key2=notebook_path "$JSON_EXTRACT")
case $? in
    0) ;;
    3) exit 0 ;;
    *)  # The key is there and could not be read, or awk is missing. Either way the
        # guard cannot see which file it is being asked to allow, and the old
        # code's `|| exit 0` is what turned that into a silent pass.
        echo "BLOCKED: the package guard could not read the target path out of the hook payload, so it cannot tell whether this edits a package manifest. This is a bug in the guard, not in your edit -- report it with the path you were editing. (If this machine has no \`awk\`, the .sh hooks cannot run at all; use the .ps1 hooks.)" >&2
        exit 2 ;;
esac
[ -n "$file_path" ] || exit 0

# Normalise the path once, for BOTH the self-guard below and the manifest match.
# Claude Code reports Windows paths with backslashes, and they arrive JSON-escaped
# as `\\`, so folding them one-for-one yields `C://proj//.claude//settings.json`.
# Squeeze the repeats or none of the patterns below match on Windows -- the
# platform this guard is shipped configured for.
#
# Fold and squeeze in ONE sed rather than two `tr` calls. This hook runs on every
# Edit and Write, so each avoided process is paid back thousands of times -- and on
# Windows/MSYS, where fork is expensive, a chain of small helpers is what makes a
# long verify-guard run stall partway through.
norm=$(printf '%s' "$file_path" | sed 's|\\|/|g; s|//*|/|g')

# GUARDED-MANIFESTS-BEGIN
GUARDED="package.json package-lock.json npm-shrinkwrap.json yarn.lock
pnpm-lock.yaml pnpm-workspace.yaml bun.lockb bun.lock deno.json deno.jsonc
deno.lock *.csproj *.fsproj *.vbproj *.nuspec packages.config
Directory.Packages.props Directory.Build.props paket.dependencies paket.lock
pyproject.toml requirements*.txt *-requirements.txt Pipfile Pipfile.lock
poetry.lock uv.lock setup.py setup.cfg environment.yml go.mod go.sum
Cargo.toml Cargo.lock pom.xml build.gradle build.gradle.kts settings.gradle
settings.gradle.kts libs.versions.toml build.sbt composer.json composer.lock
Gemfile Gemfile.lock *.gemspec Package.swift Package.resolved Podfile
Podfile.lock Cartfile Cartfile.resolved pubspec.yaml pubspec.lock mix.exs
mix.lock
.npmrc .yarnrc .yarnrc.yml .pnpmfile.cjs bunfig.toml nuget.config NuGet.Config
packages.lock.json global.json .netconfig go.work go.work.sum requirements.in
constraints.txt pip.conf .piprc poetry.toml .cargo/config.toml Cargo.lock.orig
.bundle/config .gemrc gradle.properties gradle-wrapper.properties
maven-settings.xml .npmignore Dockerfile Dockerfile.* docker-compose.yml
docker-compose.yaml devcontainer.json"
# GUARDED-MANIFESTS-END

# Match case-insensitively, by folding both sides once. `case` is case-sensitive
# and PowerShell's `-like` is not, so the two guards used to disagree: `Package.json`
# was blocked on Windows and allowed on macOS/Linux. On case-insensitive macOS --
# which is exactly where this framework directs users to the .sh hook -- that wrote
# the real manifest straight past the guard. The parity self-test compares the
# pattern STRINGS, so it passed throughout. Fold once, not once per pattern: this
# hook runs on every Edit and Write.
# One `tr` for both, split back apart with parameter expansion -- see the note
# above about process count. The blank separator line cannot appear inside either
# value, so the split is unambiguous.
folded=$(printf '%s\n\n%s' "$norm" "$GUARDED" | tr 'A-Z' 'a-z')
lnorm=${folded%%"

"*}
lguarded=${folded#*"

"}

# --- the guard guards itself ------------------------------------------------
# Everything this control depends on lives inside the perimeter the agent
# controls: the approval marker, the hook configuration, and the hook script. None
# of them is a package manifest, so without this block a blocked agent can simply
# Write `.claude/allow-package-changes` -- whose exact filename the block message
# below helpfully supplies -- and the guard is permanently open in one tool call.
# /framework-doctor check 5 finds the residue afterwards, but it runs after setup
# and after upgrade, never during phase work, and the marker can be deleted once
# the edit has landed. So the block has to be here, at the moment of the write.
#
# This block sits BELOW the fold and matches the folded path. It used to sit above
# it, matching `$norm`, which recreated -- for the guard's own configuration -- the
# exact bug the fold nine lines up was added to fix: `.claude/Settings.json` and
# `.claude/Allow-Package-Changes` were ALLOWED, and on case-insensitive macOS they
# are the same file. One Write disabled both hooks. The manifest list was tested
# for case (`Package.json`); this was not, which is why it shipped.
case "$lnorm" in
    *.claude/allow-package-changes|*.claude/settings*.json|*.claude/hooks/*)
        echo "BLOCKED: '$file_path' is part of the package guard itself (its approval marker, its configuration, or its hook script). Only a human creates or edits these. If package changes are genuinely approved in the feature's plan.md (or spec.md at Small tier), ask the user to create the marker -- do not create it yourself." >&2
        exit 2
        ;;
esac

# Match on the basename, not the whole path: a directory called `vendor/Gemfile/`
# is not a manifest, and `docs/notes-package.json` should not slip through a
# suffix match. Both separators are already normalised to `/` above.
lname=${lnorm##*/}

# `set -f` is required: without it the `for` list undergoes pathname expansion,
# so `*.csproj` silently becomes whatever .csproj files happen to be in the
# working directory -- and the pattern itself is lost.
set -f
for pat in $lguarded; do
    # A pattern that NAMES a directory is matched against the path, not the
    # basename. `.cargo/config.toml` and `.bundle/config` were in this list for
    # three releases and could never fire: the basename of the first is
    # `config.toml` and of the second `config`, so neither ever equalled its own
    # pattern. Those two files decide where every package in the project comes
    # from, which is the case this list calls worse than a manifest edit.
    case "$pat" in
        */*) case "$lnorm" in $pat|*/$pat) ;; *) continue ;; esac ;;
        *)   case "$lname" in $pat) ;; *) continue ;; esac ;;
    esac
    [ -f ".claude/allow-package-changes" ] && exit 0
    echo "BLOCKED: '$file_path' is a package manifest/lockfile. Adding or changing packages requires approval in the feature's plan.md (or spec.md on Small-tier projects, which have no plan.md). If the approved spec covers it, ask the user to create .claude/allow-package-changes and retry." >&2
    exit 2
done
set +f

exit 0
