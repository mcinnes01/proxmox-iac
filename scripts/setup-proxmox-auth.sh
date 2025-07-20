#!/bin/bash
set -euo pipefail

# Proxmox Terraform User and API Token Setup Script
# This script creates a terraform user in Proxmox and generates an API token
# Stores the token securely using SOPS

# Configuration
PROXMOX_ENDPOINT="${PROXMOX_ENDPOINT:-https://192.168.1.10:8006}"
TERRAFORM_USER="terraform-prov@pve"
TOKEN_ID="terraform"

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
    
    # Create the request body
    local request_body="userid=${TERRAFORM_USER}&comment=Terraform automation user"
    
    log "DEBUG: Request body: ${request_body}"
    log "DEBUG: URL: ${PROXMOX_ENDPOINT}/api2/json/access/users"
    
    local response
    response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X POST \
        -d "$request_body" \
        "${PROXMOX_ENDPOINT}/api2/json/access/users")
    
    log "DEBUG: Full response: $response"
    
    if echo "$response" | jq -e '.data' &> /dev/null; then
        success "Terraform user created successfully"
        return 0
    elif echo "$response" | grep -q "already exists"; then
        success "Terraform user already exists"
        return 0
    else
        error "Failed to create terraform user"
        echo "Response: $response"
        return 1
    fi
}

# Set user permissions
set_permissions() {
    log "Setting permissions for terraform user..."
    
    # Set PVEAdmin permissions on root path
    log "Setting PVEAdmin role on root path..."
    local root_response
    root_response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: $CSRF_TOKEN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X PUT \
        -d "users=${TERRAFORM_USER}&roles=PVEAdmin&path=/" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    log "Root path response: $root_response"
    
    # Set permissions on local-lvm datastore
    log "Setting PVEAdmin role on /storage/local-lvm..."
    local lvm_response
    lvm_response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: $CSRF_TOKEN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X PUT \
        -d "users=${TERRAFORM_USER}&roles=PVEAdmin&path=/storage/local-lvm" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    log "local-lvm response: $lvm_response"
    
    # Set permissions on local datastore
    log "Setting PVEAdmin role on /storage/local..."
    local local_response
    local_response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: $CSRF_TOKEN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X PUT \
        -d "users=${TERRAFORM_USER}&roles=PVEAdmin&path=/storage/local" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    log "local response: $local_response"
    
    success "Permissions set for terraform user on all required paths"
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

# Delete existing API token
delete_token() {
    log "Deleting existing API token..."
    
    local response
    response=$(curl -s -k \
        -X DELETE \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
        "${PROXMOX_ENDPOINT}/api2/json/access/users/${TERRAFORM_USER}/token/${TOKEN_ID}")
    
    success "Existing API token deleted"
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

# Store token as environment variable for DevContainer

# Update terraform.tfvars
update_terraform_vars() {
    log "Creating terraform.tfvars with API token..."
    
    local tfvars_file="terraform/terraform.tfvars"
    
    # Create terraform.tfvars from template
    cat > "$tfvars_file" << EOF
# Proxmox Configuration
# Generated automatically by setup-proxmox-auth.sh

proxmox_api_url = "https://192.168.1.10:8006/api2/json"
proxmox_username = ""
proxmox_password = ""
proxmox_api_token_id = "${TERRAFORM_USER}!${TOKEN_ID}"
proxmox_api_token_secret = "${API_TOKEN_VALUE}"
proxmox_insecure = true

# Network Configuration
network_gateway = "192.168.1.254"
nameserver = "192.168.1.254"

# Proxmox Node Settings
proxmox_node = "gateway"
vm_datastore = "local-lvm"

# Enable Talos cluster
enable_talos_cluster = true
EOF
    
    success "terraform.tfvars created with API token"
}

# Store token as environment variable for DevContainer
store_token_as_env() {
    log "Storing API token as environment variable..."
    
    # Create or update .env file for the project
    local env_file=".env"
    
    if [[ -f "$env_file" ]]; then
        # Remove existing PROXMOX_API_TOKEN line
        sed -i '/^PROXMOX_API_TOKEN=/d' "$env_file"
    fi
    
    # Append new token
    echo "PROXMOX_API_TOKEN=${API_TOKEN_FULL}" >> "$env_file"
    
    success "API token stored in .env file"
    log "Add .env to your .gitignore to keep the token secure"
}

# Main execution
main() {
    log "Starting Proxmox Terraform setup..."
    
    check_prerequisites
    get_credentials
    get_auth_ticket
    
    # Create user if it doesn't exist
    if ! check_user_exists; then
        log "User doesn't exist, creating..."
        if ! create_user; then
            error "Failed to create user"
            exit 1
        fi
    else
        log "Terraform user already exists"
    fi
    
    # Always set permissions to ensure they're correct
    log "Setting/updating permissions..."
    set_permissions
    
    # Always regenerate API token to ensure we have a fresh one
    if check_token_exists; then
        log "API token exists, regenerating for fresh credentials..."
        delete_token
    fi
    
    create_token
    update_terraform_vars
    store_token_as_env
    
    success "Proxmox Terraform setup completed!"
    success "✅ User: ${TERRAFORM_USER}"
    success "✅ Token ID: ${TOKEN_ID}"
    success "✅ Token stored in terraform.tfvars and .env"
    success "✅ Using IP address (192.168.1.10) for reliable infrastructure access"
    success "🌐 DNS (proxmox.andisoft.co.uk) available for user convenience"
    success "You can now run 'terraform plan' to test the configuration."
}

# Run main function
main "$@"
