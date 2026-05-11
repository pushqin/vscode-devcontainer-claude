FROM node:24

ARG CLAUDE_CODE_VERSION=latest
ARG TZ=America/Los_Angeles
ARG GIT_DELTA_VERSION=0.18.2


# =============================================================================
# 1. SYSTEM PACKAGES
# =============================================================================

# Core tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    less procps sudo man-db unzip gnupg2 nano vim jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Git & GitHub
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    git gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Networking & firewall
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    iptables ipset iproute2 dnsutils aggregate \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Shell
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    zsh fzf \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Modern CLI replacements
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    ripgrep fd-find bat \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/batcat /usr/bin/bat \
    && ln -sf /usr/bin/fdfind /usr/bin/fd



# =============================================================================
# 2. ADDITIONAL TOOL INSTALLS
# =============================================================================

# eza - modern ls replacement with icons and git integration
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
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
# 3. CLAUDE CODE
# =============================================================================

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Playwright MCP - install Chrome and its dependencies
RUN npx playwright install --with-deps chrome


# =============================================================================
# 4. FIREWALL & HARDENING SCRIPTS
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
# 5. SUDO ACCESS
# =============================================================================

# post-start.sh runs as root on every container start (firewall + hardening)
RUN echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall \
    && echo "node ALL=(root) NOPASSWD: /usr/local/bin/post-start.sh" >> /etc/sudoers.d/firewall

# Uncomment for full sudo during initial setup, then comment back and rebuild:
# RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-sudo


# =============================================================================
# 6. USER & SHELL SETUP
# =============================================================================

# Set default shell to zsh
RUN chsh -s /usr/bin/zsh node

# Switch to non-root user
USER node
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
# Using printf to avoid Windows line-ending issues
RUN sed -i 's/plugins=(git)/plugins=(git fzf gh docker colored-man-pages sudo zsh-autosuggestions zsh-syntax-highlighting you-should-use)/' ${HOME}/.zshrc \
    && printf '\n# --- Modern CLI aliases ---\nalias ls="eza --icons --group-directories-first"\nalias ll="eza -la --icons --group-directories-first"\nalias tree="eza --tree --icons"\nalias cat="bat --paging=never"\nalias grep="rg"\nalias find="fd"\n\n# --- Zoxide (smart cd) ---\neval "$(zoxide init zsh)"\n' >> ${HOME}/.zshrc


# =============================================================================
# 7. ENVIRONMENT
# =============================================================================

ENV EDITOR=nano
ENV VISUAL=nano
ENV SHELL=/usr/bin/zsh
