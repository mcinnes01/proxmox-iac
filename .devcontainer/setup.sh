#!/bin/bash
set -e

echo "🏠 Setting up Talos Proxmox Homelab DevContainer..."
echo "=================================================="

# Update package index
sudo apt-get update

# Install additional required packages
echo "📦 Installing additional tools..."
sudo apt-get install -y wget curl git jq unzip make

# Install Talos CLI
echo "🔧 Installing Talos CLI..."
TALOS_VERSION="v1.10.5"
curl -sL https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-amd64 -o /tmp/talosctl
sudo install /tmp/talosctl /usr/local/bin/talosctl
rm /tmp/talosctl

# Install Cilium CLI
echo "🌐 Installing Cilium CLI..."
CILIUM_VERSION="v0.16.28"
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzf cilium-linux-amd64.tar.gz -C /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Install Flux CLI
echo "🔄 Installing Flux CLI..."
FLUX_VERSION="v2.5.1"
curl -s https://fluxcd.io/install.sh | sudo bash -s -- --version=${FLUX_VERSION}

# Install additional tools
echo "⚙️ Installing additional Kubernetes tools..."

# Install k9s (Kubernetes dashboard)
K9S_VERSION="v0.32.8"
curl -sL https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz | tar xz -C /tmp
sudo install /tmp/k9s /usr/local/bin/k9s
rm /tmp/k9s

# Install yq (YAML processor)
YQ_VERSION="v4.45.1"
curl -sL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -o /tmp/yq
sudo install /tmp/yq /usr/local/bin/yq
rm /tmp/yq

# Install SOPS (secrets management)
SOPS_VERSION="v3.9.3"
curl -sL https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 -o /tmp/sops
sudo install /tmp/sops /usr/local/bin/sops
rm /tmp/sops

# Create required directories
echo "� Creating required directories..."
mkdir -p ~/.ssh ~/.kube /workspaces/proxmox-iac/terraform/output
chmod 700 ~/.ssh

# Set up Git configuration for line endings
echo "⚙️ Configuring Git for proper line endings..."
git config --global core.autocrlf false
git config --global core.eol lf

# Create useful aliases and functions
echo "� Setting up aliases and functions..."
cat >> ~/.bashrc << 'EOF'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'

# Terraform aliases
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'

# Talos aliases
alias t='talosctl'
alias th='talosctl health'
alias tn='talosctl nodes'
alias tl='talosctl logs'

# Cilium aliases
alias cs='cilium status'
alias ch='cilium connectivity test'

# Homelab functions
homelab-status() {
    echo "🏠 Homelab Cluster Status"
    echo "========================"
    echo ""
    
    # Check if configs exist
    if [[ -f "/workspaces/proxmox-iac/terraform/output/kube-config.yaml" ]]; then
        export KUBECONFIG="/workspaces/proxmox-iac/terraform/output/kube-config.yaml"
        echo "📋 Kubernetes Nodes:"
        kubectl get nodes -o wide || echo "❌ Cannot connect to Kubernetes API"
        echo ""
        
        echo "� System Pods:"
        kubectl get pods -n kube-system || echo "❌ Cannot get system pods"
        echo ""
        
        echo "🌐 Cilium Status:"
        cilium status || echo "❌ Cilium not available"
        echo ""
    else
        echo "❌ Kubeconfig not found. Deploy cluster first."
    fi
    
    if [[ -f "/workspaces/proxmox-iac/terraform/output/talos-config.yaml" ]]; then
        export TALOSCONFIG="/workspaces/proxmox-iac/terraform/output/talos-config.yaml"
        echo "🔧 Talos Health:"
        talosctl health || echo "❌ Cannot connect to Talos API"
    else
        echo "❌ Talos config not found. Deploy cluster first."
    fi
}

homelab-logs() {
    if [[ -f "/workspaces/proxmox-iac/terraform/output/talos-config.yaml" ]]; then
        export TALOSCONFIG="/workspaces/proxmox-iac/terraform/output/talos-config.yaml"
        talosctl logs --follow
    else
        echo "❌ Talos config not found. Deploy cluster first."
    fi
}

homelab-config() {
    echo "� Homelab Configuration"
    echo "======================="
    if [[ -f "/workspaces/proxmox-iac/terraform/output/kube-config.yaml" ]]; then
        echo "✅ Kubernetes config: /workspaces/proxmox-iac/terraform/output/kube-config.yaml"
        echo "   Run: export KUBECONFIG=/workspaces/proxmox-iac/terraform/output/kube-config.yaml"
    else
        echo "❌ Kubernetes config not found"
    fi
    
    if [[ -f "/workspaces/proxmox-iac/terraform/output/talos-config.yaml" ]]; then
        echo "✅ Talos config: /workspaces/proxmox-iac/terraform/output/talos-config.yaml"
        echo "   Run: export TALOSCONFIG=/workspaces/proxmox-iac/terraform/output/talos-config.yaml"
    else
        echo "❌ Talos config not found"
    fi
}

# Auto-set configs if they exist
if [[ -f "/workspaces/proxmox-iac/terraform/output/kube-config.yaml" ]]; then
    export KUBECONFIG="/workspaces/proxmox-iac/terraform/output/kube-config.yaml"
fi

if [[ -f "/workspaces/proxmox-iac/terraform/output/talos-config.yaml" ]]; then
    export TALOSCONFIG="/workspaces/proxmox-iac/terraform/output/talos-config.yaml"
fi
EOF

echo ""
echo "🎉 DevContainer setup complete!"
echo ""
echo "🚀 Quick Start:"
echo "=============="
echo "1. Configure: cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
echo "2. Validate:  ./validate-setup.sh"
echo "3. Deploy:    make deploy"
echo "4. Status:    homelab-status"
echo ""
echo "� Available commands:"
echo "====================="
echo "homelab-status    # Complete cluster status"
echo "homelab-logs      # Stream cluster logs"
echo "homelab-config    # Show configuration paths"
echo "make help         # Show all make targets"