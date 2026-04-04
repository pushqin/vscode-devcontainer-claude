#!/bin/bash
# =============================================================================
# Aperant WSL Setup — GUI in WSL (via WSLg), Agents in Docker Container
# =============================================================================
# Run this in your Ubuntu WSL terminal (NOT inside the Docker container):
#   bash setup-aperant-wsl.sh
# =============================================================================
set -euo pipefail

APERANT_VERSION="2.7.6"
CONTAINER_NAME="family-interviewer"
CONTAINER_WORKDIR="/workspaces/family-interviewer"
CONTAINER_USER="node"
CONTAINER_SHELL="/bin/zsh"
WRAPPER_PATH="$HOME/.local/bin/aperant-docker-shell"
LAUNCHER_PATH="$HOME/.local/bin/launch-aperant"
CLAUDE_SHIM_PATH="$HOME/.local/bin/claude"
STUB_PROJECT="/workspaces/family-interviewer"
WINDOWS_REPO="/mnt/c/Users/pushq/repos/family-interviewer"

echo "=== Aperant WSL Setup ==="
echo ""

# Step 1: Install Electron/GUI dependencies
echo "[1/7] Installing GUI dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    libgtk-3-0 libnss3 libatk-bridge2.0-0 libgbm1 libasound2t64 \
    xdg-utils libsecret-1-0 libnotify4 libxss1 libxtst6 \
    libappindicator3-1 wget 2>&1 | tail -1

# Step 2: Download and install Aperant
echo "[2/7] Installing Aperant v${APERANT_VERSION}..."
wget -q -O /tmp/aperant.deb \
    "https://github.com/AndyMik90/Aperant/releases/download/v${APERANT_VERSION}/Auto-Claude-${APERANT_VERSION}-linux-amd64.deb"
sudo dpkg -i /tmp/aperant.deb 2>&1 | tail -2 || sudo apt-get install -f -y 2>&1 | tail -2
rm -f /tmp/aperant.deb

# Step 3: Detect installed binary
APERANT_BIN=$(which auto-claude-ui 2>/dev/null || find /opt /usr -name "auto-claude-ui" -type f 2>/dev/null | head -1)
if [ -z "$APERANT_BIN" ]; then
    echo "ERROR: Could not find Aperant binary after install." >&2
    echo "Try: dpkg -L auto-claude-ui | grep bin" >&2
    exit 1
fi
echo "   Found binary: $APERANT_BIN"

# Step 4: Create wrapper shell (routes Aperant PTY into Docker container)
echo "[3/7] Creating Docker-routing wrapper shell..."
mkdir -p "$(dirname "$WRAPPER_PATH")"
cat > "$WRAPPER_PATH" << EOF
#!/bin/bash
# Aperant PTY → Docker container router
# All agent shells spawned by Aperant land inside the container.
CONTAINER="$CONTAINER_NAME"
WORKDIR="$CONTAINER_WORKDIR"
CUSER="$CONTAINER_USER"
CSHELL="$CONTAINER_SHELL"

# Auto-start stopped container (retry once if Docker is slow to respond)
start_container() {
    if ! docker inspect --format='{{.State.Running}}' "\$CONTAINER" 2>/dev/null | grep -q true; then
        if docker inspect "\$CONTAINER" >/dev/null 2>&1; then
            docker start "\$CONTAINER" >/dev/null
            sleep 2
        else
            return 1
        fi
    fi
    return 0
}

if ! start_container; then
    sleep 2
    if ! start_container; then
        echo "ERROR: Container '\$CONTAINER' not found. Build it first (VS Code → Reopen in Container)." >&2
        # Non-interactive call (-c flag): just exit, don't block
        [ "\${1:-}" = "-c" ] && exit 1
        read -p "Press Enter to exit..."
        exit 1
    fi
fi

# Git env vars to fix safe.directory and fileMode (GIT_CONFIG_SYSTEM=/dev/null blocks config files)
GIT_ENV="-e GIT_CONFIG_COUNT=2 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=\$WORKDIR -e GIT_CONFIG_KEY_1=core.fileMode -e GIT_CONFIG_VALUE_1=false"

# Handle -c flag (used by Aperant for CLI detection like "which claude")
if [ "\${1:-}" = "-c" ]; then
    shift
    exec docker exec -it \$GIT_ENV -w "\$WORKDIR" -u "\$CUSER" "\$CONTAINER" "\$CSHELL" -c "\$*"
fi

# Interactive shell
exec docker exec -it \$GIT_ENV -w "\$WORKDIR" -u "\$CUSER" "\$CONTAINER" "\$CSHELL" -l
EOF
chmod +x "$WRAPPER_PATH"

# Step 5: Create claude CLI shim (routes "claude" commands into container)
echo "[4/7] Creating claude CLI shim..."
cat > "$CLAUDE_SHIM_PATH" << EOF
#!/bin/bash
# Shim: routes claude commands into the Docker container
# Aperant checks for "claude" in PATH — this satisfies detection
# while ensuring all execution happens inside the container.
CONTAINER="$CONTAINER_NAME"
WORKDIR="$CONTAINER_WORKDIR"
CUSER="$CONTAINER_USER"

# Auto-start stopped container
if ! docker inspect --format='{{.State.Running}}' "\$CONTAINER" 2>/dev/null | grep -q true; then
    if docker inspect "\$CONTAINER" >/dev/null 2>&1; then
        docker start "\$CONTAINER" >/dev/null
        sleep 2
    else
        echo "ERROR: Container '\$CONTAINER' does not exist." >&2
        exit 1
    fi
fi

# Use -it only when a TTY is available (Aperant checks run without a TTY)
DOCKER_FLAGS="-i"
if [ -t 0 ]; then
    DOCKER_FLAGS="-it"
fi

exec docker exec \$DOCKER_FLAGS -w "\$WORKDIR" -u "\$CUSER" "\$CONTAINER" /usr/local/bin/claude "\$@"
EOF
chmod +x "$CLAUDE_SHIM_PATH"

# Step 6: Ensure ~/.local/bin is in PATH
echo "[5/7] Ensuring ~/.local/bin is in PATH..."
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    for rcfile in "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$rcfile" ] && ! grep -q 'HOME/.local/bin' "$rcfile"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rcfile"
            echo "   Added to $rcfile"
        fi
    done
    export PATH="$HOME/.local/bin:$PATH"
fi

# Step 7: Create launcher (sets SHELL and launches Aperant)
echo "[6/7] Creating Aperant launcher..."
cat > "$LAUNCHER_PATH" << EOF
#!/bin/bash
# Launch Aperant with agent execution routed into Docker container

# Prepare container: git fixes + sync Claude auth
CONTAINER="$CONTAINER_NAME"
CUSER="$CONTAINER_USER"
WORKDIR="$CONTAINER_WORKDIR"
if docker inspect --format='{{.State.Running}}' "\$CONTAINER" 2>/dev/null | grep -q true; then
    # Sync only known-safe Claude config files (not entire directory — prevents
    # a compromised container from planting malicious scripts in WSL ~/.claude/)
    mkdir -p "\$HOME/.claude"
    for f in .credentials.json .claude.json settings.json; do
        docker cp "\$CONTAINER:/home/\$CUSER/.claude/\$f" "\$HOME/.claude/\$f" 2>/dev/null || true
    done

    # Also sync credentials to Aperant's profile directory
    # Aperant reads OAuth tokens from ~/.claude-profiles/primary/.credentials.json
    mkdir -p "\$HOME/.claude-profiles/primary"
    docker cp "\$CONTAINER:/home/\$CUSER/.claude/.credentials.json" "\$HOME/.claude-profiles/primary/.credentials.json" 2>/dev/null || true

    echo "Claude config synced from container (whitelisted files only)"
fi

export SHELL="$WRAPPER_PATH"
export ELECTRON_OZONE_PLATFORM_HINT=auto
exec "$APERANT_BIN" --no-sandbox "\$@"
EOF
chmod +x "$LAUNCHER_PATH"

# Step 8: Bind-mount project so paths match inside container
echo "[7/7] Setting up project directory..."
# Aperant uses Path.resolve() which follows symlinks — so symlinks won't work.
# A bind mount makes /workspaces/family-interviewer a real directory that
# resolve() keeps as-is. This path matches the container's bind mount.
sudo mkdir -p "$STUB_PROJECT"
if ! mountpoint -q "$STUB_PROJECT" 2>/dev/null; then
    sudo mount --bind "$WINDOWS_REPO" "$STUB_PROJECT"
    echo "   Bind-mounted $STUB_PROJECT -> $WINDOWS_REPO"
else
    echo "   Already mounted: $STUB_PROJECT"
fi

# Make the bind mount persist across WSL restarts
FSTAB_ENTRY="$WINDOWS_REPO $STUB_PROJECT none bind 0 0"
if ! grep -qF "$STUB_PROJECT" /etc/fstab 2>/dev/null; then
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab >/dev/null
    echo "   Added to /etc/fstab for persistence"
fi

# Note: GIT_CONFIG_GLOBAL and GIT_CONFIG_SYSTEM are set to /dev/null in the container,
# so git config --system/--global cannot be used. The wrapper injects git fixes via
# GIT_CONFIG_COUNT/KEY/VALUE env vars on every docker exec call.

# Verify
echo "Verifying..."
echo ""
echo "=== Setup Complete ==="
echo ""
echo "  Architecture:"
echo "    Windows ← WSLg ← Aperant (WSL) → docker exec → container"
echo ""
echo "  To launch Aperant:"
echo "    $LAUNCHER_PATH"
echo ""
echo "  Then open project folder: $STUB_PROJECT"
echo ""
echo "  Make sure the Dev Container is running first (open in VS Code)."
echo ""
echo "  To verify agents run in container:"
echo "    - Open a terminal in Aperant"
echo "    - Run: hostname (should show container ID, not WSL hostname)"
echo "    - Run: which claude (should show /usr/local/bin/claude)"
echo ""
