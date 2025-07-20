#!/bin/bash
set -euo pipefail

# Enhanced Terraform Deployment Script with SSH Key Management and Drift Detection
# This script handles the complete lifecycle of Proxmox infrastructure deployment

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
SSH_KEY_PATH="$HOME/.ssh/proxmox_ed25519"
SSH_PUB_KEY_PATH="$HOME/.ssh/proxmox_ed25519.pub"

# Default values (can be overridden with environment variables)
PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.1}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-}"
TERRAFORM_AUTO_APPROVE="${TERRAFORM_AUTO_APPROVE:-false}"
ENABLE_DRIFT_DETECTION="${ENABLE_DRIFT_DETECTION:-true}"
DRIFT_CHECK_INTERVAL="${DRIFT_CHECK_INTERVAL:-300}" # 5 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Utility Functions
# =============================================================================

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

# =============================================================================
# SSH Key Management Functions
# =============================================================================

generate_ssh_key() {
    log "Generating new SSH key pair..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    
    # Generate new ED25519 key without passphrase
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "terraform-proxmox-$(date +%Y%m%d)"
    
    # Set proper permissions
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_PUB_KEY_PATH"
    
    success "SSH key pair generated successfully"
    log "Private key: $SSH_KEY_PATH"
    log "Public key: $SSH_PUB_KEY_PATH"
}

test_ssh_connection() {
    log "Testing SSH connection to Proxmox..."
    
    if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no \
        "$PROXMOX_USER@$PROXMOX_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
        success "SSH key authentication successful"
        return 0
    else
        warning "SSH key authentication failed"
        return 1
    fi
}

upload_ssh_key() {
    log "Uploading SSH public key to Proxmox..."
    
    if [ -z "$PROXMOX_PASSWORD" ]; then
        read -s -p "Enter Proxmox root password: " PROXMOX_PASSWORD
        echo
    fi
    
    # Read the public key
    if [ ! -f "$SSH_PUB_KEY_PATH" ]; then
        error "Public key file not found: $SSH_PUB_KEY_PATH"
        return 1
    fi
    
    PUB_KEY_CONTENT=$(cat "$SSH_PUB_KEY_PATH")
    
    # Upload using sshpass and scp
    if command -v sshpass >/dev/null 2>&1; then
        # Create authorized_keys directory structure and add key
        sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no "$PROXMOX_USER@$PROXMOX_HOST" \
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUB_KEY_CONTENT' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys"
        
        success "SSH public key uploaded successfully"
        return 0
    else
        warning "sshpass not found, attempting alternative method..."
        
        # Alternative: use expect if available
        if command -v expect >/dev/null 2>&1; then
            expect << EOF
spawn ssh $PROXMOX_USER@$PROXMOX_HOST "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUB_KEY_CONTENT' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
expect "password:"
send "$PROXMOX_PASSWORD\r"
expect eof
EOF
            success "SSH public key uploaded successfully (via expect)"
            return 0
        else
            error "Neither sshpass nor expect available. Please install sshpass:"
            error "  apt-get update && apt-get install -y sshpass"
            return 1
        fi
    fi
}

setup_ssh_key() {
    log "Setting up SSH key for Proxmox access..."
    
    # Check if SSH key exists and works
    if [ -f "$SSH_KEY_PATH" ] && [ -f "$SSH_PUB_KEY_PATH" ]; then
        if test_ssh_connection; then
            success "Existing SSH key works, continuing..."
            return 0
        else
            warning "Existing SSH key doesn't work, regenerating..."
        fi
    else
        log "No SSH key found, generating new one..."
    fi
    
    # Generate new SSH key
    generate_ssh_key
    
    # Upload public key to Proxmox
    if ! upload_ssh_key; then
        error "Failed to upload SSH key to Proxmox"
        return 1
    fi
    
    # Test the connection again
    if test_ssh_connection; then
        success "SSH key setup completed successfully"
        return 0
    else
        error "SSH key setup failed - connection test failed"
        return 1
    fi
}

# =============================================================================
# Proxmox API Functions
# =============================================================================

create_terraform_user_and_api_key() {
    log "Creating Terraform user and API key on Proxmox..."
    
    # Use the improved authentication script
    if ! "$SCRIPT_DIR/setup-proxmox-auth.sh"; then
        error "Failed to create Terraform user and API key"
        return 1
    fi
    
    success "Terraform user setup completed"
}

# =============================================================================
# Terraform Functions
# =============================================================================

terraform_init() {
    log "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    if ! terraform init; then
        error "Terraform initialization failed"
        return 1
    fi
    success "Terraform initialized"
}

terraform_plan() {
    log "Running Terraform plan..."
    cd "$TERRAFORM_DIR"
    if ! terraform plan -out=tfplan; then
        error "Terraform plan failed"
        return 1
    fi
    success "Terraform plan completed"
}

terraform_apply() {
    log "Applying Terraform configuration..."
    cd "$TERRAFORM_DIR"
    
    if [ "$TERRAFORM_AUTO_APPROVE" = "true" ]; then
        if ! terraform apply -auto-approve tfplan; then
            error "Terraform apply failed"
            return 1
        fi
    else
        if ! terraform apply tfplan; then
            error "Terraform apply failed"
            return 1
        fi
    fi
    
    success "Terraform apply completed"
}

terraform_validate() {
    log "Validating Terraform configuration..."
    cd "$TERRAFORM_DIR"
    if ! terraform validate; then
        error "Terraform validation failed"
        return 1
    fi
    success "Terraform configuration is valid"
}

# =============================================================================
# Drift Detection Functions
# =============================================================================

setup_drift_detection() {
    if [ "$ENABLE_DRIFT_DETECTION" != "true" ]; then
        log "Drift detection disabled, skipping setup"
        return 0
    fi
    
    log "Setting up drift detection..."
    
    # Create drift detection script
    cat > "$PROJECT_ROOT/scripts/drift-detection.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
LOG_FILE="$PROJECT_ROOT/logs/drift-detection.log"

# Create logs directory
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_drift() {
    log "Starting drift detection check..."
    
    cd "$TERRAFORM_DIR"
    
    # Run terraform plan to detect drift
    if terraform plan -detailed-exitcode -out=drift-check.tfplan > /dev/null 2>&1; then
        log "No drift detected - infrastructure matches desired state"
        return 0
    else
        exit_code=$?
        case $exit_code in
            1)
                log "ERROR: Terraform plan failed"
                return 1
                ;;
            2)
                log "DRIFT DETECTED: Infrastructure has drifted from desired state"
                
                # Show the drift
                terraform plan -no-color | tee -a "$LOG_FILE"
                
                # Auto-correct drift if enabled
                if [ "${AUTO_CORRECT_DRIFT:-false}" = "true" ]; then
                    log "Auto-correcting drift..."
                    terraform apply -auto-approve drift-check.tfplan | tee -a "$LOG_FILE"
                    log "Drift correction applied"
                else
                    log "Drift detected but auto-correction disabled. Manual intervention required."
                fi
                return 2
                ;;
        esac
    fi
}

# Run the drift check
check_drift
EOF
    
    chmod +x "$PROJECT_ROOT/scripts/drift-detection.sh"
    
    # Create systemd service for drift detection (if systemd is available)
    if command -v systemctl >/dev/null 2>&1; then
        setup_systemd_drift_detection
    else
        setup_cron_drift_detection
    fi
    
    success "Drift detection setup completed"
}

setup_systemd_drift_detection() {
    log "Setting up systemd drift detection service..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/terraform-drift-detection.service > /dev/null << EOF
[Unit]
Description=Terraform Drift Detection
After=network.target

[Service]
Type=oneshot
User=$(whoami)
WorkingDirectory=$PROJECT_ROOT
ExecStart=$PROJECT_ROOT/scripts/drift-detection.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd timer
    sudo tee /etc/systemd/system/terraform-drift-detection.timer > /dev/null << EOF
[Unit]
Description=Run Terraform Drift Detection every ${DRIFT_CHECK_INTERVAL} seconds
Requires=terraform-drift-detection.service

[Timer]
OnBootSec=${DRIFT_CHECK_INTERVAL}sec
OnUnitActiveSec=${DRIFT_CHECK_INTERVAL}sec
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable and start the timer
    sudo systemctl daemon-reload
    sudo systemctl enable terraform-drift-detection.timer
    sudo systemctl start terraform-drift-detection.timer
    
    success "Systemd drift detection timer enabled"
}

setup_cron_drift_detection() {
    log "Setting up cron-based drift detection..."
    
    # Calculate cron interval
    MINUTES=$((DRIFT_CHECK_INTERVAL / 60))
    if [ $MINUTES -lt 1 ]; then
        MINUTES=1
    fi
    
    # Add cron job
    (crontab -l 2>/dev/null; echo "*/$MINUTES * * * * $PROJECT_ROOT/scripts/drift-detection.sh") | crontab -
    
    success "Cron-based drift detection enabled (every $MINUTES minutes)"
}

# =============================================================================
# Main Deployment Function
# =============================================================================

deploy_infrastructure() {
    log "Starting Proxmox infrastructure deployment..."
    
    # Step 1: SSH Key Setup
    if ! setup_ssh_key; then
        error "SSH key setup failed"
        exit 1
    fi
    
    # Step 2: Create Terraform User and API Key
    if ! create_terraform_user_and_api_key; then
        error "Failed to create Terraform user and API key"
        exit 1
    fi
    
    # Step 3: Terraform Validation
    if ! terraform_validate; then
        error "Terraform validation failed"
        exit 1
    fi
    
    # Step 4: Terraform Init
    if ! terraform_init; then
        error "Terraform initialization failed"
        exit 1
    fi
    
    # Step 5: Terraform Plan
    if ! terraform_plan; then
        error "Terraform planning failed"
        exit 1
    fi
    
    # Step 6: Terraform Apply
    if ! terraform_apply; then
        error "Terraform apply failed"
        exit 1
    fi
    
    # Step 7: Verify VMs were created
    log "Verifying VMs were created in Proxmox..."
    cd "$TERRAFORM_DIR"
    
    # Check if output directory exists and has config files
    if [ ! -d "output" ] || [ ! -f "output/talos-config.yaml" ]; then
        error "Terraform outputs not found - VMs may not have been created"
        log "Checking terraform state..."
        terraform show
        exit 1
    fi
    
    # Verify we can see VMs in Proxmox
    local vm_check=$(curl -k -H "Authorization: PVEAPIToken=$(grep 'proxmox_api_token_id' terraform.tfvars | cut -d'"' -f2)=$(grep 'proxmox_api_token_secret' terraform.tfvars | cut -d'"' -f2)" \
        "https://$PROXMOX_HOST:8006/api2/json/nodes/gateway/qemu" 2>/dev/null | grep -o '"name":"talos-' || echo "")
    
    if [ -z "$vm_check" ]; then
        warning "Could not verify VMs in Proxmox - they may still be deploying"
    else
        success "VMs found in Proxmox"
    fi
    
    # Step 8: Setup Drift Detection
    if ! setup_drift_detection; then
        warning "Drift detection setup failed, but infrastructure deployment was successful"
    fi
    
    success "Infrastructure deployment completed successfully!"
    
    # Show outputs
    log "Displaying Terraform outputs..."
    cd "$TERRAFORM_DIR"
    terraform output
}

# =============================================================================
# Main Script Logic
# =============================================================================

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Enhanced Terraform deployment script with SSH key management and drift detection.

OPTIONS:
    -h, --help              Show this help message
    -a, --auto-approve      Auto-approve Terraform apply
    -d, --disable-drift     Disable drift detection
    -i, --interval SECONDS  Set drift detection interval (default: 300)
    --host HOST             Proxmox host (default: 192.168.1.1)
    --user USER             Proxmox user (default: root)
    --password PASSWORD     Proxmox password (will prompt if not provided)

ENVIRONMENT VARIABLES:
    PROXMOX_HOST            Proxmox server hostname/IP
    PROXMOX_USER            Proxmox username
    PROXMOX_PASSWORD        Proxmox password
    TERRAFORM_AUTO_APPROVE  Auto-approve Terraform (true/false)
    ENABLE_DRIFT_DETECTION  Enable drift detection (true/false)
    DRIFT_CHECK_INTERVAL    Drift check interval in seconds
    AUTO_CORRECT_DRIFT      Auto-correct detected drift (true/false)

EXAMPLES:
    $0                                          # Interactive deployment
    $0 -a --host 192.168.1.100                # Auto-approve with custom host
    $0 --disable-drift                         # Deploy without drift detection
    $0 -i 600                                  # Set drift check to 10 minutes

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -a|--auto-approve)
            TERRAFORM_AUTO_APPROVE="true"
            shift
            ;;
        -d|--disable-drift)
            ENABLE_DRIFT_DETECTION="false"
            shift
            ;;
        -i|--interval)
            DRIFT_CHECK_INTERVAL="$2"
            shift 2
            ;;
        --host)
            PROXMOX_HOST="$2"
            shift 2
            ;;
        --user)
            PROXMOX_USER="$2"
            shift 2
            ;;
        --password)
            PROXMOX_PASSWORD="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Install required dependencies
if ! command -v sshpass >/dev/null 2>&1; then
    log "Installing required dependencies..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y sshpass
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y sshpass
    else
        warning "Could not install sshpass automatically. Please install it manually."
    fi
fi

# Validate inputs
if [ -z "$PROXMOX_HOST" ]; then
    error "Proxmox host not specified"
    exit 1
fi

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"

# Show configuration
log "Configuration:"
log "  Proxmox Host: $PROXMOX_HOST"
log "  Proxmox User: $PROXMOX_USER"
log "  Auto-approve: $TERRAFORM_AUTO_APPROVE"
log "  Drift Detection: $ENABLE_DRIFT_DETECTION"
log "  Drift Interval: ${DRIFT_CHECK_INTERVAL}s"

# Run the deployment
deploy_infrastructure
