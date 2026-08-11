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

## Local model fleet

A tuned Ollama fleet runs locally on this machine (see `~/source/repos/n3otech/devops-core/local-ai-agents/ollama/` for models, docs, and the eval harness).

- Endpoint: `http://127.0.0.1:11435` (guarded proxy — preferred) or `http://127.0.0.1:11434` (direct).
- The proxy and watchdog auto-start at logon via Task Scheduler (`\OllamaGuardProxy`, `\OllamaWatchdog`).

## Environment gotchas (this machine)

- Default shell is **PowerShell 7.6.4** (`pwsh`) — modern syntax (`??`, ternary, `&&`/`||`) is fully supported.
- Windows PowerShell 5.1 (`powershell.exe`) is still present for legacy scripts. When explicitly targeting it, avoid `??`, ternary operators, and `&&`/`||` pipeline chains.
- In Git Bash, Windows CLI flags need `//` (e.g. `schtasks //query`), and non-ASCII payloads via curl get mangled — use Python for HTTP/API tests instead.
- For operations needing elevation (e.g. modifying scheduled tasks), use **Windows Sudo** (`sudo`, v1.0.1) — do not skip them or hand them back to the user. Machine policy is **inline mode** (`HKLM:\...\Sudo Enabled=3`), so prefer `sudo --inline <cmd>` and read stdout directly (UAC prompt appears on the user's screen each time). Plain `sudo` opens a separate window whose stdout is not captured; if that is ever the mode again, redirect the elevated command's output to a file and read it back.
- Never use `:` in filenames (creates NTFS alternate data streams).

## Skills to use

Skills live under `~\.copilot\skills\<skill-name>\SKILL.md` or `~\.copilot\installed-plugins\<plugin>\skills\<skill-name>\SKILL.md` — read the skill file before applying it. Use the relevant skill whenever its description matches the task at hand, rather than solving it manually:

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

Check for newly available skills each session, as this list may not be exhaustive going forward.

## General agent behavior

- Prefer precise, surgical changes over broad rewrites; don't fix unrelated pre-existing issues unless tightly coupled to the current task.
- Only run linters, builds, and tests that already exist in the repo; use the smallest targeted command that covers the change.
- Prefer ecosystem tools (package managers, scaffolding/refactoring tools, linters) over manual edits.
- Validate changes actually work (build/test/run) before considering a task complete.
- Do not create planning/notes markdown files unless explicitly requested.
