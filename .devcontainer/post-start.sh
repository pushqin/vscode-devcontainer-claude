#!/bin/bash
# =============================================================================
# Post-start: Firewall + OS-level hardening + Git remote setup
# Runs as root via: sudo /usr/local/bin/post-start.sh
# =============================================================================

set -euo pipefail

# --- Firewall ---
/usr/local/bin/init-firewall.sh

# --- Fix volume ownership ---
chown -R node:node /home/node/.claude

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
REPO_URL="github.com/YOUR_USER/YOUR_REPO.git"
PAT_TOKEN="${GH_PAT_FAMILY:-}"

cd /workspace 2>/dev/null || true

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not inside a git repository yet — skipping git configuration."
    echo "=== Hardening complete ==="
    exit 0
fi

su - node -c "cd /workspace && git config --local credential.helper ''"

if [ "$REPO_URL" = "github.com/YOUR_USER/YOUR_REPO.git" ]; then
    echo ""
    echo "  WARNING: REPO_URL not configured in post-start.sh"
    echo ""
fi

if [ -z "$PAT_TOKEN" ]; then
    echo ""
    echo "  WARNING: GH_PAT_FAMILY environment variable is not set."
    echo ""
fi

if [ "$REPO_URL" != "github.com/YOUR_USER/YOUR_REPO.git" ] && [ -n "$PAT_TOKEN" ]; then
    su - node -c "cd /workspace && git remote set-url origin 'https://oauth2:${PAT_TOKEN}@${REPO_URL}'"
    echo "Git remote configured: https://oauth2:****@${REPO_URL}"
else
    echo "Skipping git remote setup (missing repo URL or PAT token)."
fi

echo "=== Hardening complete ==="
