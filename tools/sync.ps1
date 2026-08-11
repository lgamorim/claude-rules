<#
.SYNOPSIS
    Copy a rule profile — optionally recomposed — into a target repository, or
    report drift between the two.

.DESCRIPTION
    Resolves the `@import` lines of `.claude/rules/profiles/<Profile>.md` and
    copies each referenced module into the target repo's `.claude/rules/`,
    preserving the core/archetype/overlays layout.

    A profile's workflow posture is a default, not a fixed pairing, and some
    overlays are opt-in (see profiles/README.md). -Workflow swaps the posture;
    -Add appends opt-in overlays. Either one makes the result a *composition*:
    the profile manifest no longer describes the set, so it is not copied, and
    the script prints the `@import` lines to paste into the target's CLAUDE.md.

    With -Check, nothing is written: the script reports MISSING or DRIFT for
    each file instead, so a consuming repo can be audited against the source.
    Pass the same -Workflow/-Add arguments to -Check that were used to sync,
    or the audit will compare against the wrong set.

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-lib -Profile library-team

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-app -Profile application-solo -Workflow team

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-app -Profile application-solo -Add persistence-efcore -Check
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Target,
    [Parameter(Mandatory)] [string] $Profile,
    [ValidateSet('solo', 'team')] [string] $Workflow,
    [string[]] $Add = @(),
    [switch] $Check
)

$ErrorActionPreference = 'Stop'

# Read a text file for comparison with line endings normalized to LF. Consuming
# repos may check out with `eol=lf` (.gitattributes) while this worktree is
# CRLF, so a byte-level compare (Get-FileHash) reports DRIFT for identical
# text. -Encoding utf8 is explicit because Windows PowerShell 5.1 misreads a
# BOM-less UTF-8 file as ANSI.
function Get-NormalizedContent([string] $Path) {
    (Get-Content $Path -Raw -Encoding utf8) -replace "`r`n", "`n"
}

$rulesRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\.claude\rules')).Path
$profilePath = Join-Path $rulesRoot "profiles\$Profile.md"

if (-not (Test-Path $profilePath)) {
    $available = Get-ChildItem (Join-Path $rulesRoot 'profiles') -Filter '*.md' |
                 Where-Object { $_.BaseName -ne 'README' } |
                 ForEach-Object { $_.BaseName }
    throw "Unknown profile '$Profile'. Available: $($available -join ', ')"
}
if (-not (Test-Path $Target)) { throw "Target repo not found: $Target" }

# Modules the profile imports, in declaration order.
$modules = @(Select-String -Path $profilePath -Pattern '^\s*@(\S+\.md)\s*$' |
             ForEach-Object { $_.Matches[0].Groups[1].Value } |
             ForEach-Object { (Resolve-Path (Join-Path (Split-Path $profilePath) $_)).Path })

$composed = $false

# Swap the workflow posture in place, so the module keeps its position.
if ($Workflow) {
    $wantedPath = Join-Path $rulesRoot "overlays\workflow-$Workflow.md"
    if (-not (Test-Path $wantedPath)) { throw "No overlay for workflow posture '$Workflow'." }
    $wanted = (Resolve-Path $wantedPath).Path

    $current = @($modules | Where-Object {
        $_ -like '*overlays\workflow-solo.md' -or $_ -like '*overlays\workflow-team.md'
    })
    if ($current.Count -eq 0) { throw "Profile '$Profile' imports no workflow overlay to swap." }

    if ($current[0] -ne $wanted) {
        $modules = @($modules | ForEach-Object { if ($_ -eq $current[0]) { $wanted } else { $_ } })
        $composed = $true
    }
}

# Append opt-in overlays (e.g. persistence-efcore, workflow-agent-review-solo).
foreach ($name in $Add) {
    $overlayPath = Join-Path $rulesRoot "overlays\$name.md"
    if (-not (Test-Path $overlayPath)) {
        $available = Get-ChildItem (Join-Path $rulesRoot 'overlays') -Filter '*.md' |
                     ForEach-Object { $_.BaseName }
        throw "Unknown overlay '$name'. Available: $($available -join ', ')"
    }
    $overlay = (Resolve-Path $overlayPath).Path
    if ($modules -notcontains $overlay) {
        $modules += $overlay
        $composed = $true
    }
}

# An agent-review overlay is posture-matched: pairing it with the opposite
# workflow overlay would copy a set the rules themselves forbid.
$posture = @($modules | Where-Object {
    $_ -like '*overlays\workflow-solo.md' -or $_ -like '*overlays\workflow-team.md'
})
foreach ($variant in 'solo', 'team') {
    $review = @($modules | Where-Object { $_ -like "*overlays\workflow-agent-review-$variant.md" })
    if ($review.Count -gt 0 -and ($posture.Count -eq 0 -or $posture[0] -notlike "*workflow-$variant.md")) {
        throw "Overlay 'workflow-agent-review-$variant' requires the '$variant' workflow posture; use -Workflow $variant or the matching agent-review variant."
    }
}

# A composition is no longer the profile, so shipping the manifest would
# misdescribe it — the consumer imports the modules directly instead.
$sources = if ($composed) { $modules } else { @($profilePath) + $modules }
$label = if ($composed) { "$Profile (composed)" } else { $Profile }

$drift = 0
foreach ($src in $sources) {
    $relative = $src.Substring($rulesRoot.Length).TrimStart('\', '/')
    $dst = Join-Path $Target (Join-Path '.claude\rules' $relative)

    if ($Check) {
        if (-not (Test-Path $dst)) {
            Write-Output "MISSING  $relative"
            $drift++
        }
        elseif ((Get-NormalizedContent $src) -ne (Get-NormalizedContent $dst)) {
            Write-Output "DRIFT    $relative"
            $drift++
        }
        else {
            Write-Verbose "OK       $relative"
        }
    }
    else {
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        Copy-Item $src $dst -Force
        Write-Output "synced   $relative"
    }
}

if ($Check) {
    if ($drift -eq 0) { Write-Output "In sync: $($sources.Count) file(s) match '$label'." }
    else { Write-Output "$drift of $($sources.Count) file(s) differ from '$label'." }
}
elseif ($composed) {
    Write-Output ''
    Write-Output 'Composed set - no profile matches it, so import these from the target CLAUDE.md:'
    foreach ($src in $modules) {
        $rel = $src.Substring($rulesRoot.Length).TrimStart('\', '/').Replace('\', '/')
        Write-Output "@.claude/rules/$rel"
    }
}
