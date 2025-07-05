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
    local required_commands=("terraform" "ssh" "curl" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            if [ "$cmd" = "jq" ]; then
                log_warning "jq is not installed. Installing jq..."
                if command_exists "apt"; then
                    sudo apt update && sudo apt install -y jq
                elif command_exists "yum"; then
                    sudo yum install -y jq
                elif command_exists "brew"; then
                    brew install jq
                else
                    log_error "Cannot install jq automatically. Please install jq manually."
                    exit 1
                fi
            else
                log_error "$cmd is not installed or not in PATH"
                exit 1
            fi
        fi
    done
    
    # Check for Terraform configuration
    if [ ! -f "terraform/versions.tf" ]; then
        log_error "Terraform configuration not found. Make sure you're in the project root."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

setup_configuration() {
    log_step "Setting up configuration files..."
    
    cd terraform
    
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

generate_random_password() {
    # Generate a 20-character random password
    openssl rand -base64 20 | tr -d "=+/" | cut -c1-20
}

create_terraform_user() {
    log_step "Creating dedicated Terraform user..."
    
    # Check if we already have terraform-prov@pve configured with a real password
    if grep -q 'proxmox_password[[:space:]]*=[[:space:]]*"[^"]*"' terraform.tfvars 2>/dev/null && \
       ! grep -q "your-password-here" terraform.tfvars 2>/dev/null; then
        log_info "terraform-prov@pve user already configured with password in terraform.tfvars"
        return 0
    fi
    
    # Get Proxmox API endpoint
    local proxmox_api_url=$(grep -o 'proxmox_api_url[[:space:]]*=[[:space:]]*"[^"]*"' terraform.tfvars | sed 's/.*"\([^"]*\)".*/\1/')
    if [ -z "$proxmox_api_url" ]; then
        log_error "proxmox_api_url not found in terraform.tfvars"
        exit 1
    fi
    
    # Clean up URL - remove trailing slash and /api2/json if present
    proxmox_api_url=$(echo "$proxmox_api_url" | sed 's|/$||' | sed 's|/api2/json$||')
    local api_base="${proxmox_api_url}/api2/json"
    
    # Authentication setup
    local auth_method=""
    local auth_header=""
    local csrf_token=""
    
    echo ""
    log_info "To create the terraform-prov@pve user, we need root access to Proxmox"
    echo "Choose authentication method:"
    echo "1. Root password"
    echo "2. Root API token"
    echo ""
    read -p "Enter choice (1 or 2): " -n 1 -r
    echo ""
    
    if [[ $REPLY == "1" ]]; then
        local root_user="root@pam"
        read -p "Enter root username (default: root@pam): " input_user
        if [ -n "$input_user" ]; then
            root_user="$input_user"
        fi
        
        echo -n "Enter root password: "
        read -s root_password
        echo ""
        
        # Get authentication ticket
        log_info "Authenticating with Proxmox API..."
        local auth_response=$(curl -s -k -X POST "$api_base/access/ticket" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "username=$root_user&password=$root_password")
        
        local ticket=$(echo "$auth_response" | jq -r '.data.ticket // empty')
        csrf_token=$(echo "$auth_response" | jq -r '.data.CSRFPreventionToken // empty')
        
        if [ -z "$ticket" ] || [ "$ticket" = "null" ]; then
            log_error "Failed to authenticate with Proxmox API"
            echo "Response: $auth_response"
            exit 1
        fi
        
        auth_header="Cookie: PVEAuthCookie=$ticket"
        auth_method="password"
        
    elif [[ $REPLY == "2" ]]; then
        local root_user="root@pam"
        read -p "Enter root username (default: root@pam): " input_user
        if [ -n "$input_user" ]; then
            root_user="$input_user"
        fi
        
        echo -n "Enter root API token ID: "
        read root_token_id
        echo -n "Enter root API token secret: "
        read -s root_token_secret
        echo ""
        
        auth_header="Authorization: PVEAPIToken=$root_user!$root_token_id=$root_token_secret"
        auth_method="token"
        
    else
        log_error "Invalid choice"
        exit 1
    fi
    
    # Generate random password for terraform user
    local terraform_password=$(generate_random_password)
    
    log_info "Creating terraform-prov@pve user..."
    
    # Create user via API
    local create_user_response=$(curl -s -k -X POST "$api_base/access/users" \
        -H "$auth_header" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        $([ -n "$csrf_token" ] && echo "-H \"CSRFPreventionToken: $csrf_token\"") \
        -d "userid=terraform-prov@pve&password=$terraform_password&enable=1&comment=Terraform provisioning user")
    
    # Check response
    if echo "$create_user_response" | jq -e '.data' >/dev/null 2>&1; then
        log_success "User terraform-prov@pve created successfully"
    elif echo "$create_user_response" | grep -q "already exists"; then
        log_info "User terraform-prov@pve already exists, updating password..."
        
        # Update password for existing user
        local update_response=$(curl -s -k -X PUT "$api_base/access/users/terraform-prov@pve" \
            -H "$auth_header" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            $([ -n "$csrf_token" ] && echo "-H \"CSRFPreventionToken: $csrf_token\"") \
            -d "password=$terraform_password")
        
        if echo "$update_response" | jq -e '.data' >/dev/null 2>&1; then
            log_success "Password updated for terraform-prov@pve"
        else
            log_warning "Password update may have failed, but continuing..."
        fi
    else
        log_error "Failed to create user terraform-prov@pve"
        echo "Response: $create_user_response"
        exit 1
    fi
    
    # Assign PVEVMAdmin role
    log_info "Assigning PVEVMAdmin role to terraform-prov@pve..."
    local assign_role_response=$(curl -s -k -X PUT "$api_base/access/acl" \
        -H "$auth_header" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        $([ -n "$csrf_token" ] && echo "-H \"CSRFPreventionToken: $csrf_token\"") \
        -d "path=/&users=terraform-prov@pve&roles=PVEVMAdmin")
    
    if echo "$assign_role_response" | jq -e '.data' >/dev/null 2>&1; then
        log_success "PVEVMAdmin role assigned to terraform-prov@pve"
    else
        log_warning "Role assignment may have failed, but continuing..."
        echo "Response: $assign_role_response"
    fi
    
    # Update terraform.tfvars with new credentials
    log_info "Updating terraform.tfvars with new user credentials..."
    
    # Update the username and password in terraform.tfvars
    sed -i "s/proxmox_username = \".*\"/proxmox_username = \"terraform-prov@pve\"/" terraform.tfvars
    sed -i "s/proxmox_password = \".*\"/proxmox_password = \"$terraform_password\"/" terraform.tfvars
    sed -i "s/proxmox_api_token_id = \".*\"/proxmox_api_token_id = \"\"/" terraform.tfvars
    sed -i "s/proxmox_api_token_secret = \".*\"/proxmox_api_token_secret = \"\"/" terraform.tfvars
    
    log_success "Terraform user created and configured successfully"
    echo ""
    log_info "User Details:"
    echo "  Username: terraform-prov@pve"
    echo "  Password: [saved in terraform.tfvars]"
    echo "  Role: PVEVMAdmin"
    echo ""
    
    # Security reminder
    log_warning "Security Reminder:"
    echo "  • terraform.tfvars contains sensitive data and is git-ignored"
    echo "  • Consider using API tokens for production deployments"
    echo "  • The terraform-prov@pve user has PVEVMAdmin role (VM management only)"
    echo ""
}

check_authentication() {
    log_step "Checking Proxmox configuration..."
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        log_error "terraform.tfvars not found"
        echo "Please copy terraform.tfvars.example to terraform.tfvars and customize it:"
        echo "  cp terraform.tfvars.example terraform.tfvars"
        echo "  nano terraform.tfvars"
        exit 1
    fi
    
    # Check if we need to create the terraform user based on password placeholder
    if grep -q "your-token-secret-here\|your-password-here" terraform.tfvars; then
        log_info "No authentication configured, creating dedicated Terraform user..."
        create_terraform_user
    elif ! grep -q 'proxmox_password[[:space:]]*=[[:space:]]*"[^"]*"' terraform.tfvars || \
         [ -z "$(grep -o 'proxmox_password[[:space:]]*=[[:space:]]*"[^"]*"' terraform.tfvars | sed 's/.*"\([^"]*\)".*/\1/')" ]; then
        log_warning "Authentication may not be properly configured"
        echo ""
        read -p "Create terraform-prov@pve user for secure deployment? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Continuing with existing configuration..."
        else
            create_terraform_user
        fi
    else
        log_info "Using terraform-prov@pve user from terraform.tfvars"
    fi
    
    # Check authentication options from environment variables
    if [ -n "$PM_API_TOKEN_ID" ] && [ -n "$PM_API_TOKEN_SECRET" ]; then
        log_info "Using environment variables for Proxmox API token authentication"
        export TF_VAR_proxmox_username="$PM_USER"
        export TF_VAR_proxmox_api_token_id="$PM_API_TOKEN_ID"
        export TF_VAR_proxmox_api_token_secret="$PM_API_TOKEN_SECRET"
        export TF_VAR_proxmox_password=""
    elif [ -n "$PM_PASS" ] && [ -n "$PM_USER" ]; then
        log_info "Using environment variables for Proxmox password authentication"
        export TF_VAR_proxmox_username="$PM_USER"
        export TF_VAR_proxmox_password="$PM_PASS"
        export TF_VAR_proxmox_api_token_id=""
        export TF_VAR_proxmox_api_token_secret=""
    else
        log_info "Using terraform.tfvars for Proxmox authentication"
    fi
    
    # Check if SSH keys exist
    SSH_PRIVATE_KEY=$(grep -o 'ssh_private_key_file[[:space:]]*=[[:space:]]*"[^"]*"' terraform.tfvars | sed 's/.*"\([^"]*\)".*/\1/')
    SSH_PUBLIC_KEY=$(grep -o 'ssh_public_key_file[[:space:]]*=[[:space:]]*"[^"]*"' terraform.tfvars | sed 's/.*"\([^"]*\)".*/\1/')
    
    # Expand tilde to home directory
    SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY/#\~/$HOME}"
    SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY/#\~/$HOME}"
    
    if [ ! -f "$SSH_PRIVATE_KEY" ] || [ ! -f "$SSH_PUBLIC_KEY" ]; then
        log_warning "SSH keys not found:"
        echo "  Private key: $SSH_PRIVATE_KEY"
        echo "  Public key: $SSH_PUBLIC_KEY"
        echo ""
        echo "Generate SSH keys with:"
        echo "  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"
        exit 1
    fi
    
    log_success "Configuration validated"
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
        log_success "Kubeconfig saved to: terraform/kubeconfig.yaml"
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
    
    cd terraform
    
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
    echo "  deploy      - Deploy the K3s cluster (default)"
    echo "  create-user - Create terraform-prov@pve user only"
    echo "  destroy     - Destroy the K3s cluster"
    echo "  validate    - Validate configuration only"
    echo "  kubeconfig  - Get kubeconfig for existing cluster"
    echo "  info        - Show cluster information"
    echo "  ssh <ip>    - SSH to a cluster node"
    echo "  help        - Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Terraform >= 1.0"
    echo "  - Proxmox VE with template"
    echo "  - Authentication: API token or password"
    echo "  - SSH key pair for cluster access"
    echo ""
    echo "Setup:"
    echo "  1. Edit terraform/terraform.tfvars with your settings"
    echo "  2. Set authentication (choose one):"
    echo "     API Token: export PM_USER=root@pam PM_API_TOKEN_ID=terraform PM_API_TOKEN_SECRET=..."
    echo "     Password:  export PM_USER=root@pam PM_PASS=..."
    echo "  3. Run: $0 deploy"
    echo ""
    echo "Automated User Creation:"
    echo "  - The script will automatically create a 'terraform-prov@pve' user"
    echo "  - Uses root credentials for initial setup, then switches to dedicated user"
    echo "  - Assigns PVEVMAdmin role (VM management only, not full admin)"
    echo "  - Updates terraform.tfvars with new user credentials"
    echo ""
    echo "Network Configuration:"
    echo "  - Proxmox server: 192.168.1.1"
    echo "  - K3s nodes: 192.168.1.2 - 192.168.1.50"
    echo "  - Subnet: 192.168.1.0/24"
    echo ""
}

# Main execution
main() {
    local command="${1:-deploy}"
    
    case "$command" in
        "create-user")
            check_prerequisites
            setup_configuration
            create_terraform_user
            ;;
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
            cd terraform
            get_kubeconfig
            ;;
        "info")
            check_prerequisites
            cd terraform
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