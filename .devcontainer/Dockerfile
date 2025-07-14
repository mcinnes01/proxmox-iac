# Talos Proxmox Homelab DevContainer
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    jq \
    unzip \
    make \
    gnupg \
    lsb-release \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform from HashiCorp repository
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install Helm
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update && apt-get install -y helm \
    && rm -rf /var/lib/apt/lists/*

# Install Talos CLI
ARG TALOS_VERSION=v1.10.5
RUN curl -sL https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-amd64 -o /tmp/talosctl \
    && install /tmp/talosctl /usr/local/bin/talosctl \
    && rm /tmp/talosctl

# Install Cilium CLI
ARG CILIUM_VERSION=v0.16.28
RUN curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-amd64.tar.gz \
    && tar xzf cilium-linux-amd64.tar.gz -C /usr/local/bin \
    && rm cilium-linux-amd64.tar.gz

# Install Flux CLI
ARG FLUX_VERSION=v2.5.1
RUN curl -s https://fluxcd.io/install.sh | bash -s -- --version=${FLUX_VERSION}

# Install additional tools
RUN curl -sL https://github.com/derailed/k9s/releases/download/v0.32.8/k9s_Linux_amd64.tar.gz | tar xz -C /tmp \
    && install /tmp/k9s /usr/local/bin/k9s \
    && rm /tmp/k9s

RUN curl -sL https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 -o /tmp/yq \
    && install /tmp/yq /usr/local/bin/yq \
    && rm /tmp/yq

RUN curl -sL https://github.com/mozilla/sops/releases/download/v3.9.3/sops-v3.9.3.linux.amd64 -o /tmp/sops \
    && install /tmp/sops /usr/local/bin/sops \
    && rm /tmp/sops

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Set up Git configuration for proper line endings
RUN git config --global core.autocrlf false \
    && git config --global core.eol lf

# Create required directories
RUN mkdir -p /home/vscode/.ssh /home/vscode/.kube \
    && chmod 700 /home/vscode/.ssh \
    && chown -R vscode:vscode /home/vscode

USER vscode
