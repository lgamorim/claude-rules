<#
.SYNOPSIS
    Check this repository against the maintenance rules in its root CLAUDE.md
    that a script can decide, so the reviewer no longer checks them by eye.

.DESCRIPTION
    Runs four checks and prints one `file:line: message` line per failure:

    1. Imports resolve. Every `@path` line in a profile manifest
       (`.claude/rules/profiles/*.md` except README.md) and in an example's
       `examples/*/CLAUDE.md` names an existing file. A line counts as an
       import when, outside a fenced code block, it holds only `@` and a
       path — the form every manifest in this repository uses.
    2. No dead weight. Every module under `.claude/rules/core`, `archetype`,
       and `overlays` is imported by at least one profile manifest, or is an
       overlay whose path `overlays/<name>.md` appears in
       `.claude/rules/profiles/README.md`, which documents the opt-ins.
    3. Hygiene. Every line the diff from the merge base of -Base to HEAD
       adds to a Markdown file is at most 80 characters, unless it is a
       table row (its first non-blank character is `|`), and no line it
       adds to any file ends in whitespace. Only committed changes count:
       the range is the one the reviewer reads, `git diff <Base>...HEAD`.
    4. Profile tables agree. The table whose header starts with `Profile`
       in `README.md` and the one in `.claude/rules/profiles/README.md` hold
       the same rows, comparing cell text with Markdown links reduced to
       their link text.

    Exits 0 when every check passes and 1 otherwise.

.EXAMPLE
    ./tools/check.ps1

.EXAMPLE
    ./tools/check.ps1 -Base origin/master
#>
[CmdletBinding()]
param(
    [string] $Base = 'master'
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$rulesRoot = Join-Path $repoRoot '.claude/rules'
$failures = New-Object System.Collections.Generic.List[string]

function Get-RepoPath([string] $Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    $full.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
}

function Add-Failure([string] $Path, [int] $Line, [string] $Message) {
    $failures.Add("${Path}:${Line}: $Message")
}

# -Encoding utf8 is explicit because Windows PowerShell 5.1 misreads a
# BOM-less UTF-8 file as ANSI, which would miscount line lengths.
function Read-Lines([string] $Path) {
    @(Get-Content -LiteralPath $Path -Encoding utf8)
}

# Whole-line imports outside fenced code blocks, as
# @{ Line; Target; Resolved } records with Resolved an absolute path.
function Get-Imports([string] $Path) {
    $lines = Read-Lines $Path
    $inFence = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence -or $lines[$i] -notmatch '^\s*@(\S+)\s*$') { continue }
        $target = $Matches[1]
        [pscustomobject]@{
            Line     = $i + 1
            Target   = $target
            Resolved = [System.IO.Path]::GetFullPath(
                (Join-Path (Split-Path $Path) $target))
        }
    }
}

function Get-ProfileManifests {
    Get-ChildItem (Join-Path $rulesRoot 'profiles') -Filter '*.md' |
        Where-Object { $_.Name -ne 'README.md' } |
        Sort-Object Name
}

# --- 1. Imports resolve ------------------------------------------------------

$importers = @(Get-ProfileManifests) + @(
    Get-ChildItem (Join-Path $repoRoot 'examples') -Directory |
        ForEach-Object { Join-Path $_.FullName 'CLAUDE.md' } |
        Where-Object { Test-Path -LiteralPath $_ } |
        ForEach-Object { Get-Item -LiteralPath $_ })

foreach ($file in $importers) {
    foreach ($import in @(Get-Imports $file.FullName)) {
        if (-not (Test-Path -LiteralPath $import.Resolved -PathType Leaf)) {
            Add-Failure (Get-RepoPath $file.FullName) $import.Line `
                "import '@$($import.Target)' does not resolve to a file"
        }
    }
}

# --- 2. No dead weight -------------------------------------------------------

$imported = @{}
foreach ($manifest in Get-ProfileManifests) {
    foreach ($import in @(Get-Imports $manifest.FullName)) {
        $imported[$import.Resolved.ToLowerInvariant()] = $true
    }
}

$profilesReadme = Join-Path $rulesRoot 'profiles/README.md'
$profilesReadmeText = (Read-Lines $profilesReadme) -join "`n"

foreach ($folder in 'core', 'archetype', 'overlays') {
    $modules = Get-ChildItem (Join-Path $rulesRoot $folder) -Filter '*.md' |
        Sort-Object Name
    foreach ($module in $modules) {
        if ($imported.ContainsKey($module.FullName.ToLowerInvariant())) { continue }
        $optIn = $folder -eq 'overlays' -and
            $profilesReadmeText.Contains("overlays/$($module.Name)")
        if (-not $optIn) {
            $why = if ($folder -eq 'overlays') {
                'no profile imports it and profiles/README.md does not name it'
            } else {
                'no profile imports it'
            }
            Add-Failure (Get-RepoPath $module.FullName) 1 "dead weight: $why"
        }
    }
}

# --- 3. Hygiene of added lines -----------------------------------------------

# git writes the diff text as the files' raw bytes, and with
# core.quotePath=false writes a path's non-ASCII bytes raw instead of
# quoting the path for them. This repository's files and paths are UTF-8,
# so decode the output as UTF-8 and non-ASCII characters (the rules use em
# dashes) count as one each.
$savedEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
    $mergeBase = git -C $repoRoot merge-base $Base HEAD
    if ($LASTEXITCODE -ne 0) { throw "Cannot find a merge base of '$Base' and HEAD." }
    $diff = @(git -C $repoRoot -c core.quotePath=false diff --no-color `
        --no-ext-diff --unified=0 $mergeBase HEAD)
    if ($LASTEXITCODE -ne 0) { throw "git diff against '$Base' failed." }
}
finally {
    [Console]::OutputEncoding = $savedEncoding
}

$path = $null
$newLine = 0
$inHeader = $false
foreach ($line in $diff) {
    if ($line.StartsWith('diff --git ')) { $inHeader = $true; $path = $null; continue }
    if ($inHeader) {
        if ($line.StartsWith('+++ ')) {
            $path = if ($line -eq '+++ /dev/null') { $null } else { $line.Substring(6) }
        }
        elseif ($line -match '^@@ -\S+ \+(\d+)') {
            $inHeader = $false
            $newLine = [int]$Matches[1]
        }
        continue
    }
    if ($line -match '^@@ -\S+ \+(\d+)') { $newLine = [int]$Matches[1]; continue }
    if (-not $line.StartsWith('+') -or $null -eq $path) { continue }

    # The diff text holds the raw bytes, so a line of a file committed with
    # CRLF endings keeps its CR; the line ending is not part of the line.
    $text = $line.Substring(1).TrimEnd("`r")
    if ($text -match '\s$') {
        Add-Failure $path $newLine 'added line ends in whitespace'
    }
    if ($path -like '*.md' -and $text -notmatch '^\s*\|') {
        $length = (New-Object System.Globalization.StringInfo $text).LengthInTextElements
        if ($length -gt 80) {
            Add-Failure $path $newLine "added Markdown line is $length characters (max 80)"
        }
    }
    $newLine++
}

# --- 4. Profile tables agree -------------------------------------------------

# The rows of the first table whose header's first cell is `Profile`, as
# @{ Line; Text } records; Text is the row's cells with Markdown links
# reduced to their text, joined by ` | `.
function Get-ProfileTable([string] $Path) {
    $lines = Read-Lines $Path
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\|\s*Profile\s*\|') { $start = $i; break }
    }
    if ($start -lt 0) { return }
    for ($i = $start; $i -lt $lines.Count -and $lines[$i] -match '^\s*\|'; $i++) {
        if ($i -eq $start + 1) { continue }  # the |---| delimiter row
        $cells = $lines[$i].Trim().Trim('|').Split('|') | ForEach-Object {
            ($_ -replace '\[([^\]]*)\]\([^)]*\)', '$1').Trim()
        }
        [pscustomobject]@{ Line = $i + 1; Text = $cells -join ' | ' }
    }
}

$tableFiles = (Join-Path $repoRoot 'README.md'), $profilesReadme
$tables = foreach ($file in $tableFiles) {
    $rows = @(Get-ProfileTable $file)
    if ($rows.Count -eq 0) {
        Add-Failure (Get-RepoPath $file) 1 'no table whose header starts with Profile'
    }
    , $rows
}

if ($tables[0].Count -gt 0 -and $tables[1].Count -gt 0) {
    $left, $right = $tables
    $leftPath, $rightPath = $tableFiles | ForEach-Object { Get-RepoPath $_ }
    $count = [Math]::Max($left.Count, $right.Count)
    for ($i = 0; $i -lt $count; $i++) {
        if ($i -ge $left.Count) {
            Add-Failure $rightPath $right[$i].Line "profile table row missing from ${leftPath}"
        }
        elseif ($i -ge $right.Count) {
            Add-Failure $leftPath $left[$i].Line "profile table row missing from ${rightPath}"
        }
        elseif ($left[$i].Text -ne $right[$i].Text) {
            Add-Failure $leftPath $left[$i].Line `
                "profile table row differs from ${rightPath}:$($right[$i].Line)"
        }
    }
}

# --- Report -------------------------------------------------------------------

if ($failures.Count -eq 0) {
    Write-Output 'All checks passed.'
    exit 0
}
$failures | ForEach-Object { Write-Output $_ }
Write-Output "$($failures.Count) failure(s)."
exit 1
