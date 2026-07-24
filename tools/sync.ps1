<#
.SYNOPSIS
    Copy a rule profile and every module it imports into a target repository,
    or report drift between the two.

.DESCRIPTION
    Resolves the `@import` lines of `.claude/rules/profiles/<Profile>.md` and
    copies each referenced module (plus the profile itself) into the target
    repo's `.claude/rules/`, preserving the core/archetype/overlays layout.

    With -Check, nothing is written: the script reports MISSING or DRIFT for
    each file instead, so a consuming repo can be audited against the source.

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-lib -Profile library-team

.EXAMPLE
    ./tools/sync.ps1 -Target C:\Git\me\my-lib -Profile library-team -Check
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Target,
    [Parameter(Mandatory)] [string] $Profile,
    [switch] $Check
)

$ErrorActionPreference = 'Stop'

$rulesRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\.claude\rules')).Path
$profilePath = Join-Path $rulesRoot "profiles\$Profile.md"

if (-not (Test-Path $profilePath)) {
    $available = Get-ChildItem (Join-Path $rulesRoot 'profiles') -Filter '*.md' |
                 Where-Object { $_.BaseName -ne 'README' } |
                 ForEach-Object { $_.BaseName }
    throw "Unknown profile '$Profile'. Available: $($available -join ', ')"
}
if (-not (Test-Path $Target)) { throw "Target repo not found: $Target" }

# The profile itself ships alongside the modules it imports.
$sources = @($profilePath)
$sources += Select-String -Path $profilePath -Pattern '^\s*@(\S+\.md)\s*$' |
            ForEach-Object { $_.Matches[0].Groups[1].Value } |
            ForEach-Object { (Resolve-Path (Join-Path (Split-Path $profilePath) $_)).Path }

$drift = 0
foreach ($src in $sources) {
    $relative = $src.Substring($rulesRoot.Length).TrimStart('\', '/')
    $dst = Join-Path $Target (Join-Path '.claude\rules' $relative)

    if ($Check) {
        if (-not (Test-Path $dst)) {
            Write-Output "MISSING  $relative"
            $drift++
        }
        elseif ((Get-FileHash $src).Hash -ne (Get-FileHash $dst).Hash) {
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
    if ($drift -eq 0) { Write-Output "In sync: $($sources.Count) file(s) match '$Profile'." }
    else { Write-Output "$drift of $($sources.Count) file(s) differ from '$Profile'." }
}
