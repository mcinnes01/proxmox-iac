#!/bin/bash
set -euo pipefail

# Simple script to set root@pam authentication in terraform.tfvars
# This matches exactly how the original repository does authentication

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get Proxmox root password
get_root_password() {
    if [[ -z "${PROXMOX_ROOT_PASSWORD:-}" ]]; then
        echo -n "Enter Proxmox root password: "
        read -s PROXMOX_ROOT_PASSWORD
        echo
    fi
    
    if [[ -z "$PROXMOX_ROOT_PASSWORD" ]]; then
        error "Proxmox root password is required"
        exit 1
    fi
}

# Update terraform.tfvars with root authentication
update_terraform_vars() {
    log "Updating terraform.tfvars with root@pam authentication..."
    
    # Replace placeholder password with actual password
    sed -i "s/PLACEHOLDER_PASSWORD/${PROXMOX_ROOT_PASSWORD}/g" terraform.tfvars
    
    success "terraform.tfvars updated with root@pam authentication"
}

main() {
    log "Setting up root@pam authentication for Proxmox (matching original repository approach)..."
    
    get_root_password
    update_terraform_vars
    
    success "✅ Authentication configured using root@pam (same as original repository)"
    success "✅ This should resolve the query-url-metadata API authentication issue"
    success ""
    success "🚀 Ready to deploy:"
    success "   terraform plan"
    success "   terraform apply"
}

# Run main function
main "$@"
