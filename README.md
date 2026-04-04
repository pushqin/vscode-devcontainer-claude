# Secure Devcontainer for AI Agents

An isolated devcontainer setup that gives AI agents (Claude Code, etc.) full CLI permissions inside the container while keeping your Windows host completely locked down. Includes Aperant GUI integration via WSLg.

## Architecture

```
Windows desktop (WSLg renders Aperant window here)
  └── Ubuntu WSL2
       └── Aperant (native Linux Electron app)
            └── PTY shells spawn $SHELL → wrapper script
                 └── docker exec → family-interviewer container
                      └── claude CLI + project files + firewall
```

- **Windows** — only displays the Aperant window (via WSLg)
- **WSL** — runs Aperant and shim scripts, no project code here
- **Docker container** — all agent execution, Claude CLI, firewall rules, project files

## Prerequisites

### Install WSL2 with Ubuntu

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu
```

This will reboot your machine. After reboot, Ubuntu will launch and ask you to create a username and password. Remember the password — you'll need it for `sudo` commands.

To verify WSLg is working (should show a calculator window):

```bash
wsl -- bash -c "sudo apt-get update && sudo apt-get install -y gnome-calculator && gnome-calculator"
```

### Install Docker Desktop

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. In Docker Desktop Settings → Resources → WSL Integration: enable your Ubuntu distro

## Quick Start

### 1. Set up the Dev Container

2. Set your GitHub PAT as a Windows environment variable (scoped to your target repo only):

   ```powershell
   [System.Environment]::SetEnvironmentVariable("GH_PAT_FAMILY", "ghp_your_token_here", "User")
   ```

3. Open the project in VS Code and select "Reopen in Container"

### 2. Set up Aperant (GUI for agent orchestration)

Run in your **WSL Ubuntu terminal** (not inside the container):

Go to wsl , type `wsl` in the windows terminal

```bash
cd /mnt/c/Users/pushq/repos/family-interviewer
bash setup-aperant-wsl.sh
```

This installs:

- Electron GUI dependencies
- Aperant `.deb` package
- Docker-routing wrapper shell (`~/.local/bin/aperant-docker-shell`)
- Claude CLI shim (`~/.local/bin/claude`) — satisfies Aperant's detection while routing all commands into the container
- Launcher script (`~/.local/bin/launch-aperant`)

### 3. Launch Aperant in the wsl terminal

```bash
~/.local/bin/launch-aperant 
```

Then open project folder: `/workspaces/family-interviewer`

**Prerequisite:** The Dev Container must be running (open in VS Code first, or the wrapper will auto-start a stopped container).

### 4. Verify

In an Aperant terminal:

- `hostname` — should show the container ID, not your WSL hostname
- `which claude` — should show `/usr/local/bin/claude`
- `curl http://host.docker.internal:2375` — should be rejected (firewall)

## Setup Mode vs Locked Mode

Two settings profiles control what the AI agent can do:

| Mode             | File                           | Sudo    |
| ---------------- | ------------------------------ | ------- |
| Locked (default) | `.claude/settings.locked.json` | Blocked |
| Setup            | `.claude/settings.setup.json`  | Allowed |

**Enable setup mode** (to install packages, configure the container):

```bash
cp .claude/settings.setup.json .claude/settings.json
```

**Lock down after setup**:

```bash
cp .claude/settings.locked.json .claude/settings.json
```

The Dockerfile also has a commentable section for OS-level sudo access. Uncomment the `node-sudo` line and rebuild the container for full sudo, then comment it back when done.

## PAT Token

The GitHub PAT should be:

- Scoped to **one specific repository** only
- Given **only** commit and push permissions
- Passed via the `GH_PAT_FAMILY` environment variable (not stored in the container)
- Git credential helper is disabled — no caching

## Configuration Files

| File                              | Purpose                                                  |
| --------------------------------- | -------------------------------------------------------- |
| `.devcontainer/devcontainer.json` | Container config, env var sanitization, VS Code settings |
| `.devcontainer/Dockerfile`        | Base image, packages, sudo configuration                 |
| `.devcontainer/init-firewall.sh`  | Blocks dangerous host ports                              |
| `.devcontainer/post-start.sh`     | Firewall init + git remote setup with PAT                |
| `.claude/settings.json`           | Active Claude permissions (locked by default)            |
| `.claude/settings.locked.json`    | Locked profile (sudo blocked)                            |
| `.claude/settings.setup.json`     | Setup profile (sudo allowed)                             |
| `setup-aperant-wsl.sh`            | WSL-side Aperant + shim installer                        |

---

## Security Details

### Credentials blocked from leaking into container

- SSH agent forwarding (disabled)
- Git config from host (`GIT_CONFIG_GLOBAL=/dev/null`)
- VS Code git credential injection (`VSCODE_GIT_ASKPASS_*` cleared)
- VS Code IPC sockets (`VSCODE_IPC_HOOK` cleared)
- Cloud CLI credentials (AWS, Azure, GCP env vars cleared)
- Package manager tokens (NPM, pip, NuGet, Cargo cleared)
- Docker credential store (`DOCKER_CONFIG` cleared)
- GPG keys (`GPG_TTY`, `GPG_AGENT_INFO` cleared)
- Kubernetes/Terraform credentials cleared
- GitHub/GitLab tokens cleared
- Host credential files (`~/.npmrc`, `~/.docker/config.json`, etc.) deleted on container creation

### Network isolation

- Full internet access for the agent to work
- Dangerous host ports blocked (Docker API, databases, admin panels)
- `host.docker.internal` access blocked for Claude via settings deny rules

### File system isolation

- `.devcontainer/` folder mounted read-only — agent cannot modify its own sandbox
- Claude settings deny read/write/edit of `.devcontainer/**`

### Agent restrictions (`.claude/settings.json`)

- `git push` blocked (use manually or enable explicitly)
- `git remote set-url` / `git remote add` blocked (prevents PAT exfiltration to another repo)
- `sudo` blocked in locked mode
- `iptables` / `ipset` blocked (prevents firewall tampering)
- Probing `host.docker.internal` via curl/wget blocked

### VS Code hardening

- GitHub Copilot disabled
- GitHub remote extensions disabled
- Authentication providers disabled
- Settings sync disabled
- Auto port forwarding disabled

### Aperant isolation

- Aperant runs in WSL, not inside the container — no GUI attack surface in the sandbox
- `$SHELL` override routes all PTY sessions into the container
- Claude CLI shim in WSL is a passthrough only — no local execution
- Container auto-starts if stopped, but must be pre-built via VS Code
- `--no-sandbox` is required for Electron in WSLg — disables Chromium sandbox but agents still run in Docker, not in Aperant's process
