# Talos Proxmox Homelab DevContainer
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install system dependencies
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
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install other tools
RUN curl -s https://fluxcd.io/install.sh | bash && \
    curl -sL https://github.com/siderolabs/talos/releases/download/v1.10.5/talosctl-linux-amd64 -o /usr/local/bin/talosctl && \
    chmod +x /usr/local/bin/talosctl && \
    curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/v0.16.28/cilium-linux-amd64.tar.gz && \
    tar xzf cilium-linux-amd64.tar.gz && \
    mv cilium /usr/local/bin/ && \
    rm cilium-linux-amd64.tar.gz

USER vscode
