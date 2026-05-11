# Secure Devcontainer for AI Agents

An isolated devcontainer that gives AI agents (Claude Code, etc.) full autonomy inside the container — including `--dangerously-skip-permissions` — while keeping your host locked down. All protection is OS-level: the agent runs as an unprivileged user with no sudo, immutable safeguard files, a network firewall, and sanitized credentials.

Works with any git host (GitHub, GitLab, Bitbucket, Azure DevOps, self-hosted Gitea, etc.) — the setup is git-host agnostic.

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

3. Copy the `.devcontainer/` folder from this repo into your target project

4. Open the project in VS Code and select "Reopen in Container"

5. Run `claude login` to authenticate, then `claude --dangerously-skip-permissions`

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

- Full internet access for the agent to work
- Dangerous host ports blocked: Docker API, databases (PostgreSQL, MySQL, Redis, MongoDB, Elasticsearch), admin panels
- `host.docker.internal` dangerous ports blocked

## Setup Mode

To install packages or configure the container during initial setup, uncomment the full-sudo line in the Dockerfile and rebuild:

```dockerfile
# In .devcontainer/Dockerfile, uncomment:
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-sudo
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
| `.devcontainer/devcontainer.json` | Container config, env var sanitization, per-project volumes, VS Code settings |
| `.devcontainer/Dockerfile` | Base image, packages, sudo configuration |
| `.devcontainer/init-firewall.sh` | Blocks dangerous host ports |
| `.devcontainer/post-start.sh` | OS-level hardening + git remote setup (reads `REPO_URL` / `REPO_PAT` from env) |
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
- Host credential files (`~/.npmrc`, `~/.docker/config.json`, etc.) deleted on container creation

Only `REPO_PAT` and `REPO_URL` are explicitly forwarded to the container.

## VS Code Hardening

- `.devcontainer/` hidden from file explorer and marked read-only inside the container
- GitHub Copilot and remote extensions blocked
- Authentication providers disabled
- Settings sync and auto port forwarding disabled
