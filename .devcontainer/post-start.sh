#!/bin/bash
# =============================================================================
# Post-start: Firewall + OS-level hardening + Git remote setup
# Runs as root via: sudo /usr/local/bin/post-start.sh
# =============================================================================

set -euo pipefail

# --- Firewall ---
/usr/local/bin/init-firewall.sh

# --- Fix volume ownership ---
chown -R vscode:vscode /home/vscode/.claude
mkdir -p /home/vscode/.nuget/packages
chown -R vscode:vscode /home/vscode/.nuget
# Named volume mounts as root:root on first creation; zsh writes its history
# here (see HISTFILE in <workspace>/shell/zshrc.zsh).
mkdir -p /commandhistory
chown -R vscode:vscode /commandhistory

# --- Seed default Claude config (first-time only) ---
# Volume is empty on first start; copy baked-in defaults so the user doesn't
# have to re-configure plugins, theme, etc. To re-seed, delete the named volume
# (claude-code-<workspace>-config) and rebuild.
if [ ! -f /home/vscode/.claude/settings.json ] && [ -d /etc/claude-code-defaults ]; then
    cp -rn /etc/claude-code-defaults/. /home/vscode/.claude/
    chown -R vscode:vscode /home/vscode/.claude
    echo "[seed] Default Claude config seeded into /home/vscode/.claude."
fi

# --- Git safe directory (mounted workspace has different owner) ---
# GIT_CONFIG_GLOBAL points to this file (host gitconfig is blocked via /dev/null override)
# Discover every git working tree at /workspace/<repo> at startup so this script
# stays project-agnostic. Each found repo gets a safe.directory entry so git
# stops complaining about dubious ownership.
WORKSPACE_REPOS=$(find /workspace -mindepth 2 -maxdepth 2 -type d -name .git -printf '%h ' 2>/dev/null)
{
    printf '[safe]\n'
    for repo in $WORKSPACE_REPOS; do
        printf '\tdirectory = %s\n' "$repo"
    done
} > /home/vscode/.gitconfig-safe
chown vscode:vscode /home/vscode/.gitconfig-safe

# --- Immutable safeguard files ---
chattr +i /usr/local/bin/init-firewall.sh 2>/dev/null || true
chattr +i /usr/local/bin/post-start.sh 2>/dev/null || true
chattr +i /etc/claude-code/managed-settings.json 2>/dev/null || true
echo "[hardening] Startup scripts and managed settings immutable."

# --- Sudoers ---
chattr +i /etc/sudoers 2>/dev/null || true
chattr +i /etc/sudoers.d/firewall 2>/dev/null || true
find /etc/sudoers.d/ -type f ! -name firewall -delete 2>/dev/null || true
echo "[hardening] Sudoers locked."

# --- User database ---
chattr +i /etc/passwd 2>/dev/null || true
chattr +i /etc/shadow 2>/dev/null || true
chattr +i /etc/group 2>/dev/null || true
echo "[hardening] User database locked."

# --- Strip setuid/setgid binaries ---
KEEP_SUID="/usr/bin/sudo /usr/bin/su"
while IFS= read -r binary; do
    skip=false
    for keep in $KEEP_SUID; do
        [ "$binary" = "$keep" ] && skip=true && break
    done
    if [ "$skip" = false ]; then
        chmod u-s,g-s "$binary" 2>/dev/null || true
    fi
done < <(find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null)
echo "[hardening] Setuid/setgid binaries stripped."

# --- Per-repo git config (project-agnostic) ---
# Clear any inherited credential helper from the host's gitconfig so credentials
# don't leak from the host keychain into container git ops. Runs for every git
# working tree discovered under /workspace.
#
# Project-specific remote setup (e.g., injecting a PAT into a specific repo's
# origin URL) lives inside the workspace itself (e.g., project/setup-remote.sh)
# and is invoked from the workspace's shell init rather than from here.
for repo in $WORKSPACE_REPOS; do
    if [ ! -d "$repo/.git" ]; then
        continue
    fi
    su - vscode -c "GIT_CONFIG_GLOBAL=/home/vscode/.gitconfig-safe git -C '$repo' config --local credential.helper ''"
done

echo "=== Hardening complete ==="
