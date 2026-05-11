# bootstrap.ps1 - Set up dev environment on a new Windows machine
# Usage: Invoke-Expression (Invoke-WebRequest https://raw.githubusercontent.com/bsamba/dotfiles/main/bootstrap.ps1 -UseBasicParsing).Content
# Or after cloning: .\bootstrap.ps1
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = "Stop"
$dotfiles = $PSScriptRoot

function Install-WingetPackage {
    param([string]$Id, [string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "  Installing $Id..." -ForegroundColor Cyan
        winget install $Id --accept-package-agreements --accept-source-agreements -e
    } else {
        Write-Host "  $Name already installed" -ForegroundColor Green
    }
}

Write-Host "`n=== Dotfiles Bootstrap ===" -ForegroundColor Magenta

# --- Install tools ---
Write-Host "`n[1/4] Installing tools..." -ForegroundColor Yellow

Install-WingetPackage "JanDeDobbeleer.OhMyPosh"   "oh-my-posh"
Install-WingetPackage "GitHub.cli"                 "gh"
Install-WingetPackage "Microsoft.DotNet.SDK.9"     "dotnet"
Install-WingetPackage "Docker.DockerDesktop"       "docker"

# Refresh PATH after installs
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# dotnet-suggest
if (-not (Get-Command dotnet-suggest -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing dotnet-suggest..." -ForegroundColor Cyan
    dotnet tool install -g dotnet-suggest
}

# PSReadLine
if (-not (Get-Module PSReadLine -ListAvailable | Where-Object Version -ge "2.3.0")) {
    Write-Host "  Installing PSReadLine..." -ForegroundColor Cyan
    Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
}

# --- Install Nerd Font ---
Write-Host "`n[2/4] Installing CaskaydiaCove Nerd Font..." -ForegroundColor Yellow
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
$alreadyInstalled = Test-Path "$fontDir\CaskaydiaCoveNerdFont-Regular.ttf"

if (-not $alreadyInstalled) {
    $zip = "$env:TEMP\CascadiaCode.zip"
    $extractDir = "$env:TEMP\CascadiaCode"
    Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $extractDir -Force
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Get-ChildItem $extractDir -Filter "*.ttf" | Where-Object { $_.Name -notlike "*WindowsCompatible*" } | ForEach-Object {
        Copy-Item $_.FullName "$fontDir\$($_.Name)" -Force
        Set-ItemProperty -Path $regPath -Name ($_.BaseName + " (TrueType)") -Value "$fontDir\$($_.Name)"
    }
    Remove-Item $zip, $extractDir -Recurse -Force
    Write-Host "  Font installed" -ForegroundColor Green
} else {
    Write-Host "  Font already installed" -ForegroundColor Green
}

# --- Copy oh-my-posh theme ---
Write-Host "`n[3/4] Installing oh-my-posh theme..." -ForegroundColor Yellow
$themesDir = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes"
New-Item -ItemType Directory -Force -Path $themesDir | Out-Null
Copy-Item "$dotfiles\oh-my-posh\themes\atomic.omp.json" "$themesDir\atomic.omp.json" -Force
Write-Host "  Theme installed" -ForegroundColor Green

# --- Symlink PowerShell profile ---
Write-Host "`n[4/4] Linking PowerShell profile..." -ForegroundColor Yellow
$profileDir = Split-Path $PROFILE
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

if (Test-Path $PROFILE) {
    $existing = Get-Item $PROFILE
    # If it's already a trampoline pointing to our dotfiles, skip
    if ($existing.LinkType -ne 'SymbolicLink' -and (Get-Content $PROFILE -Raw) -match [regex]::Escape("$dotfiles\powershell\Microsoft.PowerShell_profile.ps1")) {
        Write-Host "  Profile trampoline already in place" -ForegroundColor Green
    } else {
        $backup = "$PROFILE.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item $PROFILE $backup
        Write-Host "  Existing profile backed up to $backup" -ForegroundColor DarkYellow
    }
}

if (-not (Test-Path $PROFILE)) {
    # Use a trampoline (regular file) instead of a symlink so OneDrive sync doesn't break it
    Set-Content -Path $PROFILE -Value ". `"$dotfiles\powershell\Microsoft.PowerShell_profile.ps1`"" -Encoding UTF8
    Write-Host "  Profile trampoline created" -ForegroundColor Green
}

Write-Host "`n=== Done! Restart your terminal ===" -ForegroundColor Magenta
Write-Host "  Don't forget: set font to 'CaskaydiaCove Nerd Font Mono' in Windows Terminal settings`n" -ForegroundColor DarkYellow
