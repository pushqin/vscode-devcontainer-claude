FROM mcr.microsoft.com/dotnet/sdk:10.0

ARG CLAUDE_CODE_VERSION=latest
ARG TZ=America/Los_Angeles
ARG GIT_DELTA_VERSION=0.18.2
ARG NODE_MAJOR=22
ARG FZF_VERSION=0.56.3
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000


# =============================================================================
# 1. NON-ROOT USER
# =============================================================================
# The .NET SDK image ships with a pre-existing `app` user at UID/GID 1000.
# Reuse it by renaming to ${USERNAME} so the workspace bind mount lines up
# with the host's UID 1000 without colliding on group/user creation.

RUN set -eux; \
    if getent group ${USER_GID} >/dev/null; then \
        existing_group=$(getent group ${USER_GID} | cut -d: -f1); \
        if [ "${existing_group}" != "${USERNAME}" ]; then \
            groupmod -n ${USERNAME} "${existing_group}"; \
        fi; \
    else \
        groupadd --gid ${USER_GID} ${USERNAME}; \
    fi; \
    if getent passwd ${USER_UID} >/dev/null; then \
        existing_user=$(getent passwd ${USER_UID} | cut -d: -f1); \
        if [ "${existing_user}" != "${USERNAME}" ]; then \
            usermod -l ${USERNAME} -d /home/${USERNAME} -m -s /bin/bash "${existing_user}"; \
        fi; \
        usermod -g ${USER_GID} ${USERNAME}; \
    else \
        useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}; \
    fi


# =============================================================================
# 2. SYSTEM PACKAGES
# =============================================================================

# Core tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl ca-certificates less procps sudo man-db unzip gnupg2 nano vim jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Git & GitHub CLI
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Networking & firewall
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    iptables ipset iproute2 dnsutils aggregate \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Shell
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    zsh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# fzf — install from upstream releases. Debian 13 ships an older fzf without
# the `fzf --zsh` integration mode (added in 0.48).
RUN curl -fsSL https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz \
        | tar -xz -C /usr/local/bin \
    && chmod +x /usr/local/bin/fzf


# Modern CLI replacements
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    ripgrep fd-find bat \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/batcat /usr/bin/bat \
    && ln -sf /usr/bin/fdfind /usr/bin/fd


# =============================================================================
# 3. ADDITIONAL TOOL INSTALLS
# =============================================================================

# eza - modern ls replacement with icons and git integration
RUN curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
       | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
       > /etc/apt/sources.list.d/gierens.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends eza \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# zoxide - smart cd that learns your most-used directories
RUN curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- --bin-dir=/usr/local/bin

# git-delta - better diffs with syntax highlighting
RUN curl -L https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_amd64.deb \
    -o /tmp/git-delta.deb \
    && dpkg -i /tmp/git-delta.deb \
    && rm /tmp/git-delta.deb

# Timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# =============================================================================
# 4. NODE.JS + CLAUDE CODE
# =============================================================================
# Claude Code is distributed as an npm package — install Node.js alongside
# the .NET SDK so the agent itself can run inside the container.

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Playwright MCP - install Chrome and its dependencies for browser-based testing
RUN npx playwright install --with-deps chrome


# =============================================================================
# 5. FIREWALL & HARDENING SCRIPTS
# =============================================================================

COPY --chown=root:root init-firewall.sh /usr/local/bin/init-firewall.sh
RUN sed -i 's/\r$//' /usr/local/bin/init-firewall.sh && chmod +x /usr/local/bin/init-firewall.sh

COPY --chown=root:root post-start.sh /usr/local/bin/post-start.sh
RUN sed -i 's/\r$//' /usr/local/bin/post-start.sh && chmod 755 /usr/local/bin/post-start.sh

# Managed settings — root-owned, read-only. Claude Code reads these but cannot
# modify them. Deny rules here are enforced regardless of other settings.
COPY --chown=root:root managed-settings.json /etc/claude-code/managed-settings.json
RUN sed -i 's/\r$//' /etc/claude-code/managed-settings.json \
    && chmod 444 /etc/claude-code/managed-settings.json


# =============================================================================
# 6. SUDO ACCESS
# =============================================================================

# post-start.sh runs as root on every container start (firewall + hardening)
RUN echo "${USERNAME} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall \
    && echo "${USERNAME} ALL=(root) NOPASSWD: /usr/local/bin/post-start.sh" >> /etc/sudoers.d/firewall

# Uncomment for full sudo during initial setup, then comment back and rebuild:
# RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode-sudo


# =============================================================================
# 7. USER & SHELL SETUP
# =============================================================================

# Set default shell to zsh
RUN chsh -s /usr/bin/zsh ${USERNAME}

# Switch to non-root user
USER ${USERNAME}
WORKDIR /workspace

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    -- --unattended

# Third-party zsh plugins
RUN git clone https://github.com/zsh-users/zsh-autosuggestions \
        ${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        ${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
    && git clone https://github.com/MichaelAquilina/zsh-you-should-use \
        ${HOME}/.oh-my-zsh/custom/plugins/you-should-use

# Configure plugins and aliases in .zshrc
# Using printf to avoid Windows line-ending issues.
# Note: fzf is NOT in the oh-my-zsh plugin list — that plugin auto-detects
# Debian's package layout and sources files from /usr/share/doc/fzf/examples
# which our upstream binary doesn't ship. We use `fzf --zsh` directly instead.
RUN sed -i 's/plugins=(git)/plugins=(git gh docker dotnet colored-man-pages sudo zsh-autosuggestions zsh-syntax-highlighting you-should-use)/' ${HOME}/.zshrc \
    && printf '\n# --- Modern CLI aliases ---\nalias ls="eza --icons --group-directories-first"\nalias ll="eza -la --icons --group-directories-first"\nalias tree="eza --tree --icons"\nalias cat="bat --paging=never"\nalias grep="rg"\nalias find="fd"\n\n# --- fzf (native integration) ---\neval "$(fzf --zsh)"\n\n# --- Zoxide (smart cd) ---\neval "$(zoxide init zsh)"\n' >> ${HOME}/.zshrc


# =============================================================================
# 8. ENVIRONMENT
# =============================================================================

ENV EDITOR=nano
ENV VISUAL=nano
ENV SHELL=/usr/bin/zsh
# Disable .NET telemetry and first-run greeting noise inside the agent's shell
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
