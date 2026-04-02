FROM node:24

ARG CLAUDE_CODE_VERSION=latest
ARG TZ=America/Los_Angeles
ARG GIT_DELTA_VERSION=0.18.2

# Install system dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    less git procps sudo fzf zsh man-db unzip gnupg2 gh \
    iptables ipset iproute2 dnsutils aggregate jq nano vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install git-delta
RUN curl -L https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_amd64.deb -o /tmp/git-delta.deb \
    && dpkg -i /tmp/git-delta.deb \
    && rm /tmp/git-delta.deb

# Install Claude Code globally (as root)
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Copy firewall script
COPY --chown=root:root init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# =============================================================================
# SUDO ACCESS CONFIGURATION
# =============================================================================
# The firewall script ALWAYS needs sudo (do not comment this line):
RUN echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall

# --- SETUP MODE: Uncomment the line below to give full sudo access ---
# --- Use this during initial container setup, then comment it back ---
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-sudo

# --- To disable: comment the line above and rebuild the container ---
# =============================================================================

# Set default shell to zsh for node user
RUN chsh -s /usr/bin/zsh node

# Switch to non-root user
USER node
WORKDIR /workspace

# Install oh-my-zsh + plugins
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && sed -i 's/plugins=(git)/plugins=(git fzf zsh-autosuggestions)/' ${HOME}/.zshrc

# Set default editor
ENV EDITOR=nano
ENV VISUAL=nano

# Default shell
ENV SHELL=/usr/bin/zsh
