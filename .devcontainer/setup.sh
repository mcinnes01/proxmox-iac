#!/bin/bash
set -e

echo "🏠 Setting up Proxmox K3s Homelab DevContainer..."
echo "=============================================="

# Debug: List current files before setup
echo "📋 Files before setup:"
ls -la /workspaces/proxmox-iac/ | head -20
echo ""

# Check required tools
echo "🔧 Checking required tools..."
for tool in terraform git ssh; do
    if command -v $tool &> /dev/null; then
        echo "✅ $tool is installed"
    else
        echo "❌ $tool is NOT installed"
    fi
done

# Create required directories
echo "📁 Creating required directories..."
mkdir -p ~/.ssh
mkdir -p ~/.kube
chmod 700 ~/.ssh

# Terraform setup
echo "🏗️ Terraform setup information:"
echo "   • Version: $(terraform version -json | jq -r '.terraform_version')"
echo "   • Working directory: /workspaces/proxmox-iac/terraform"
echo "   • Configure your provider.tf and terraform.tfvars files"

# SSH key setup
echo "🔐 SSH key setup:"
echo "   • Place your SSH private key at ~/.ssh/proxmox-k3s"
echo "   • Make sure it has proper permissions: chmod 600 ~/.ssh/proxmox-k3s"

# Network configuration
echo "🌐 Network configuration:"
echo "   • Proxmox server: 192.168.1.1"
echo "   • K3s nodes: 192.168.1.2 - 192.168.1.50"
echo "   • Configure your network settings in terraform.tfvars"

# Create aliases
echo "🔗 Setting up aliases..."
cat >> ~/.bashrc << 'EOF'
alias k='kubectl'
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'
alias deploy='bash deploy-k3s.sh'
EOF

echo ""
echo "🎉 DevContainer setup complete!"
echo "Ready to deploy: bash deploy-k3s.sh"

# Debug: List files after setup
echo ""
echo "📋 Files after setup:"
ls -la /workspaces/proxmox-iac/ | head -20