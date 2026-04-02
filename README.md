# Secure Devcontainer for AI Agents

An isolated devcontainer setup that gives AI agents (Claude Code, etc.) full CLI permissions inside the container while keeping your Windows host completely locked down.

## Quick Start

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)

2. Set your GitHub PAT as a Windows environment variable (scoped to your target repo only):
   ```powershell
   [System.Environment]::SetEnvironmentVariable("GH_PAT_FAMILY", "ghp_your_token_here", "User")
   ```

3. Copy all files from this repo into your target project

4. Edit `.devcontainer/post-start.sh` — change the repo URL:
   ```bash
   REPO_URL="github.com/youruser/yourrepo.git"
   ```

5. Open the project in VS Code and select "Reopen in Container"

## Setup Mode vs Locked Mode

Two settings profiles control what the AI agent can do:

| Mode | File | Sudo |
|------|------|------|
| Locked (default) | `.claude/settings.locked.json` | Blocked |
| Setup | `.claude/settings.setup.json` | Allowed |

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

| File | Purpose |
|------|---------|
| `.devcontainer/devcontainer.json` | Container config, env var sanitization, VS Code settings |
| `.devcontainer/Dockerfile` | Base image, packages, sudo configuration |
| `.devcontainer/init-firewall.sh` | Blocks dangerous host ports |
| `.devcontainer/post-start.sh` | Firewall init + git remote setup with PAT |
| `.claude/settings.json` | Active Claude permissions (locked by default) |
| `.claude/settings.locked.json` | Locked profile (sudo blocked) |
| `.claude/settings.setup.json` | Setup profile (sudo allowed) |

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
