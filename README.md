# dotfiles

Personal developer environment for Windows / PowerShell.

## What's included

| File | Purpose |
|---|---|
| `powershell/Microsoft.PowerShell_profile.ps1` | PowerShell profile |
| `oh-my-posh/themes/atomic.omp.json` | oh-my-posh atomic theme |
| `AGENTS.md` | Global instructions for AI coding agents |
| `bootstrap.ps1` | One-shot setup script for a new machine |

## Fresh machine setup

### Prerequisites
- [PowerShell 7+](https://aka.ms/powershell)
- [Windows Terminal](https://aka.ms/terminal)
- [winget](https://aka.ms/winget) (built into Windows 11)

### Option A — Clone first, then bootstrap
```powershell
git clone https://github.com/bsamba/dotfiles $env:USERPROFILE\dotfiles
Set-Location $env:USERPROFILE\dotfiles
.\bootstrap.ps1
```

### Option B — One-liner (no git needed)
```powershell
Invoke-Expression (Invoke-WebRequest https://raw.githubusercontent.com/bsamba/dotfiles/main/bootstrap.ps1 -UseBasicParsing).Content
```

## What bootstrap does

1. Installs PowerShell profile dependencies: `oh-my-posh`, `PSReadLine`
2. Installs **CaskaydiaCove Nerd Font** (per-user)
3. Copies the oh-my-posh theme
4. Symlinks `$PROFILE` → `dotfiles\powershell\Microsoft.PowerShell_profile.ps1`
5. Hardlinks `AGENTS.md` → `~/AGENTS.md`, `~/.codex/AGENTS.md`, and `~/.claude/CLAUDE.md`
6. Prompts for `AUTO_ADMIN_PASSWORD`, `N3O_NUGET_TOKEN`, and `NUGET_AUTH_TOKEN` if they are not set

## After setup

Set your Windows Terminal font to **CaskaydiaCove Nerd Font Mono** for icons to render correctly.

## Updating

Edit files in `~/dotfiles/` directly — the profile is symlinked and `AGENTS.md` is hardlinked so changes take effect immediately.
Push changes with:
```powershell
cd ~/dotfiles
git add -A && git commit -m "update" && git push
```
