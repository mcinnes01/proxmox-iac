#!/bin/bash
set -e

echo "🏠 Setting up Talos Proxmox Homelab DevContainer..."
echo "=================================================="

# Create required directories
mkdir -p ~/.ssh ~/.kube /workspaces/proxmox-iac/terraform/output
chmod 700 ~/.ssh

# Create useful aliases and functions
echo "🔧 Setting up aliases and functions..."
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
        
        echo "🔧 System Pods:"
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

homelab-config() {
    echo "📋 Homelab Configuration"
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
echo "2. Deploy:    make deploy"
echo "3. Status:    homelab-status"
echo ""
echo "📋 Available commands:"
echo "====================="
echo "homelab-status    # Complete cluster status"
echo "homelab-config    # Show configuration paths"
echo "make help         # Show all make targets"
