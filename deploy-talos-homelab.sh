#!/bin/bash

# Talos Proxmox Homelab Deployment Script
# This script automates the complete deployment of a Talos Kubernetes cluster on Proxmox

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
OUTPUT_DIR="$TERRAFORM_DIR/output"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running in DevContainer or has required tools
    local missing_tools=()
    
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v talosctl >/dev/null 2>&1 || missing_tools+=("talosctl")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v cilium >/dev/null 2>&1 || missing_tools+=("cilium")
    command -v flux >/dev/null 2>&1 || missing_tools+=("flux")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please run in DevContainer or install missing tools"
        exit 1
    fi
    
    # Check for Azure CLI authentication
    if ! az account show >/dev/null 2>&1; then
        log_error "Azure CLI not authenticated. Run 'az login' first."
        exit 1
    fi
    
    # Check for Terraform variables
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Copy from terraform.tfvars.example and configure."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

setup_azure_backend() {
    log_info "Setting up Azure backend for Terraform state..."
    
    # Check if backend resources exist
    if ! az group show --name homelab-state-rg >/dev/null 2>&1; then
        log_info "Creating Azure resource group for state management..."
        az group create --name homelab-state-rg --location eastus
    fi
    
    if ! az storage account show --name homelabstatestg --resource-group homelab-state-rg >/dev/null 2>&1; then
        log_info "Creating Azure storage account for Terraform state..."
        az storage account create \
            --name homelabstatestg \
            --resource-group homelab-state-rg \
            --location eastus \
            --sku Standard_LRS
    fi
    
    # Create container for state
    az storage container create \
        --name tfstate \
        --account-name homelabstatestg \
        --auth-mode login >/dev/null 2>&1 || true
    
    log_success "Azure backend configured"
}

setup_azure_keyvault() {
    log_info "Setting up Azure Key Vault for secrets management..."
    
    # Get current user details for Key Vault access
    local tenant_id=$(az account show --query tenantId -o tsv)
    local object_id=$(az ad signed-in-user show --query id -o tsv)
    
    # Update terraform.tfvars with Azure details if not already set
    if ! grep -q "tenant_id.*=.*\"$tenant_id\"" "$TERRAFORM_DIR/terraform.tfvars"; then
        log_info "Adding Azure configuration to terraform.tfvars..."
        cat >> "$TERRAFORM_DIR/terraform.tfvars" << EOF

# Azure Key Vault Configuration (auto-configured)
azure = {
  tenant_id = "$tenant_id"
  object_id = "$object_id"
  location  = "East US"
}

enable_keyvault = true
EOF
    fi
    
    log_success "Azure Key Vault configuration prepared"
}

deploy_infrastructure() {
    log_info "Deploying Talos infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log_info "Planning infrastructure deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    log_info "Applying infrastructure deployment..."
    terraform apply tfplan
    
    # Clean up plan file
    rm -f tfplan
    
    log_success "Infrastructure deployed successfully"
}

configure_cluster_access() {
    log_info "Configuring cluster access..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Wait for output files to be generated
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if [ -f "$OUTPUT_DIR/kube-config.yaml" ] && [ -f "$OUTPUT_DIR/talos-config.yaml" ]; then
            break
        fi
        
        log_info "Waiting for cluster configuration files... (attempt $((attempt + 1))/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "Timeout waiting for cluster configuration files"
        exit 1
    fi
    
    # Set up kubectl configuration
    export KUBECONFIG="$OUTPUT_DIR/kube-config.yaml"
    echo "export KUBECONFIG=\"$OUTPUT_DIR/kube-config.yaml\"" >> ~/.bashrc
    
    # Set up talosctl configuration
    export TALOSCONFIG="$OUTPUT_DIR/talos-config.yaml"
    echo "export TALOSCONFIG=\"$OUTPUT_DIR/talos-config.yaml\"" >> ~/.bashrc
    
    log_success "Cluster access configured"
}

wait_for_cluster_ready() {
    log_info "Waiting for cluster to be ready..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get nodes >/dev/null 2>&1; then
            local ready_nodes=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
            local total_nodes=$(kubectl get nodes --no-headers | wc -l)
            
            if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
                log_success "All nodes are ready ($ready_nodes/$total_nodes)"
                break
            else
                log_info "Nodes ready: $ready_nodes/$total_nodes"
            fi
        else
            log_info "Waiting for Kubernetes API... (attempt $((attempt + 1))/$max_attempts)"
        fi
        
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "Timeout waiting for cluster to be ready"
        exit 1
    fi
}

verify_cluster_health() {
    log_info "Verifying cluster health..."
    
    # Check Talos health
    log_info "Checking Talos health..."
    if talosctl health; then
        log_success "Talos health check passed"
    else
        log_warning "Talos health check failed"
    fi
    
    # Check Kubernetes nodes
    log_info "Checking Kubernetes nodes..."
    kubectl get nodes
    
    # Check system pods
    log_info "Checking system pods..."
    kubectl get pods --all-namespaces
    
    # Check Cilium status
    log_info "Checking Cilium status..."
    if cilium status; then
        log_success "Cilium is healthy"
    else
        log_warning "Cilium health check failed"
    fi
    
    log_success "Cluster health verification completed"
}

setup_flux_gitops() {
    log_info "Setting up Flux GitOps (optional)..."
    
    read -p "Do you want to set up Flux GitOps? [y/N]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Flux setup requires GitHub repository configuration"
        log_info "Please refer to the README for GitOps setup instructions"
    else
        log_info "Skipping Flux setup"
    fi
}

print_cluster_info() {
    log_success "🎉 Talos Kubernetes cluster deployment completed!"
    echo
    echo "📋 Cluster Information:"
    echo "======================"
    echo "Cluster Endpoint: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
    echo "Kubeconfig: $OUTPUT_DIR/kube-config.yaml"
    echo "Talos Config: $OUTPUT_DIR/talos-config.yaml"
    echo
    echo "🔧 Available Commands:"
    echo "====================="
    echo "kubectl get nodes              # View cluster nodes"
    echo "talosctl health               # Check Talos health"
    echo "cilium status                 # Check network status"
    echo "homelab-status               # Complete health check"
    echo
    echo "🌐 Access URLs (after configuring LoadBalancer IPs):"
    echo "=================================================="
    echo "Hubble UI: http://<loadbalancer-ip>:80"
    echo "Cilium Status: cilium status"
    echo
    echo "📖 Next Steps:"
    echo "=============="
    echo "1. Configure GitOps with Flux (see README)"
    echo "2. Deploy applications to the cluster"
    echo "3. Set up monitoring and observability"
    echo "4. Configure backup strategies"
    echo
    log_info "Deployment completed successfully! 🚀"
}

# Main deployment flow
main() {
    echo "🏠 Talos Proxmox Homelab Deployment"
    echo "===================================="
    echo
    
    check_prerequisites
    setup_azure_backend
    setup_azure_keyvault
    deploy_infrastructure
    configure_cluster_access
    wait_for_cluster_ready
    verify_cluster_health
    setup_flux_gitops
    print_cluster_info
}

# Handle script interruption
trap 'log_error "Deployment interrupted. Check logs for details."; exit 1' INT TERM

# Run main function
main "$@"
