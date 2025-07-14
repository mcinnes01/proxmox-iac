#!/bin/bash
set -e

echo "🏠 Setting up Talos Proxmox Homelab DevContainer..."

# Install Talos CLI
echo "Installing Talos CLI..."
TALOS_VERSION="v1.10.5"
curl -sL https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-amd64 -o /tmp/talosctl
sudo install /tmp/talosctl /usr/local/bin/talosctl
rm /tmp/talosctl

# Install Cilium CLI
echo "Installing Cilium CLI..."
CILIUM_VERSION="v0.16.28"
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzf cilium-linux-amd64.tar.gz -C /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Install Flux CLI
echo "Installing Flux CLI..."
curl -s https://fluxcd.io/install.sh | sudo bash

# Create required directories
mkdir -p ~/.ssh ~/.kube /workspaces/proxmox-iac/terraform/output
chmod 700 ~/.ssh

# Add aliases
echo "# Homelab aliases" >> ~/.bashrc
echo "alias k='kubectl'" >> ~/.bashrc
echo "alias tf='terraform'" >> ~/.bashrc
echo "alias t='talosctl'" >> ~/.bashrc

echo "✅ DevContainer setup complete!"
