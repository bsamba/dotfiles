# AGENTS.md

General-purpose instructions for coding agents operating on this machine. This file is a fallback for sessions that are not rooted in a specific repository.

## Relationship to repository AGENTS.md

- This file is a **global baseline** for coding agents on this machine. If a repository has its own `AGENTS.md` at its root, that file **supplements** these instructions rather than replacing them. Apply repo-specific guidance on top of this baseline; only override this baseline when the repo's instructions explicitly conflict with it.

## Workflow rules

- **Never commit directly to `dev`, `stg`, or `main`** (or equivalently named default/staging/production branches). Always create a feature branch and open a pull request instead.
- For promotion PRs (`dev → stg → main`), prefer a real merge commit over squash where the repo allows it, so branch histories stay linked.
- **When starting work in a repo, always use or create a GitHub issue for the task first.** Check for an existing issue that matches the task; if none exists, create one before starting implementation. Reference the issue number in commits and the PR description.
- Follow the repo-root conventions below when cloning repos or creating scratch files.

## Repository and scratch file locations

- Clone or locate repositories under `~/source/repos`.
  - Org-owned repos go under `~/source/repos/<org-name>/<repo-name>`.
  - Personal repos go directly under `~/source/repos/<repo-name>`.
  - Before cloning, check whether the repo already exists at the expected path and reuse it.
- Use `~/source/scratch` for scratch/temporary/throwaway work (experiments, one-off scripts, files to inspect) — do not scatter these into the repos root or home directory.
- `~` paths are **machine-absolute**: `~/source/scratch` = `C:/Users/Bas/source/scratch`. Never prepend the current repo/workspace root to a `~`, drive-letter, or `/c/` path — `<repo>/source/scratch/...` does not exist.
- When a tool call fails, never retry the identical call (the local model fleet runs at temperature 0 — identical retries fail identically and loop). Change approach: list the parent, search by filename, or report what is missing.

### Git worktree layout

- Repos with long-lived environment branches (`main`/`dev`/`stg`) use **git worktrees** so every branch stays checked out:
  - The main checkout stays at the repo root (`~/source/repos/<org-name>/<repo-name>`) on the default branch.
  - Each additional branch lives in a sibling directory named `<repo-name>.worktrees/<branch>` — e.g. `~/source/repos/n3otech/vcwpCareHub.worktrees/dev` and `~/source/repos/n3otech/vcwpCareHub.worktrees/stg`.
- Create them with `git worktree add ../<repo-name>.worktrees/<branch> <branch>` from the <repos default branch> checkout. Never check out the same branch in two worktrees — git refuses, and a detached HEAD in a worktree is a sign the layout drifted.
- When restructuring existing checkouts into this layout, move directories with `git worktree move` (fall back to `mv` + `git worktree repair` if the move is blocked by a Windows file lock).

## Local model fleet

A tuned Ollama fleet runs locally on this machine (see `~/source/repos/n3otech/devops-core/local-ai-agents/ollama/` for models, docs, and the eval harness).

- Endpoint: `http://127.0.0.1:11435` (guarded proxy — preferred) or `http://127.0.0.1:11434` (direct).
- The proxy and watchdog auto-start at logon via Task Scheduler (`\OllamaGuardProxy`, `\OllamaWatchdog`).
- **Prefer local Ollama models for sub-agents.** When launching a custom agent (`task`) or delegating to background agents, point them at the local fleet via the OpenAI-compatible proxy endpoint `http://127.0.0.1:11435/v1` rather than a remote/cloud model, unless the task explicitly requires a remote model. This keeps work on the tuned local fleet, avoids network latency, and respects the temperature-0 determinism the fleet is configured for.

### Job-side loop detection (fleet cost discipline)

When running agentic jobs against the fleet (Copilot CLI sessions, batch scripts, custom harnesses), build the loop guard into the job itself — the proxy cannot see tool results, so it cannot detect semantic repetition:

- **Instruct the agent.** Add to the job's prompt/instructions: *"If a tool call returns the same result as your previous attempt, do not repeat it — change approach or stop."* Re-running a tool that returns identical output wastes tokens, and on cloud-only models it wastes money.
- **Cap iterations in the harness.** Abort a job after N consecutive identical tool results or a hard tool-call budget, and emit a summary of what was done instead of looping.
- **Prefer local lanes.** Jobs that don't specifically need a cloud-only model should target local lane models (e.g. `qwen3.8-copilot`); direct cloud-model requests bypass all local lanes and bill paid tokens per request.
- **The proxy sheds runaway cloud loops.** The cloud rate valve (`CLOUD_RATE_PER_MIN`, default 30 req/min per cloud model) returns `429 + Retry-After`; a job that trips it is looping, not working — fix the harness rather than raising the limit to "unblock" it.

## Environment gotchas (this machine)

- Default shell is **PowerShell 7.6.4** (`pwsh`) — modern syntax (`??`, ternary, `&&`/`||`) is fully supported.
- Windows PowerShell 5.1 (`powershell.exe`) is still present for legacy scripts. When explicitly targeting it, avoid `??`, ternary operators, and `&&`/`||` pipeline chains.
- In Git Bash, Windows CLI flags need `//` (e.g. `schtasks //query`), and non-ASCII payloads via curl get mangled — use Python for HTTP/API tests instead.
- For operations needing elevation (e.g. modifying scheduled tasks), use **Windows Sudo** (`sudo`, v1.0.1) — do not skip them or hand them back to the user. Machine policy is **inline mode** (`HKLM:\...\Sudo Enabled=3`), so prefer `sudo --inline <cmd>` and read stdout directly (UAC prompt appears on the user's screen each time). Plain `sudo` opens a separate window whose stdout is not captured; if that is ever the mode again, redirect the elevated command's output to a file and read it back.
- Never use `:` in filenames (creates NTFS alternate data streams).

## Skills to use

Skills live under `~\.copilot\skills\<skill-name>\SKILL.md`, `~\.agents\skills\<skill-name>\SKILL.md`, or `~\.copilot\installed-plugins\<plugin>\skills\<skill-name>\SKILL.md` — read the skill file before applying it. Use the relevant skill whenever its description matches the task at hand, rather than solving it manually:

- **repo-root-conventions** — where to clone/locate repos and place scratch files (see above).
- **windows-powershell** — PowerShell 5.1/7 scripting, Windows system administration, scheduled tasks, Credential Manager, Pester testing, and Windows/Git Bash interop rules.
- **wsl2** — WSL2 setup, `.wslconfig` / `wsl.conf` configuration, Windows↔Linux interop, networking (NAT vs mirrored mode), systemd, and filesystem performance rules.
- **python** — Python project structure, virtual environments, `uv`, type annotations, async, `pytest`, security, and Windows/WSL-specific gotchas.
- **typescript** — TypeScript strict configuration, types, async patterns, tooling (`eslint`, `vitest`, `zod`), Node.js best practices, and security.
- **coreutils-shell** — Bash/POSIX shell scripting, GNU coreutils patterns, safe variable handling, `trap`/cleanup, `shellcheck`, and Windows/Git Bash/WSL2 gotchas.
- **setup-local-sdk** — installing a local .NET SDK for preview/version-specific testing without touching the system install.
- **aspnet-minimal-api-openapi** — creating ASP.NET Minimal API endpoints with proper OpenAPI documentation.
- **csharp-async** — C# async programming best practices.
- **csharp-mstest** — MSTest unit testing best practices (modern assertions, data-driven tests).
- **csharp-nunit** — NUnit unit testing best practices.
- **csharp-tunit** — TUnit unit testing best practices.
- **csharp-xunit** — xUnit unit testing best practices.
- **dotnet-best-practices** — ensuring .NET/C# code meets solution/project best practices.
- **dotnet-upgrade** — .NET framework upgrade analysis and execution.
- **microsoft-code-reference** — verifying Microsoft SDK/API signatures and working code samples; use when writing, debugging, or reviewing any code touching a Microsoft SDK/API to avoid hallucinated methods or deprecated patterns.
- **microsoft-docs** — looking up official Microsoft documentation (Azure, .NET, M365, Windows, Power Platform, etc.) for conceptual/how-to questions.
- **microsoft-skill-creator** — scaffolding new agent skills for Microsoft technologies from official docs.
- **customize-cloud-agent** — configuring the Copilot cloud agent environment (`copilot-setup-steps.yml`, preinstalling tools/dependencies).
- **github-pr-media** — uploading images/videos and embedding them in PR descriptions or GitHub comments.
- **project-setup-info-local** — scaffolding complete new projects in a VS Code workspace (frameworks, config files, folder structure); not for individual files or modifications to existing projects.
- **agent-customization** — creating, updating, or debugging VS Code agent customization files (`.instructions.md`, `.prompt.md`, `.agent.md`, `SKILL.md`, `AGENTS.md`); use for saving coding preferences, fixing ignored instructions, or defining custom agent modes.
- **chronicle** — querying Copilot session history for standup reports, usage tips, session search, and reindexing.
- **get-search-view-results** — reading the current results from the VS Code Search view.
- **typesafe-ai** — building with TypeSafe's System One API (the `jev` model): typed `noul`/`choice`/`score` judgments, state design, confidence handling, and the HTTP/SDK contracts. Located at `~\.agents\skills\typesafe-ai\SKILL.md`. Read the live docs at `https://docs.typesafe.ai/llms.txt` as part of the task — they are the source of truth. See "TypeSafe API access" below for the credential and endpoint.

Check for newly available skills each session, as this list may not be exhaustive going forward.

## Machine-scope credentials

These secrets live in **machine-scope** environment variables (`HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment`), so every shell and every process on this machine inherits them — no per-shell loading step is needed. They were moved from user scope to machine scope on 2026-09-24.

| Variable | Purpose |
| --- | --- |
| `TYPESAFE_API_KEY` | TypeSafe System One API key (see "TypeSafe API access" below) |
| `DEEP_SEEK_API_KEY` | DeepSeek API key — auth for the Ollama guard proxy's DeepSeek cloud-overflow leg |
| `KIMI_API_KEY` | Kimi (Moonshot) API key — auth for the proxy's Kimi cloud-overflow leg |
| `CLOUD_TOKEN_THRESHOLD` | Fraction (e.g. `0.60`) that the guard proxy multiplies by `PROXY_LANE_CONTEXT_TOKENS` to decide when a request overflows to a cloud plane |

The three proxy variables are consumed by `~/source/repos/n3otech/devops-core/local-ai-agents/ollama/proxy.js`; its header comment documents the overflow ladder (DeepSeek → Kimi → stay local) and the per-model token ceilings.

Because these are machine-scope, they are readable by **every account** on this machine. Prefer user scope for any new secret that should not be machine-wide. Never commit these values, echo them into logs, or embed them in client-side bundles.

## TypeSafe API access

TypeSafe's System One API is available directly from this machine. The API key is in the machine-scope environment variable `TYPESAFE_API_KEY`, so it is already present in every shell — no loading step is required.

- **Endpoint**: `POST https://api.typesafe.ai/v1/systemone`
- **Auth**: `Authorization: Bearer $env:TYPESAFE_API_KEY` (the `Bearer` scheme is required; a raw key is rejected)
- **Model**: `jev-latest` (resolves to the current `jev` release, e.g. `jev-1.13.0`)
- **Body**: `{ "state": <string|object|array>, "model": "jev-latest", "questions": { "<id>": <Question> } }`
- **Question types**: `noul` (yes/no probability), `choice` (one of a defined set + distribution), `score` (ordered levels + distribution). `choice`/`score` answers also carry `confidence`.
- **Errors**: `401` bad key, `422` validation, `429` rate limit, `529` overloaded — back off exponentially on `429`/`529`.

The key is already in the environment of every shell. If a shell somehow lacks it, read it explicitly from machine scope:

```powershell
$env:TYPESAFE_API_KEY = [Environment]::GetEnvironmentVariable('TYPESAFE_API_KEY','Machine')
```

Keep the key server-side in any application code; never commit it or embed it in client-side bundles. Prefer the official SDKs (`typesafe-sdk` for Python, `@typesafe-ai/sdk` for JavaScript) when writing application integrations — they read `TYPESAFE_API_KEY` from the environment and handle retries automatically.

## General agent behavior

- Prefer precise, surgical changes over broad rewrites; don't fix unrelated pre-existing issues unless tightly coupled to the current task.
- Only run linters, builds, and tests that already exist in the repo; use the smallest targeted command that covers the change.
- Prefer ecosystem tools (package managers, scaffolding/refactoring tools, linters) over manual edits.
- Validate changes actually work (build/test/run) before considering a task complete.
- Do not create planning/notes markdown files unless explicitly requested.
