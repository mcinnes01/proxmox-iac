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
