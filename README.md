# dotfiles

Personal developer environment for Windows / PowerShell.

## What's included

| File | Purpose |
|---|---|
| `powershell/Microsoft.PowerShell_profile.ps1` | PowerShell profile |
| `oh-my-posh/themes/atomic.omp.json` | oh-my-posh atomic theme |
| `AGENTS.md` | Global instructions for AI coding agents (single source of truth) |
| `.copilot/instructions/spec-driven-dev.instructions.md` | Persistent instruction that makes the spec-driven workflow implicit |
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
7. Installs Matt Pocock's coding-agent skills (`npx skills@latest add mattpocock/skills`) and hardlinks the spec-driven-dev instruction into `~/.copilot/instructions/`

> **Single source of truth:** `AGENTS.md` is the canonical file. `bootstrap.ps1` hardlinks it into `~/AGENTS.md`, `~/.codex/AGENTS.md`, and `~/.claude/CLAUDE.md`, so editing it here updates every agent at once. Re-run `.\check-links.ps1` after pulling to confirm the links are still intact.

## After setup

Set your Windows Terminal font to **CaskaydiaCove Nerd Font Mono** for icons to render correctly.

## Implicit coding workflow

Every coding session runs a spec-driven pre-flight **before** writing code or
taking action. It is wired in via the persistent instruction
`spec-driven-dev.instructions.md` (loaded automatically by the agent).

1. **grill-me** — sharpen the plan (design tree, decision frontier)
2. **to-spec** — synthesize an aligned spec, publish it to the issue tracker
3. **to-tickets** — break the spec into tracer-bullet tickets with blocking edges
4. **tdd** — implement each ticket test-first (red → green → refactor)

The skills are installed by `bootstrap.ps1` via
`npx skills@latest add mattpocock/skills`. Read-only questions and pure chat
skip the pre-flight.

## Updating

Edit files in `~/dotfiles/` directly — the profile is a trampoline and `AGENTS.md` is hardlinked so changes take effect immediately.
Confirm the `AGENTS.md` hard links are still intact with:
```powershell
.\check-links.ps1
```
Push changes with:
```powershell
cd ~/dotfiles
git add -A && git commit -m "update" && git push
```

## Remote Ollama endpoint (`https://ai.lab.n3otech.com`)

The tuned local Ollama fleet is reachable off-machine through the n3otech
lab hub (`twd0x5drsp000`), which runs Caddy + WireGuard:

- **Endpoint:** `https://ai.lab.n3otech.com/v1` (OpenAI-compatible).
- **Prerequisite:** you must be on the n3otech WireGuard mesh (`10.7.0.0/24`).
- **No API key needed:** the guard proxy on `192.168.1.241:11435` requires
  `Authorization: Bearer <key>` from every non-loopback client, but Caddy on
  the hub injects that key **server-side**, so a WireGuard peer uses the plain
  URL and never holds the key. WireGuard peer membership is the only
  client-side credential. Clients outside the mesh get `403` from Caddy.

```powershell
# from a WireGuard peer:
Invoke-RestMethod https://ai.lab.n3otech.com/v1/models | Format-Table
```

> **Clients without WireGuard:** a non-mesh client is rejected with `403`
> before the request reaches the proxy. Enabling access for them without
> handing them the proxy key (Tailscale / mTLS / forward-auth / Cloudflare
> Access) is tracked in
> [devops-core#319](https://github.com/n3otech/devops-core/issues/319).
