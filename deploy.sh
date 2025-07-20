#!/bin/bash
set -euo pipefail

# Talos Proxmox Homelab - Single Command Deployment
# This script orchestrates the complete deployment from clean state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Single command deployment for Talos/Proxmox/Kubernetes homelab.

OPTIONS:
    -h, --help              Show this help message
    -a, --auto-approve      Auto-approve all prompts
    --host HOST             Proxmox host IP (default: 192.168.1.10)
    --github-token TOKEN    GitHub token for Flux bootstrap
    --github-owner OWNER    GitHub owner/org (default: mcinnes01)
    --github-repo REPO      GitHub repository (default: proxmox-iac)

ENVIRONMENT VARIABLES:
    PROXMOX_HOST           Proxmox server IP
    PROXMOX_PASSWORD       Proxmox root password
    GITHUB_TOKEN           GitHub personal access token
    AUTO_APPROVE           Auto-approve all prompts (true/false)

EXAMPLES:
    $0                                          # Interactive deployment
    $0 -a --host 192.168.1.10                 # Auto-approve with custom host
    $0 --github-token ghp_xxx --auto-approve  # Fully automated

EOF
}

# Default values
PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.10}"
GITHUB_OWNER="${GITHUB_OWNER:-mcinnes01}"
GITHUB_REPO="${GITHUB_REPO:-proxmox-iac}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -a|--auto-approve)
            AUTO_APPROVE="true"
            shift
            ;;
        --host)
            PROXMOX_HOST="$2"
            shift 2
            ;;
        --github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --github-owner)
            GITHUB_OWNER="$2"
            shift 2
            ;;
        --github-repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

main() {
    log "Starting Talos Proxmox Homelab Deployment"
    log "=========================================="
    
    # Pre-flight checks
    log "Running pre-flight checks..."
    
    # Check required tools
    for tool in terraform terramate talosctl kubectl flux cilium; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            error "Required tool '$tool' not found. Please run in DevContainer."
            exit 1
        fi
    done
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository. Please run from the project root."
        exit 1
    fi
    
    success "Pre-flight checks passed"
    
    # Step 1: Deploy Infrastructure
    log "Step 1: Deploying Proxmox infrastructure with Terraform..."
    if ! "$PROJECT_ROOT/scripts/deploy-infrastructure.sh" --host "$PROXMOX_HOST" ${AUTO_APPROVE:+--auto-approve}; then
        error "Infrastructure deployment failed"
        exit 1
    fi
    success "Infrastructure deployed successfully"
    
    # Step 2: Wait for cluster to be ready
    log "Step 2: Waiting for Talos cluster to be ready..."
    
    # Check if terraform outputs exist
    if [ ! -f "$PROJECT_ROOT/terraform/output/talos-config.yaml" ] || [ ! -f "$PROJECT_ROOT/terraform/output/kube-config.yaml" ]; then
        error "Terraform output files not found. Infrastructure deployment may have failed."
        log "Expected files:"
        log "  - $PROJECT_ROOT/terraform/output/talos-config.yaml"
        log "  - $PROJECT_ROOT/terraform/output/kube-config.yaml"
        exit 1
    fi
    
    export TALOSCONFIG="$PROJECT_ROOT/terraform/output/talos-config.yaml"
    export KUBECONFIG="$PROJECT_ROOT/terraform/output/kube-config.yaml"
    
    log "Using config files:"
    log "  - TALOSCONFIG: $TALOSCONFIG"
    log "  - KUBECONFIG: $KUBECONFIG"
    
    # Wait for nodes to be ready
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if talosctl health >/dev/null 2>&1; then
            success "Talos cluster is healthy"
            break
        fi
        log "Waiting for cluster... (attempt $attempt/$max_attempts)"
        sleep 30
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "Cluster failed to become ready within timeout"
        exit 1
    fi
    
    # Step 3: Install Cilium
    log "Step 3: Installing Cilium CNI..."
    if ! cilium install --version 1.17.5 --values "$PROJECT_ROOT/kubernetes/cilium/values.yaml"; then
        error "Cilium installation failed"
        exit 1
    fi
    
    # Wait for Cilium to be ready
    log "Waiting for Cilium to be ready..."
    cilium status --wait --wait-duration=5m
    success "Cilium installed and ready"
    
    # Step 4: Bootstrap Flux
    log "Step 4: Bootstrapping Flux GitOps..."
    
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        if [ "$AUTO_APPROVE" != "true" ]; then
            read -s -p "Enter GitHub personal access token: " GITHUB_TOKEN
            echo
        else
            error "GITHUB_TOKEN environment variable required for auto-approve mode"
            exit 1
        fi
    fi
    
    export GITHUB_TOKEN
    
    if ! flux bootstrap github \
        --owner="$GITHUB_OWNER" \
        --repository="$GITHUB_REPO" \
        --branch=main \
        --path=./kubernetes \
        --personal; then
        error "Flux bootstrap failed"
        exit 1
    fi
    success "Flux bootstrapped successfully"
    
    # Step 5: Wait for applications to deploy
    log "Step 5: Waiting for applications to deploy..."
    
    # Wait for cert-manager
    log "Waiting for cert-manager..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s
    
    # Wait for Home Assistant
    log "Waiting for Home Assistant..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=home-assistant -n home-automation --timeout=300s
    
    success "Applications deployed successfully"
    
    # Step 6: Display results
    log "Step 6: Deployment Summary"
    log "========================="
    
    echo ""
    success "Deployment completed successfully!"
    echo ""
    
    log "Cluster Information:"
    kubectl get nodes -o wide
    echo ""
    
    log "Application URLs:"
    echo "• Home Assistant: https://home.andisoft.co.uk"
    echo "• Grafana: https://grafana.home.andisoft.co.uk"
    echo "• Prometheus: https://prometheus.home.andisoft.co.uk"
    echo ""
    
    log "DNS Records to Configure:"
    echo "External DNS (Fast Hosts):"
    echo "• home.andisoft.co.uk -> $(kubectl get service -n home-automation home-assistant-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
    echo ""
    echo "Internal DNS (UDM Pro):"
    echo "• proxmox.home.andisoft.co.uk -> 192.168.1.10"
    echo "• talos-cp-01.home.andisoft.co.uk -> 192.168.1.11"
    echo "• talos-worker-01.home.andisoft.co.uk -> 192.168.1.1"
    echo ""
    
    log "Configuration Files:"
    echo "• Kubernetes: $KUBECONFIG"
    echo "• Talos: $TALOSCONFIG"
    echo ""
    
    success "Your Talos Kubernetes homelab is ready!"
}

# Run main function
main "$@"
