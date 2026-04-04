#!/bin/bash
# =============================================================================
# Post-start: Firewall + Git remote configuration
# =============================================================================

set -euo pipefail

# --- Firewall ---
sudo /usr/local/bin/init-firewall.sh

# --- Git credential isolation + remote setup ---
# >>> EDIT THIS: Set your GitHub repo URL below <<<
REPO_URL="github.com/pushqin/family-interviewer.git"

PAT_TOKEN="${GH_PAT_FAMILY:-}"

cd /workspaces/family-interviewer 2>/dev/null || true

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not inside a git repository yet — skipping git configuration."
    exit 0
fi

git config --local credential.helper ""

if [ "$REPO_URL" = "github.com/YOUR_USER/YOUR_REPO.git" ]; then
    echo ""
    echo "============================================================"
    echo "  WARNING: Git repo URL not configured!"
    echo "============================================================"
    echo ""
    echo "  Edit .devcontainer/post-start.sh and change REPO_URL to"
    echo "  your actual GitHub repo URL."
    echo ""
    echo "  See README.md for details."
    echo "============================================================"
    echo ""
fi

if [ -z "$PAT_TOKEN" ]; then
    echo ""
    echo "============================================================"
    echo "  WARNING: GH_PAT_FAMILY environment variable is not set!"
    echo "============================================================"
    echo ""
    echo "  Git push/pull will not work without a PAT token."
    echo ""
    echo "  To fix:"
    echo "    1. Create a GitHub PAT scoped to your target repo"
    echo "    2. Set it as an environment variable on your Windows host:"
    echo "       setx GH_PAT_FAMILY \"ghp_your_token_here\""
    echo "    3. Rebuild the container"
    echo ""
    echo "  See README.md for details."
    echo "============================================================"
    echo ""
fi

if [ "$REPO_URL" != "github.com/YOUR_USER/YOUR_REPO.git" ] && [ -n "$PAT_TOKEN" ]; then
    git remote set-url origin "https://oauth2:${PAT_TOKEN}@${REPO_URL}"
    echo "Git remote configured: https://oauth2:****@${REPO_URL}"
else
    echo "Skipping git remote setup (missing repo URL or PAT token)."
fi
