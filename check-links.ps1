# check-links.ps1 - Verify the AGENTS.md hard links created by bootstrap.ps1 are intact.
#
# bootstrap.ps1 hardlinks ~/AGENTS.md, ~/.codex/AGENTS.md, and ~/.claude/CLAUDE.md
# to dotfiles\AGENTS.md so every coding agent shares one source of truth. If a tool
# ever replaces one of those paths with a copy (or a backup / OneDrive op breaks the
# link), agents silently start reading stale instructions. This script catches that.
#
# Usage: .\check-links.ps1
# Exit code 0 = all links intact; non-zero = at least one link is broken.
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$dotfiles = $PSScriptRoot
$target = Join-Path $dotfiles "AGENTS.md"

if (-not (Test-Path $target)) {
    Write-Host "check-links: dotfiles target not found: $target" -ForegroundColor Red
    exit 1
}

$targetHash = (Get-FileHash $target -Algorithm SHA256).Hash

$links = @(
    @{ Name = "root AGENTS.md";        Path = Join-Path $env:USERPROFILE "AGENTS.md" },
    @{ Name = ".codex AGENTS.md";      Path = Join-Path $env:USERPROFILE ".codex\AGENTS.md" },
    @{ Name = ".claude CLAUDE.md";     Path = Join-Path $env:USERPROFILE ".claude\CLAUDE.md" }
)

$broken = 0
Write-Host "`n=== AGENTS.md hard-link check ===" -ForegroundColor Magenta
foreach ($l in $links) {
    if (-not (Test-Path $l.Path)) {
        Write-Host ("  [FAIL] {0,-20} missing" -f $l.Name) -ForegroundColor Red
        $broken++
        continue
    }
    $item = Get-Item $l.Path
    $isHard = ($item.LinkType -eq 'HardLink')
    $sameContent = $false
    if ($isHard) {
        $sameContent = ((Get-FileHash $l.Path -Algorithm SHA256).Hash -eq $targetHash)
    }
    if ($isHard -and $sameContent) {
        Write-Host ("  [OK  ] {0,-20} hardlink, in sync" -f $l.Name) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] {0,-20} LinkType={1} (expected HardLink, in sync)" -f $l.Name, $item.LinkType) -ForegroundColor Red
        $broken++
    }
}

Write-Host ""
if ($broken -eq 0) {
    Write-Host "  All links intact - single source of truth confirmed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "  $broken link(s) broken - run .\bootstrap.ps1 to repair." -ForegroundColor Red
    exit 1
}
