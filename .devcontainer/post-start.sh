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
# here (see HISTFILE in isrotel-workspace/shell/zshrc.zsh).
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
printf '[safe]\n\tdirectory = /workspace/isrotel-workspace\n' > /home/vscode/.gitconfig-safe
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

# --- Git remote setup ---
# REPO_URL and REPO_PAT come from the host env via devcontainer.json.
# sudo strips env vars, so read them from the vscode user's environment.
REPO_URL=$(su - vscode -c 'echo $REPO_URL' 2>/dev/null || true)
REPO_PAT=$(su - vscode -c 'echo $REPO_PAT' 2>/dev/null || true)

cd /workspace/isrotel-workspace 2>/dev/null || true

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not inside a git repository yet — skipping git configuration."
    echo "=== Hardening complete ==="
    exit 0
fi

su - vscode -c "GIT_CONFIG_GLOBAL=/home/vscode/.gitconfig-safe git -C /workspace/isrotel-workspace config --local credential.helper ''"

if [ -z "$REPO_URL" ]; then
    echo ""
    echo "  WARNING: REPO_URL environment variable is not set."
    echo ""
fi

if [ -z "$REPO_PAT" ]; then
    echo ""
    echo "  WARNING: REPO_PAT environment variable is not set."
    echo ""
fi

if [ -n "$REPO_URL" ] && [ -n "$REPO_PAT" ]; then
    su - vscode -c "GIT_CONFIG_GLOBAL=/home/vscode/.gitconfig-safe git -C /workspace/isrotel-workspace remote set-url origin 'https://oauth2:${REPO_PAT}@${REPO_URL}'"
    echo "Git remote configured: https://oauth2:****@${REPO_URL}"
else
    echo "Skipping git remote setup (missing repo URL or PAT token)."
fi

echo "=== Hardening complete ==="
