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

    A sync stamps the source commit (HEAD of this checkout) into the target's
    `.claude/rules/.sync-source`, so a later audit knows what it was synced
    from, followed by the set's composition: the profile, the workflow
    posture the set ends up with, and the overlays -Add appended to it.
    Claude Code (2.1.207) loads the `.md` files under `.claude/rules/` as
    rules; this file is not one, so Claude Code does not load it as a rule.

    With -Check, nothing is written: the script reports MISSING or DRIFT for
    each file instead, so a consuming repo can be audited against the source.
    It also reports as EXTRA every `.md` file directly under the target's
    `.claude/rules/core`, `archetype`, `overlays`, or `profiles` that is not
    in the set — a module renamed or dropped since the last sync. It prints
    the source commit and the stamped one, and lists the commits between them
    that touched a file in the set or an EXTRA file. A sync lists the same
    files as `extra` but never deletes them: it cannot tell a dropped module
    from a file the consumer added there.

    -Check needs only -Target when the stamp records the composition: the
    audit compares against the stamped set. Flags passed with it describe the
    whole set, as for a sync, and when that set differs from the stamped one
    the script reports both and stops without auditing. A stamp holding only
    the commit, written by an older sync, or no stamp at all records no
    composition, so -Check then needs -Profile and the same -Workflow/-Add
    arguments that were used to sync, or it compares against the wrong set.

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-lib -Profile library-team

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-app -Profile application-solo -Workflow team

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-app -Check

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-app -Profile application-solo -Add persistence-efcore -Check
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Target,
    [string] $Profile,
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

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Run git in this checkout and return its output lines, or nothing when it
# fails (no git checkout, unknown commit). Errors are not terminating here:
# Windows PowerShell 5.1 turns a redirected stderr line into an error record,
# which 'Stop' would throw. Callers quote '--', which PowerShell otherwise
# takes as its own end-of-parameters marker and never passes on.
function Invoke-SourceGit {
    $ErrorActionPreference = 'Continue'
    $output = & git -C $sourceRoot @args 2>$null
    if ($LASTEXITCODE -eq 0) { $output }
}

# The composition as the flags that rebuild it, e.g.
# `-Profile application-solo -Workflow team -Add persistence-efcore`.
function Format-Set([string] $ProfileName, [string] $Posture, [string[]] $Overlays) {
    $text = "-Profile $ProfileName"
    if ($Posture) { $text += " -Workflow $Posture" }
    if ($Overlays.Count -gt 0) { $text += " -Add $($Overlays -join ',')" }
    $text
}

$rulesRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\.claude\rules')).Path

if (-not (Test-Path $Target)) { throw "Target repo not found: $Target" }
# Absolute from here on: .NET calls such as File.WriteAllText resolve a
# relative path against the process directory, which Set-Location never moves.
$Target = (Resolve-Path $Target).Path

# The stamp holds the source commit on its first line, then one `key: value`
# line each for the profile, the workflow posture, and the appended overlays.
# A stamp from an older sync holds the commit alone.
$stampPath = Join-Path $Target '.claude\rules\.sync-source'
$targetSha = $null
$stamp = @{}
if (Test-Path $stampPath) {
    $stampLines = @(Get-Content $stampPath -Encoding utf8)
    if ($stampLines.Count -gt 0) { $targetSha = "$($stampLines[0])".Trim() }
    foreach ($line in $stampLines | Select-Object -Skip 1) {
        if ($line -match '^(profile|workflow|add):(.*)$') { $stamp[$Matches[1]] = $Matches[2].Trim() }
    }
}
$stampedProfile = $stamp['profile']
$stampedPosture = $stamp['workflow']
$stampedAdd = @("$($stamp['add'])" -split '[,\s]+' | Where-Object { $_ })

# Without -Profile, -Check audits the set the stamp records.
$fromStamp = -not $Profile
if ($fromStamp) {
    if ($Workflow -or $Add.Count -gt 0) {
        throw '-Workflow and -Add describe a set only together with -Profile.'
    }
    if (-not $Check) { throw 'A sync needs -Profile; only -Check reads the set from the stamp.' }
    if (-not $stampedProfile) {
        $why = if (Test-Path $stampPath) { "$stampPath records no composition" } else { "$Target has no .sync-source stamp" }
        throw "$why, so -Check needs the -Profile, -Workflow, and -Add arguments the target was synced with."
    }
    $Profile = $stampedProfile
    if ($stampedPosture) { $Workflow = $stampedPosture }
    $Add = $stampedAdd
}

$profilePath = Join-Path $rulesRoot "profiles\$Profile.md"
if (-not (Test-Path $profilePath)) {
    $available = Get-ChildItem (Join-Path $rulesRoot 'profiles') -Filter '*.md' |
                 Where-Object { $_.BaseName -ne 'README' } |
                 ForEach-Object { $_.BaseName }
    throw "Unknown profile '$Profile'. Available: $($available -join ', ')"
}

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
# Only those the set did not already hold are recorded in the stamp.
$appended = @()
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
        $appended += $name
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

# The posture the set ends up with, whether the profile or -Workflow chose it.
$setPosture = if ($posture.Count -gt 0) {
    [System.IO.Path]::GetFileNameWithoutExtension($posture[0]) -replace '^workflow-', ''
}
$setText = Format-Set $Profile $setPosture $appended

# Flags passed to -Check must describe the stamped set; picking either one
# silently would audit a set the user did not ask for.
if ($Check -and -not $fromStamp -and $stampedProfile) {
    $sameAdd = (@($appended | Sort-Object) -join ',') -eq (@($stampedAdd | Sort-Object) -join ',')
    if ($Profile -ne $stampedProfile -or "$setPosture" -ne "$stampedPosture" -or -not $sameAdd) {
        Write-Output "Flags    $setText"
        Write-Output "Stamped  $(Format-Set $stampedProfile $stampedPosture $stampedAdd)"
        throw 'The flags describe a different set than .sync-source records. Drop them to audit the stamped set, or sync with them to change it.'
    }
}

# A composition is no longer the profile, so shipping the manifest would
# misdescribe it — the consumer imports the modules directly instead.
$sources = if ($composed) { $modules } else { @($profilePath) + $modules }
$label = if ($composed) { "$Profile (composed)" } else { $Profile }

# Paths relative to the rules root (e.g. `core\coding-standards.md`), keyed
# in lower case because Windows paths compare case-insensitively.
$expected = @{}
foreach ($src in $sources) {
    $expected[$src.Substring($rulesRoot.Length).TrimStart('\', '/').ToLowerInvariant()] = $true
}

# Files a sync writes only into these four folders, directly beneath each, so
# a file there outside the set is one a past sync left behind. Files elsewhere
# under .claude/rules - path-scoped rules, nested folders - are the
# consumer's own and are never examined.
$extras = @(foreach ($folder in 'core', 'archetype', 'overlays', 'profiles') {
    $dir = Join-Path $Target ".claude\rules\$folder"
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem $dir -Filter '*.md' -File | Sort-Object Name | ForEach-Object {
        $relative = Join-Path $folder $_.Name
        if (-not $expected.ContainsKey($relative.ToLowerInvariant())) { $relative }
    }
})

# Every file this target carries or should carry, as source pathspecs.
$pathspec = @($expected.Keys) + @($extras) |
            ForEach-Object { '.claude/rules/' + $_.Replace('\', '/') }

$sourceSha = Invoke-SourceGit rev-parse HEAD

if ($Check) {
    Write-Output "Source   $(if ($sourceSha) { $sourceSha } else { '(not a git checkout)' })"
    Write-Output "Target   $(if ($targetSha) { $targetSha } else { '(no .sync-source stamp)' })"
    Write-Output "Set      $setText $(if ($fromStamp) { '(from .sync-source)' } else { '(from flags)' })"

    if ($sourceSha -and $targetSha -and $sourceSha -ne $targetSha) {
        if (-not (Invoke-SourceGit rev-parse --verify --quiet "$targetSha^{commit}")) {
            Write-Output "Target's commit is not in this checkout; fetch to list the commits between them."
        }
        else {
            $missing = @(Invoke-SourceGit log --oneline --no-decorate "$targetSha..$sourceSha" '--' $pathspec)
            $ahead = @(Invoke-SourceGit log --oneline --no-decorate "$sourceSha..$targetSha" '--' $pathspec)
            if ($missing.Count -gt 0) {
                Write-Output "Commits since the target's sync that touch its files:"
                $missing | ForEach-Object { Write-Output "         $_" }
            }
            if ($ahead.Count -gt 0) {
                Write-Output "The target was synced from $($ahead.Count) commit(s) this checkout lacks; pull before trusting the comparison."
            }
        }
    }
    Write-Output ''
}

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
    foreach ($relative in $extras) { Write-Output "EXTRA    $relative" }

    if ($drift -eq 0 -and $extras.Count -eq 0) {
        Write-Output "In sync: $($sources.Count) file(s) match '$label'."
    }
    else {
        $summary = "$drift of $($sources.Count) file(s) differ from '$label'"
        if ($extras.Count -gt 0) { $summary += "; $($extras.Count) file(s) are not in it" }
        Write-Output "$summary."
    }
    return
}

# Warn rather than delete: the sync cannot tell a module dropped from the set
# from a file the consumer added there, nor see uncommitted edits to it.
if ($extras.Count -gt 0) {
    foreach ($relative in $extras) { Write-Output "extra    $relative" }
    Write-Output "These files are not in '$label'; repoint any import of one in the target's CLAUDE.md, then delete them."
}

if ($sourceSha) {
    # An empty value gets no space after its colon, so no line of the stamp
    # ends in whitespace. LF and no BOM, so it reads the same in any checkout
    # of the target.
    $stampText = "$sourceSha`n"
    foreach ($field in @(('profile', $Profile), ('workflow', $setPosture), ('add', ($appended -join ', ')))) {
        $stampText += if ($field[1]) { "$($field[0]): $($field[1])`n" } else { "$($field[0]):`n" }
    }
    [System.IO.File]::WriteAllText($stampPath, $stampText)
    Write-Output "stamped  .sync-source $sourceSha $setText"
    if (Invoke-SourceGit status --porcelain '--' $pathspec) {
        Write-Warning 'Synced files have uncommitted changes in the source, which the stamped commit does not contain.'
    }
}
else {
    Write-Warning "$sourceRoot is not a git checkout, so no .sync-source stamp was written."
}

if ($composed) {
    Write-Output ''
    Write-Output 'Composed set - no profile matches it, so import these from the target CLAUDE.md:'
    foreach ($src in $modules) {
        $rel = $src.Substring($rulesRoot.Length).TrimStart('\', '/').Replace('\', '/')
        Write-Output "@.claude/rules/$rel"
    }
}
