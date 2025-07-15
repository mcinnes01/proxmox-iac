#!/bin/bash
set -euo pipefail

# Proxmox Terraform User and API Token Setup Script
# This script creates a terraform user in Proxmox and generates an API token
# Stores the token securely using SOPS

# Configuration
PROXMOX_ENDPOINT="${PROXMOX_ENDPOINT:-https://192.168.1.10:8006}"
TERRAFORM_USER="terraform@pve"
TOKEN_ID="terraform"
SOPS_FILE="kubernetes/components/common/sops/cluster-secrets.sops.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed"
        exit 1
    fi
    
    if ! command -v sops &> /dev/null; then
        error "sops is required but not installed"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Get Proxmox credentials
get_credentials() {
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

# Get authentication ticket from Proxmox
get_auth_ticket() {
    log "Getting authentication ticket from Proxmox..."
    
    local response
    response=$(curl -s -k \
        -d "username=root@pam&password=${PROXMOX_ROOT_PASSWORD}" \
        "${PROXMOX_ENDPOINT}/api2/json/access/ticket" \
        -H "Content-Type: application/x-www-form-urlencoded") || {
        error "Failed to connect to Proxmox at ${PROXMOX_ENDPOINT}"
        exit 1
    }
    
    # Check if authentication was successful
    if ! echo "$response" | jq -e '.data.ticket' &> /dev/null; then
        error "Authentication failed. Please check your credentials and Proxmox endpoint."
        echo "Response: $response"
        exit 1
    fi
    
    TICKET=$(echo "$response" | jq -r '.data.ticket')
    CSRF_TOKEN=$(echo "$response" | jq -r '.data.CSRFPreventionToken')
    
    success "Authentication successful"
}

# Check if terraform user exists
check_user_exists() {
    log "Checking if terraform user exists..."
    
    local response
    response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_ENDPOINT}/api2/json/access/users/${TERRAFORM_USER}")
    
    if echo "$response" | jq -e '.data' &> /dev/null; then
        log "Terraform user already exists"
        return 0
    else
        log "Terraform user does not exist"
        return 1
    fi
}

# Create terraform user
create_user() {
    log "Creating terraform user..."
    
    local response
    response=$(curl -s -k \
        -X POST \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "userid=${TERRAFORM_USER}&comment=Terraform automation user" \
        "${PROXMOX_ENDPOINT}/api2/json/access/users")
    
    if echo "$response" | jq -e '.data' &> /dev/null; then
        success "Terraform user created successfully"
    else
        error "Failed to create terraform user"
        echo "Response: $response"
        exit 1
    fi
}

# Set user permissions
set_permissions() {
    log "Setting permissions for terraform user..."
    
    local response
    response=$(curl -s -k \
        -X PUT \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "users=${TERRAFORM_USER}&roleid=PVEAdmin&path=/" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    if echo "$response" | jq -e '.data' &> /dev/null; then
        success "Permissions set successfully"
    else
        warn "Failed to set permissions, may already exist"
    fi
}

# Check if API token exists
check_token_exists() {
    log "Checking if API token exists..."
    
    local response
    response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_ENDPOINT}/api2/json/access/users/${TERRAFORM_USER}/token/${TOKEN_ID}")
    
    if echo "$response" | jq -e '.data' &> /dev/null; then
        log "API token already exists"
        return 0
    else
        log "API token does not exist"
        return 1
    fi
}

# Create API token
create_token() {
    log "Creating API token..."
    
    local response
    response=$(curl -s -k \
        -X POST \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "tokenid=${TOKEN_ID}&comment=Terraform automation token&privsep=0" \
        "${PROXMOX_ENDPOINT}/api2/json/access/users/${TERRAFORM_USER}/token/${TOKEN_ID}")
    
    if echo "$response" | jq -e '.data.value' &> /dev/null; then
        API_TOKEN_VALUE=$(echo "$response" | jq -r '.data.value')
        API_TOKEN_FULL="${TERRAFORM_USER}!${TOKEN_ID}=${API_TOKEN_VALUE}"
        success "API token created successfully"
        return 0
    else
        error "Failed to create API token"
        echo "Response: $response"
        exit 1
    fi
}

# Store token in SOPS
store_token_in_sops() {
    log "Storing API token in SOPS..."
    
    # Create temporary file with the token
    local temp_file
    temp_file=$(mktemp)
    
    # Check if SOPS file exists
    if [[ -f "$SOPS_FILE" ]]; then
        # Decrypt existing file, add token, re-encrypt
        sops -d "$SOPS_FILE" > "$temp_file"
        
        # Use yq to add/update the proxmox token
        if command -v yq &> /dev/null; then
            yq eval ".data.proxmox_api_token = \"${API_TOKEN_FULL}\"" -i "$temp_file"
        else
            # Fallback: simple append if yq not available
            echo "  proxmox_api_token: ${API_TOKEN_FULL}" >> "$temp_file"
        fi
    else
        # Create new SOPS file
        cat > "$temp_file" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-secrets
  namespace: flux-system
type: Opaque
data:
  proxmox_api_token: ${API_TOKEN_FULL}
EOF
    fi
    
    # Encrypt and save
    sops -e "$temp_file" > "$SOPS_FILE"
    rm "$temp_file"
    
    success "API token stored in SOPS file: $SOPS_FILE"
}

# Update terraform.tfvars
update_terraform_vars() {
    log "Updating terraform.tfvars with API token..."
    
    local tfvars_file="terraform/terraform.tfvars"
    
    if [[ -f "$tfvars_file" ]]; then
        # Use sed to replace the placeholder
        sed -i "s|REPLACE_WITH_YOUR_TOKEN_UUID_HERE|${API_TOKEN_VALUE}|g" "$tfvars_file"
        success "terraform.tfvars updated with API token"
    else
        warn "terraform.tfvars not found, skipping update"
    fi
}

# Main execution
main() {
    log "Starting Proxmox Terraform setup..."
    
    check_prerequisites
    get_credentials
    get_auth_ticket
    
    # Create user if it doesn't exist
    if ! check_user_exists; then
        create_user
        set_permissions
    fi
    
    # Create token if it doesn't exist or if we want to regenerate
    if ! check_token_exists; then
        create_token
        store_token_in_sops
        update_terraform_vars
    else
        warn "API token already exists. To regenerate, delete it first in Proxmox UI."
        echo "Or run: curl -k -X DELETE -H \"Cookie: PVEAuthCookie=\${TICKET}\" \"${PROXMOX_ENDPOINT}/api2/json/access/users/${TERRAFORM_USER}/token/${TOKEN_ID}\""
    fi
    
    success "Proxmox Terraform setup completed!"
    success "✅ Using IP address (192.168.1.10) for reliable infrastructure access"
    success "🌐 DNS (proxmox.andisoft.co.uk) available for user convenience"
    success "You can now run 'terraform plan' to test the configuration."
}

# Run main function
main "$@"
