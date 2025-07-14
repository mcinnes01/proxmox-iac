#!/bin/bash

# Talos Homelab Deployment Validation Script
# Validates that all components are ready for deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🏠 Talos Homelab Deployment Validation"
echo "======================================"
echo

# Check prerequisites
log_info "Checking required tools..."
MISSING_TOOLS=()

command -v terraform >/dev/null 2>&1 || MISSING_TOOLS+=("terraform")
command -v talosctl >/dev/null 2>&1 || MISSING_TOOLS+=("talosctl")
command -v kubectl >/dev/null 2>&1 || MISSING_TOOLS+=("kubectl")
command -v cilium >/dev/null 2>&1 || MISSING_TOOLS+=("cilium")
command -v flux >/dev/null 2>&1 || MISSING_TOOLS+=("flux")
command -v az >/dev/null 2>&1 || MISSING_TOOLS+=("az")

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    log_error "Missing required tools: ${MISSING_TOOLS[*]}"
    log_info "Please run in DevContainer or install missing tools"
    exit 1
else
    log_success "All required tools are available"
fi

# Check Azure authentication
log_info "Checking Azure CLI authentication..."
if az account show >/dev/null 2>&1; then
    TENANT_ID=$(az account show --query tenantId -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    log_success "Azure CLI authenticated (Tenant: $TENANT_ID)"
else
    log_error "Azure CLI not authenticated. Run 'az login' first."
    exit 1
fi

# Check Terraform configuration
log_info "Checking Terraform configuration..."
if [ ! -f "terraform/terraform.tfvars" ]; then
    log_warning "terraform.tfvars not found. Copy from terraform.tfvars.example and configure."
    log_info "Available configuration template:"
    cat terraform/terraform.tfvars.example
    echo
else
    log_success "terraform.tfvars found"
fi

# Validate Terraform files
log_info "Validating Terraform configuration..."
cd terraform
if terraform init -backend=false >/dev/null 2>&1; then
    if terraform validate >/dev/null 2>&1; then
        log_success "Terraform configuration is valid"
    else
        log_error "Terraform configuration validation failed"
        terraform validate
        exit 1
    fi
else
    log_error "Terraform initialization failed"
    exit 1
fi
cd ..

# Check Azure backend resources
log_info "Checking Azure backend resources..."
if az group show --name homelab-state-rg >/dev/null 2>&1; then
    if az storage account show --name homelabstatestg --resource-group homelab-state-rg >/dev/null 2>&1; then
        log_success "Azure backend resources exist"
    else
        log_warning "Storage account for Terraform state not found"
        log_info "Run 'make setup-azure' to create it"
    fi
else
    log_warning "Resource group for Terraform state not found"
    log_info "Run 'make setup-azure' to create it"
fi

# Check DevContainer configuration
log_info "Checking DevContainer configuration..."
if [ -f ".devcontainer/devcontainer.json" ]; then
    log_success "DevContainer configuration found"
else
    log_warning "DevContainer configuration not found"
fi

# Summary
echo
log_success "🎉 Validation completed!"
echo
echo "📋 Next Steps:"
echo "=============="
echo "1. Ensure terraform.tfvars is configured with your values"
echo "2. Run 'make setup-azure' to prepare Azure backend"
echo "3. Run 'make deploy' for full deployment"
echo "4. Or run './deploy-talos-homelab.sh' for guided deployment"
echo
echo "🔧 Available Commands:"
echo "====================="
echo "make help              # Show all available commands"
echo "make setup-azure       # Setup Azure backend"
echo "make setup-keyvault    # Get Azure Key Vault configuration"
echo "make deploy           # Full deployment pipeline"
echo "make status           # Check cluster health"
echo
echo "📖 Documentation:"
echo "=================="
echo "README.md             # Complete setup guide"
echo "terraform/            # Infrastructure definitions"
echo ".devcontainer/        # Development environment"
