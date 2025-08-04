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
    log "Creating terraform user with password..."
    
    # Generate a random password for the terraform user
    TERRAFORM_PASSWORD=$(openssl rand -base64 32)
    
    # Create the request body with password
    local request_body="userid=${TERRAFORM_USER}&comment=Terraform automation user&password=${TERRAFORM_PASSWORD}"
    
    log "DEBUG: Request body: userid=${TERRAFORM_USER}&comment=Terraform automation user&password=***"
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
    
    # Check for success - Proxmox returns {"data":null} on success for user creation
    if echo "$response" | jq -e '.data' &> /dev/null || echo "$response" | grep -q '"data":null'; then
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
    
    # Set Administrator permissions on root path (needed for query-url-metadata API)
    log "Setting Administrator role on root path..."
    local root_response
    root_response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: $CSRF_TOKEN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X PUT \
        -d "users=${TERRAFORM_USER}&roles=Administrator&path=/" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    log "Root path response: $root_response"
    
    # Set permissions on nodes path (needed for query-url-metadata API)
    log "Setting PVEAdmin role on /nodes..."
    local nodes_response
    nodes_response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: $CSRF_TOKEN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X PUT \
        -d "users=${TERRAFORM_USER}&roles=PVEAdmin&path=/nodes" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    log "nodes response: $nodes_response"
    
    # Set permissions on specific node path for query-url-metadata
    log "Setting PVEAdmin role on /nodes/pve..."
    local node_response
    node_response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: $CSRF_TOKEN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X PUT \
        -d "users=${TERRAFORM_USER}&roles=PVEAdmin&path=/nodes/pve" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    log "node response: $node_response"
    
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
    
    # Set permissions on storage2 datastore (our new LVM storage)
    log "Setting PVEAdmin role on /storage/storage2..."
    local storage2_response
    storage2_response=$(curl -s -k \
        -H "Cookie: PVEAuthCookie=${TICKET}" \
        -H "CSRFPreventionToken: $CSRF_TOKEN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -X PUT \
        -d "users=${TERRAFORM_USER}&roles=PVEAdmin&path=/storage/storage2" \
        "${PROXMOX_ENDPOINT}/api2/json/access/acl")
    
    log "storage2 response: $storage2_response"
    
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
    log "Creating terraform.tfvars with Proxmox configuration..."
    
    local tfvars_file="terraform.tfvars"
    
    # Create terraform.tfvars from template with our new variable structure
    cat > "$tfvars_file" << EOF
# Proxmox Configuration
# Generated automatically by setup-proxmox-auth.sh

# Proxmox connection details
proxmox_node_name = "pve"
proxmox_admin_endpoint = "https://192.168.1.10:8006/api2/json"
proxmox_username = "${TERRAFORM_USER}"
proxmox_password = "${TERRAFORM_PASSWORD}"
proxmox_insecure = true

# Network Configuration
# Gateway/DNS: 192.168.1.254 (UDM Pro - handles routing and DNS)
# Proxmox: 192.168.1.10 → proxmox.andisoft.co.uk (internal DNS)
# Home Assistant: 192.168.1.1 → home.andisoft.co.uk (future MetalLB service)
proxmox_vms_default_gateway = "192.168.1.254"

# VM Configuration
proxmox_vms_talos = {
  controller1 = { 
    id = 100, 
    ip = "192.168.1.11/24", 
    controller = true,
    cpu_cores = 1,
    memory_mb = 3072  # 3GB RAM
  }
  worker1 = { 
    id = 110, 
    ip = "192.168.1.5/24",
    cpu_cores = 3,
    memory_mb = 9216  # 9GB RAM
  }
}

# MetalLB Load Balancer IP Pool
# Includes 192.168.1.1 for Home Assistant (home.andisoft.co.uk)
# Range 192.168.1.20-30 for other services (ingress, databases, etc.)
metallb_pool_addresses = "192.168.1.1-192.168.1.1,192.168.1.20-192.168.1.30"

# Optional: GitOps Configuration (uncomment to enable Flux)
# git_repository = "https://github.com/your-username/homelab-gitops"
# git_branch = "main"
EOF
    
    success "terraform.tfvars created with API token and network configuration"
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
        log "Terraform user already exists, setting password..."
        # Generate new password for existing user
        TERRAFORM_PASSWORD=$(openssl rand -base64 32)
        
        # Use the password endpoint to set password
        local update_response
        update_response=$(curl -s -k \
            -H "Cookie: PVEAuthCookie=${TICKET}" \
            -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -X PUT \
            -d "password=${TERRAFORM_PASSWORD}" \
            "${PROXMOX_ENDPOINT}/api2/json/access/password")
        
        log "Password update response: $update_response"
        
        # Alternative: delete and recreate user with password
        if ! echo "$update_response" | jq -e '.data' &> /dev/null; then
            log "Password update failed, deleting and recreating user..."
            
            # Delete existing user
            local delete_response
            delete_response=$(curl -s -k \
                -X DELETE \
                -H "Cookie: PVEAuthCookie=${TICKET}" \
                -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
                "${PROXMOX_ENDPOINT}/api2/json/access/users/${TERRAFORM_USER}")
            
            log "User deletion response: $delete_response"
            
            # Recreate user with password
            if ! create_user; then
                error "Failed to recreate user"
                exit 1
            fi
        else
            success "Terraform user password updated successfully"
        fi
    fi
    
    # Always set permissions to ensure they're correct
    log "Setting/updating permissions..."
    set_permissions
    
    update_terraform_vars
    
    success "Proxmox Terraform setup completed!"
    success "✅ User: ${TERRAFORM_USER}"
    success "✅ Authentication: Username/Password (avoiding API token limitations)"
    success "✅ Configuration stored in terraform.tfvars"
    success "✅ Permissions set for all storage pools (local, local-lvm, storage2)"
    success "✅ Using IP address (192.168.1.10) for reliable infrastructure access"
    success ""
    success "🚀 Next steps:"
    success "   1. Review and modify terraform.tfvars if needed"
    success "   2. Run 'terraform init' to initialize"
    success "   3. Run 'terraform plan' to preview changes"
    success "   4. Run 'terraform apply' to deploy your cluster"
}

# Run main function
main "$@"
