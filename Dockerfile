FROM ubuntu:24.04

ARG NEOVIM_VERSION=v0.10.3
ARG GH_VERSION=2.65.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    luajit \
    lua5.1 \
    luarocks \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Neovim
RUN curl -fsSL "https://github.com/neovim/neovim/releases/download/${NEOVIM_VERSION}/nvim-linux64.tar.gz" \
    | tar xz -C /opt \
    && ln -s /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim

# Install GitHub CLI
RUN curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
    | tar xz -C /opt \
    && ln -s "/opt/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh

# Create directories for Neovim plugins
ENV NVIM_DATA_DIR=/root/.local/share/nvim
RUN mkdir -p ${NVIM_DATA_DIR}/site/pack/deps/start

# Install plenary.nvim
RUN git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git \
    ${NVIM_DATA_DIR}/site/pack/deps/start/plenary.nvim

# Install mini.nvim (for mini.test)
RUN git clone --depth 1 https://github.com/echasnovski/mini.nvim.git \
    ${NVIM_DATA_DIR}/site/pack/deps/start/mini.nvim

WORKDIR /plugin

# Allow mounted volumes with different ownership
RUN git config --global --add safe.directory /plugin

# Configure gh CLI as git credential helper (for HTTPS remote access with GH_TOKEN)
RUN gh auth setup-git 2>/dev/null || true

# The plugin source is mounted here via docker-compose
CMD ["bash"]
