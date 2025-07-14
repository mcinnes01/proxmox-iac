#!/bin/bash
set -e

echo "🏠 Setting up Talos Proxmox Homelab DevContainer..."

# Create required directories
mkdir -p ~/.ssh ~/.kube /workspaces/proxmox-iac/terraform/output
chmod 700 ~/.ssh

# Add simple aliases
echo "# Homelab aliases" >> ~/.bashrc
echo "alias k='kubectl'" >> ~/.bashrc
echo "alias tf='terraform'" >> ~/.bashrc
echo "alias t='talosctl'" >> ~/.bashrc

echo "✅ DevContainer setup complete!"
