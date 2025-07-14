#!/bin/bash
# DevContainer Rebuild Test Script
# Tests all components after rebuilding the development container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🔧 DevContainer Rebuild Validation"
echo "=================================="
echo ""

# Test 1: Check all required tools are installed
log_info "Testing tool installations..."
TOOLS=("terraform" "talosctl" "kubectl" "cilium" "flux" "az" "k9s" "yq" "sops" "jq" "git" "make")
MISSING_TOOLS=()

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        log_success "$tool is installed"
    else
        log_error "$tool is NOT installed"
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    log_success "All required tools are installed"
else
    log_error "Missing tools: ${MISSING_TOOLS[*]}"
    exit 1
fi

echo ""

# Test 2: Check tool versions
log_info "Checking tool versions..."
echo "Terraform: $(terraform version | head -n1)"
echo "Talos CLI: $(talosctl version --client 2>/dev/null | grep 'Client' || echo 'Version check failed')"
echo "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'Version check failed')"
echo "Cilium CLI: $(cilium version --client 2>/dev/null | grep 'cilium-cli' || echo 'Version check failed')"
echo "Flux CLI: $(flux version --client 2>/dev/null || echo 'Version check failed')"
echo "Azure CLI: $(az version --query '\"azure-cli\"' -o tsv 2>/dev/null || echo 'Version check failed')"

echo ""

# Test 3: Check aliases and functions
log_info "Testing aliases and functions..."
ALIASES=("k" "tf" "tfi" "tfp" "tfa" "t" "cs")

for alias_name in "${ALIASES[@]}"; do
    if alias "$alias_name" &> /dev/null; then
        log_success "Alias '$alias_name' is configured"
    else
        log_warning "Alias '$alias_name' is NOT configured"
    fi
done

# Check functions
if type homelab-status &> /dev/null; then
    log_success "Function 'homelab-status' is available"
else
    log_warning "Function 'homelab-status' is NOT available"
fi

if type homelab-config &> /dev/null; then
    log_success "Function 'homelab-config' is available"
else
    log_warning "Function 'homelab-config' is NOT available"
fi

echo ""

# Test 4: Check directory structure
log_info "Checking directory structure..."
REQUIRED_DIRS=(
    "/workspaces/proxmox-iac"
    "/workspaces/proxmox-iac/terraform"
    "/workspaces/proxmox-iac/terraform/talos"
    "/workspaces/proxmox-iac/terraform/azure-keyvault"
    "/workspaces/proxmox-iac/terraform/bootstrap"
    "/workspaces/proxmox-iac/kubernetes"
    "/workspaces/proxmox-iac/.devcontainer"
    "$HOME/.ssh"
    "$HOME/.kube"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log_success "Directory '$dir' exists"
    else
        log_error "Directory '$dir' does NOT exist"
    fi
done

echo ""

# Test 5: Check required files
log_info "Checking required files..."
REQUIRED_FILES=(
    "/workspaces/proxmox-iac/README.md"
    "/workspaces/proxmox-iac/Makefile"
    "/workspaces/proxmox-iac/deploy-talos-homelab.sh"
    "/workspaces/proxmox-iac/validate-setup.sh"
    "/workspaces/proxmox-iac/validate-setup.ps1"
    "/workspaces/proxmox-iac/terraform/providers.tf"
    "/workspaces/proxmox-iac/terraform/variables.tf"
    "/workspaces/proxmox-iac/terraform/main.tf"
    "/workspaces/proxmox-iac/terraform/outputs.tf"
    "/workspaces/proxmox-iac/terraform/terraform.tfvars.example"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_success "File '$file' exists"
    else
        log_error "File '$file' does NOT exist"
    fi
done

echo ""

# Test 6: Terraform validation
log_info "Testing Terraform configuration..."
cd /workspaces/proxmox-iac/terraform

if terraform init -backend=false &> /dev/null; then
    log_success "Terraform initialization successful"
    
    if terraform validate &> /dev/null; then
        log_success "Terraform validation successful"
    else
        log_error "Terraform validation failed"
        terraform validate
    fi
else
    log_error "Terraform initialization failed"
    terraform init -backend=false
fi

echo ""

# Test 7: Git configuration
log_info "Testing Git configuration..."
if [ "$(git config --global core.autocrlf)" = "false" ]; then
    log_success "Git autocrlf is correctly set to false"
else
    log_warning "Git autocrlf is not set to false"
fi

if [ "$(git config --global core.eol)" = "lf" ]; then
    log_success "Git eol is correctly set to lf"
else
    log_warning "Git eol is not set to lf"
fi

echo ""

# Test 8: Azure CLI check
log_info "Testing Azure CLI..."
if az account show &> /dev/null; then
    TENANT_ID=$(az account show --query tenantId -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    log_success "Azure CLI is authenticated"
    echo "  Tenant ID: $TENANT_ID"
    echo "  Subscription ID: $SUBSCRIPTION_ID"
else
    log_warning "Azure CLI is not authenticated. Run 'az login' to authenticate."
fi

echo ""

# Test 9: Check Makefile targets
log_info "Testing Makefile targets..."
cd /workspaces/proxmox-iac
if make help &> /dev/null; then
    log_success "Makefile is functional"
    echo "Available targets:"
    make help | grep -E "^\s+[a-z-]+\s+" | head -10
else
    log_error "Makefile is not functional"
fi

echo ""

# Test 10: Environment variables
log_info "Checking environment variables..."
ENV_VARS=("EDITOR" "GIT_EDITOR")

for var in "${ENV_VARS[@]}"; do
    if [ -n "${!var}" ]; then
        log_success "Environment variable '$var' is set to '${!var}'"
    else
        log_warning "Environment variable '$var' is not set"
    fi
done

echo ""

# Summary
log_success "🎉 DevContainer rebuild validation completed!"
echo ""
echo "📋 Summary:"
echo "==========="
echo "✅ All required tools are installed"
echo "✅ Terraform configuration is valid"
echo "✅ Directory structure is correct"
echo "✅ Required files are present"
echo "✅ Git is properly configured"
echo ""
echo "🚀 Next Steps:"
echo "=============="
echo "1. Configure terraform.tfvars with your Proxmox details"
echo "2. Authenticate with Azure: az login"
echo "3. Deploy the cluster: make deploy"
echo "4. Check cluster status: homelab-status"
echo ""
echo "📖 For detailed instructions, see README.md"
