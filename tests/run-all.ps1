# The framework's own gate -- Windows entry point.
#
#     .\tests\run-all.ps1
#
# This is a LAUNCHER, not a second test suite. The checks live in run-all.sh and
# are deliberately written once: a PowerShell reimplementation would be a second
# source of truth for what "the framework passes" means, and the two would drift.
# CI runs run-all.sh directly (.github/workflows/selftest.yml), so what this script
# runs locally is byte-for-byte what CI runs.
#
# It finds the POSIX shell that Git for Windows already installs -- if you can run
# `git`, you have `sh`, even when it is not on PATH.
#
# run-all.sh prints the EXIT: <code> line; this script propagates that exit code.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Find-Sh {
    # 1. Already on PATH (Git Bash shell, WSL, MSYS2, a dev shell).
    $onPath = Get-Command sh -CommandType Application -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    # 2. Next to git.exe -- Git for Windows ships <install>\bin\sh.exe and
    #    <install>\usr\bin\sh.exe, while git.exe lives in <install>\cmd or
    #    <install>\mingw64\bin. Walk up from git.exe rather than guessing.
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
    if ($git) {
        $dir = Split-Path -Parent $git.Source
        for ($i = 0; $i -lt 3 -and $dir; $i++) {
            foreach ($rel in 'bin\sh.exe', 'usr\bin\sh.exe') {
                $candidate = Join-Path $dir $rel
                if (Test-Path -LiteralPath $candidate) { return $candidate }
            }
            $dir = Split-Path -Parent $dir
        }
    }

    # 3. Default install locations, last resort.
    foreach ($candidate in @(
        "$env:ProgramFiles\Git\bin\sh.exe",
        "${env:ProgramFiles(x86)}\Git\bin\sh.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\sh.exe"
    )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    return $null
}

$sh = Find-Sh
if (-not $sh) {
    Write-Host "No POSIX shell found. The self-tests are written in sh."
    Write-Host "Install Git for Windows (https://git-scm.com/download/win) -- it ships sh.exe --"
    Write-Host "or run the suite under WSL. Looked on PATH, beside git.exe, and in the"
    Write-Host "default install locations."
    Write-Host "EXIT: 127"
    exit 127
}

Write-Host "using shell: $sh"
Write-Host ""

# The suite cd's to the repo root itself; pass a path relative to it so the
# argument survives the Win32 -> MSYS path translation unambiguously.
Push-Location $root
try {
    & $sh "tests/run-all.sh"
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

exit $code
