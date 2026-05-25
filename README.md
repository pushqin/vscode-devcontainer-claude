# Secure .NET 10 Devcontainer for AI Agents

An isolated devcontainer that gives AI agents (Claude Code, etc.) full autonomy inside a .NET 10 SDK environment — including `--dangerously-skip-permissions` — while keeping your host locked down. All protection is OS-level: the agent runs as an unprivileged user with no sudo, immutable safeguard files, a network firewall, and sanitized credentials.

Built on `mcr.microsoft.com/dotnet/sdk:10.0` with Node.js 22 LTS layered on for Claude Code itself. Works with any git host (GitHub, GitLab, Bitbucket, Azure DevOps, self-hosted Gitea, etc.) — the setup is git-host agnostic.

## Quick Start

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/macOS) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux)

2. Set two environment variables on the host — a personal access token scoped to the target repo, and the repo URL (without scheme and without embedded credentials):

   **Windows (PowerShell):**
   ```powershell
   [System.Environment]::SetEnvironmentVariable("REPO_PAT", "your_token_here", "User")
   [System.Environment]::SetEnvironmentVariable("REPO_URL", "github.com/youruser/yourrepo.git", "User")
   ```

   **Linux/macOS (add to `~/.bashrc` or `~/.zshrc`):**
   ```bash
   export REPO_PAT="your_token_here"
   export REPO_URL="github.com/youruser/yourrepo.git"
   ```

   `REPO_URL` examples for other hosts:
   - GitLab: `gitlab.com/group/project.git`
   - Bitbucket: `bitbucket.org/team/repo.git`
   - Azure DevOps: `dev.azure.com/org/project/_git/repo`
   - Self-hosted: `git.example.com/group/repo.git`

3. Get the `.devcontainer/` into your project — pick one of the two layouts in [Usage Layouts](#usage-layouts) below

4. Open the project (or parent directory, for the multi-repo layout) in VS Code and select "Reopen in Container"

5. Run `claude login` to authenticate, then `claude --dangerously-skip-permissions`

6. Build / run the .NET project as usual:
   ```bash
   dotnet restore
   dotnet build
   dotnet run --project src/YourProject
   ```

## Usage Layouts

The `.devcontainer/` itself is project-agnostic — `post-start.sh` discovers every `/workspace/<repo>/.git` at runtime and the baked-in `.zshrc` sources any `/workspace/*-workspace/shell/zshrc.zsh` it finds. Two layouts work out of the box:

### Mode A — Drop-in for a single project

Copy the `.devcontainer/` folder into the root of an existing project repo:

```
my-project/                          ← open this in VS Code
├── .devcontainer/                   ← copied from this repo
├── .git/                            ← the project repo's own git
├── src/
└── ...
```

When "Reopen in Container" mounts the parent into `/workspace`, the project repo at `/workspace/` is the single git working tree; the discovery loop gives it a `safe.directory` entry. Optionally, place a `shell/zshrc.zsh` if you want auto-sourced shell init (rename your project folder to `<name>-workspace/` so the `*-workspace` glob picks it up — or skip).

### Mode B — Multi-repo wrapper (workspace + sibling project repos)

Use this repo (or a copy) as a per-project parent dir, and drop your workspace + project repos as siblings under it:

```
<project>-devcontainer/              ← open this in VS Code (the parent dir)
├── .devcontainer/                   ← in sync with this upstream
├── <project>-workspace/             ← planning workspace (its own git)
│   └── shell/zshrc.zsh              ← auto-sourced by the *-workspace glob
├── <project>-backend/               ← e.g. .NET, Java, Python (its own git)
└── <project>-frontend/              ← e.g. Next.js, Vite, etc. (its own git)
```

Every sibling with a `.git/` gets a `safe.directory` entry. Any `*-workspace/shell/zshrc.zsh` is auto-sourced into the agent's shell. No per-project edits to `.devcontainer/` needed — the same image works for the next project by swapping the workspace + project siblings.

## What's in the Container

- **.NET 10 SDK** (`mcr.microsoft.com/dotnet/sdk:10.0`) — `dotnet` CLI, MSBuild, NuGet
- **Node.js 22 LTS** — required runtime for Claude Code itself
- **Claude Code** (`@anthropic-ai/claude-code`) installed globally
- **Playwright + Chrome** — for browser-based testing via MCP
- **Git + GitHub CLI** (`git`, `gh`)
- **Shell**: zsh with oh-my-zsh, autosuggestions, syntax highlighting, fzf, zoxide
- **Modern CLI**: ripgrep, fd, bat, eza, git-delta
- **Telemetry off**: `DOTNET_CLI_TELEMETRY_OPTOUT=1`, `DOTNET_NOLOGO=1`

## Port Forwarding

The following ports are pre-listed in `devcontainer.json:forwardPorts`. The .NET ports are intrinsic to this image; the rest are common dev-stack pre-fills carried as a convenience so you don't have to add them per project. Edit the array to suit — auto port forwarding is disabled, so only what's listed is forwarded.

| Port(s) | Common use | Why it's here |
|---|---|---|
| 5000, 5001 | ASP.NET Core / Kestrel (HTTP/HTTPS) | .NET 10 SDK default — intrinsic to this devcontainer |
| 3000 | Node-stack dev server (Next.js, Vite, CRA, …) | Common pre-fill |
| 5277, 5278, 5279 | Umbraco `launchSettings.json` defaults | Common pre-fill |

## Running Multiple Devcontainers

You can run several isolated devcontainers in parallel (one per project) without conflicts:

- Container name includes the project folder name: `Claude Code .NET 10 - <project-folder>`
- Per-project volumes for zsh history, Claude config, and the NuGet packages cache (`claude-code-<project>-zshhistory`, `…-config`, `…-nuget`)
- Each container needs its own `claude login` (configs are not shared)

If you want different `REPO_PAT` / `REPO_URL` values per project, set them in a shell scoped to that project before launching VS Code, or use a `.env` loader. The host env vars are read at container start.

## How It Works

Claude runs with `--dangerously-skip-permissions`, which bypasses Claude's own permission system entirely. Protection comes from three layers:

### 1. OS-Level Hardening (post-start.sh)

On every container start, a root-owned script enforces:

- **No sudo** — sudoers config is `chattr +i` (immutable), only allows the firewall and post-start scripts
- **Immutable safeguard files** — startup scripts and managed settings are `chattr +i`
- **Locked user database** — `/etc/passwd`, `/etc/shadow`, `/etc/group` are `chattr +i`
- **Setuid binaries stripped** — prevents privilege escalation via suid exploits

### 2. Managed Settings (/etc/claude-code/managed-settings.json)

Root-owned, read-only, immutable. Deny rules here are enforced by Claude Code regardless of any other settings. Blocks:

- `sudo`, `chattr`, `iptables`, `mount/umount`
- Reading/writing `.devcontainer/` and `/etc/claude-code/`
- Reading/writing the startup scripts
- `git remote set-url/add` (prevents PAT exfiltration)
- Probing `host.docker.internal`

### 3. Network Firewall (init-firewall.sh)

- Full internet access for the agent (NuGet, npm, GitHub, etc.)
- Dangerous host ports blocked: Docker API, databases (PostgreSQL, MySQL, Redis, MongoDB, Elasticsearch), admin panels
- `host.docker.internal` dangerous ports blocked

## Setup Mode

To install packages or configure the container during initial setup, uncomment the full-sudo line in the Dockerfile and rebuild:

```dockerfile
# In .devcontainer/Dockerfile, uncomment:
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode-sudo
```

Comment it back and rebuild when done.

## Personal Access Token

Create a PAT on your git host scoped narrowly to the target repo:

- **GitHub** — [fine-grained tokens](https://github.com/settings/tokens?type=beta): select only the target repo, grant **Contents: Read and write**
- **GitLab** — [project access tokens](https://docs.gitlab.com/user/project/settings/project_access_tokens/): scope `read_repository` + `write_repository`
- **Bitbucket** — [repository access tokens](https://support.atlassian.com/bitbucket-cloud/docs/repository-access-tokens/): scopes `repository`, `repository:write`
- **Azure DevOps** — PAT with **Code (Read & Write)** for the target project
- **Other hosts** — equivalent narrow read/write scope on the single target repo

The token should be:
- Scoped to **one specific repository** only
- Limited to repository read/write (no admin, no org-wide access)
- Passed via the `REPO_PAT` environment variable (not stored in the container)
- Git credential helper is disabled inside the container — no caching

## Configuration Files

| File | Purpose |
|------|---------|
| `.devcontainer/devcontainer.json` | Container config, env var sanitization, per-project volumes, port forwarding |
| `.devcontainer/Dockerfile` | .NET 10 SDK base + Node + Claude Code + hardening |
| `.devcontainer/init-firewall.sh` | Blocks dangerous host ports |
| `.devcontainer/post-start.sh` | OS-level hardening + git `safe.directory` discovery for every `/workspace/<repo>/.git` + per-repo `credential.helper ''` clear |
| `.devcontainer/managed-settings.json` | Claude Code deny rules (baked into image) |

## Credential Isolation

The following are sanitized or blocked from entering the container:

- SSH agent forwarding
- Git config from host (`GIT_CONFIG_GLOBAL=/dev/null`)
- VS Code git credential injection (`VSCODE_GIT_ASKPASS_*`)
- VS Code IPC sockets
- Cloud CLI credentials (AWS, Azure, GCP)
- Package manager tokens (NPM, pip, NuGet, Cargo)
- Docker credential store
- GPG keys
- Kubernetes/Terraform credentials
- Git host tokens (`GITHUB_TOKEN`, `GH_TOKEN`, `GITLAB_TOKEN`, etc.)
- Host credential files (`~/.npmrc`, `~/.docker/config.json`, `~/.nuget/NuGet.Config`, etc.) deleted on container creation

Only `REPO_PAT` and `REPO_URL` are forwarded to the container — as a pass-through channel for the workspace's own remote-setup logic (e.g., rewriting `origin` with the PAT for an ADO repo). The devcontainer does not consume them itself; it's up to your workspace's `shell/zshrc.zsh` or a project-level script to use them.

## NuGet Configuration

The container starts with no host-side NuGet credentials. Add per-project `NuGet.Config` files at your repo root if you need private feeds — the agent can read these from `/workspace` (they're committed alongside the code), but cannot reach into the host's `~/.nuget/NuGet.Config`.

The NuGet package cache (`~/.nuget/packages`) is stored in a per-project named volume, so restores survive container rebuilds and don't collide between projects.

## VS Code Hardening

- `.devcontainer/` hidden from file explorer and marked read-only inside the container
- GitHub Copilot and remote extensions blocked
- Authentication providers disabled
- Settings sync and auto port forwarding disabled
- C# Dev Kit + C# extensions pre-installed
