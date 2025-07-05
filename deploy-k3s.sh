#!/bin/bash
set -e

# Proxmox K3s Deployment Script
# Following the HeekoOfficial/terraform-proxmox-k3s pattern
# Pure Terraform with no external dependencies

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${PURPLE}🔧 $1${NC}"; }

# Helper functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check for required commands
    local required_commands=("terraform" "ssh")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "$cmd is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check for Terraform configuration
    if [ ! -f "terraform/proxmox-k3s/versions.tf" ]; then
        log_error "Terraform configuration not found. Make sure you're in the project root."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

setup_configuration() {
    log_step "Setting up configuration files..."
    
    cd terraform/proxmox-k3s
    
    # Copy provider configuration if it doesn't exist
    if [ ! -f "main.tf" ]; then
        if [ -f "provider.tf.example" ]; then
            cp provider.tf.example main.tf
            log_warning "Created main.tf from template. Please edit it with your Proxmox API URL."
        else
            log_error "provider.tf.example not found"
            exit 1
        fi
    fi
    
    # Copy variables configuration if it doesn't exist
    if [ ! -f "terraform.tfvars" ]; then
        if [ -f "terraform.tfvars.example" ]; then
            cp terraform.tfvars.example terraform.tfvars
            log_warning "Created terraform.tfvars from template. Please edit it with your environment settings."
        else
            log_error "terraform.tfvars.example not found"
            exit 1
        fi
    fi
    
    log_success "Configuration files ready"
}

check_authentication() {
    log_step "Checking Proxmox authentication..."
    
    if [ -z "$PM_USER" ] || [ -z "$PM_PASS" ]; then
        log_warning "Proxmox authentication not configured"
        echo ""
        echo "Please set environment variables for Proxmox authentication:"
        echo "export PM_USER=\"terraform-prov@pve\""
        echo "export PM_PASS=\"your-password\""
        echo ""
        echo "Or run: source .env  # if you have a .env file"
        exit 1
    fi
    
    log_success "Proxmox authentication configured"
}

validate_configuration() {
    log_step "Validating Terraform configuration..."
    
    terraform fmt
    terraform validate
    
    log_success "Configuration validation passed"
}

deploy_cluster() {
    log_step "Deploying K3s cluster..."
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    log_info "Creating deployment plan..."
    terraform plan -out=tfplan
    
    # Confirm deployment
    echo ""
    log_warning "Review the deployment plan above."
    read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Apply deployment
        terraform apply tfplan
        rm tfplan
        
        log_success "Cluster deployment completed!"
        
        # Get kubeconfig
        get_kubeconfig
    else
        log_info "Deployment cancelled"
        rm tfplan
        exit 0
    fi
}

get_kubeconfig() {
    log_step "Retrieving kubeconfig..."
    
    # Extract kubeconfig
    terraform output -raw k3s_kubeconfig > kubeconfig.yaml
    
    if [ -f "kubeconfig.yaml" ]; then
        log_success "Kubeconfig saved to: terraform/proxmox-k3s/kubeconfig.yaml"
        echo ""
        log_info "To use the cluster:"
        echo "export KUBECONFIG=\"$(pwd)/kubeconfig.yaml\""
        echo "kubectl get nodes"
        echo ""
        
        # Show cluster info
        show_cluster_info
    else
        log_error "Failed to retrieve kubeconfig"
        exit 1
    fi
}

show_cluster_info() {
    log_step "Cluster Information:"
    
    # Get outputs
    local support_ip=$(terraform output -raw support_node_ip 2>/dev/null || echo "N/A")
    local master_ips=$(terraform output -json master_node_ips 2>/dev/null | jq -r '.[]' | tr '\n' ' ' || echo "N/A")
    
    echo ""
    echo "🏠 Cluster Details:"
    echo "   Support Node IP: $support_ip"
    echo "   Master Node IPs: $master_ips"
    echo ""
    echo "🔐 Access:"
    echo "   Kubeconfig: $(pwd)/kubeconfig.yaml"
    echo "   SSH: ssh k3s@<node-ip>"
    echo ""
    echo "📊 Health Check:"
    echo "   export KUBECONFIG=\"$(pwd)/kubeconfig.yaml\""
    echo "   kubectl get nodes"
    echo "   kubectl get pods -A"
    echo ""
}

destroy_cluster() {
    log_step "Destroying K3s cluster..."
    
    cd terraform/proxmox-k3s
    
    log_warning "This will destroy ALL cluster resources!"
    read -p "Are you sure? Type 'yes' to confirm: " -r
    echo ""
    
    if [ "$REPLY" = "yes" ]; then
        terraform destroy
        log_success "Cluster destroyed"
    else
        log_info "Destroy cancelled"
    fi
}

ssh_to_node() {
    local node_ip="$1"
    if [ -z "$node_ip" ]; then
        log_error "Usage: $0 ssh <node-ip>"
        exit 1
    fi
    
    log_info "Connecting to $node_ip..."
    ssh k3s@"$node_ip"
}

show_help() {
    echo ""
    echo "Proxmox K3s Deployment Script"
    echo "============================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy    - Deploy the K3s cluster (default)"
    echo "  destroy   - Destroy the K3s cluster"
    echo "  validate  - Validate configuration only"
    echo "  kubeconfig - Get kubeconfig for existing cluster"
    echo "  info      - Show cluster information"
    echo "  ssh <ip>  - SSH to a cluster node"
    echo "  help      - Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Terraform >= 1.0"
    echo "  - Proxmox VE with template"
    echo "  - Environment variables: PM_USER, PM_PASS"
    echo ""
    echo "Setup:"
    echo "  1. Edit terraform/proxmox-k3s/main.tf with your Proxmox API URL"
    echo "  2. Edit terraform/proxmox-k3s/terraform.tfvars with your settings"
    echo "  3. Set authentication: export PM_USER=... PM_PASS=..."
    echo "  4. Run: $0 deploy"
    echo ""
}

# Main execution
main() {
    local command="${1:-deploy}"
    
    case "$command" in
        "deploy")
            check_prerequisites
            setup_configuration
            check_authentication
            validate_configuration
            deploy_cluster
            ;;
        "destroy")
            check_prerequisites
            destroy_cluster
            ;;
        "validate")
            check_prerequisites
            setup_configuration
            validate_configuration
            log_success "Configuration is valid"
            ;;
        "kubeconfig")
            check_prerequisites
            cd terraform/proxmox-k3s
            get_kubeconfig
            ;;
        "info")
            check_prerequisites
            cd terraform/proxmox-k3s
            show_cluster_info
            ;;
        "ssh")
            ssh_to_node "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Banner
echo ""
echo "🚀 Proxmox K3s Cluster Deployment"
echo "   Following HeekoOfficial/terraform-proxmox-k3s pattern"
echo ""

# Execute main function with all arguments
main "$@"
