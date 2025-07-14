# Talos Homelab Deployment Validation Script (PowerShell)
# Validates that all components are ready for deployment

param(
    [switch]$Detailed
)

# Colors for output
$Colors = @{
    Red    = "Red"
    Green  = "Green"
    Yellow = "Yellow"
    Blue   = "Blue"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        "Info"    { Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor $Colors.Blue }
        "Success" { Write-Host "[$timestamp] [SUCCESS] $Message" -ForegroundColor $Colors.Green }
        "Warning" { Write-Host "[$timestamp] [WARNING] $Message" -ForegroundColor $Colors.Yellow }
        "Error"   { Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor $Colors.Red }
    }
}

Write-Host "🏠 Talos Homelab Deployment Validation" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

# Check prerequisites
Write-Log "Checking required tools..." "Info"
$MissingTools = @()

$RequiredTools = @("terraform", "talosctl", "kubectl", "cilium", "flux", "az")
foreach ($tool in $RequiredTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $MissingTools += $tool
    }
}

if ($MissingTools.Count -gt 0) {
    Write-Log "Missing required tools: $($MissingTools -join ', ')" "Error"
    Write-Log "Please run in DevContainer or install missing tools" "Info"
    exit 1
} else {
    Write-Log "All required tools are available" "Success"
}

# Check Azure authentication
Write-Log "Checking Azure CLI authentication..." "Info"
try {
    $account = az account show --output json | ConvertFrom-Json
    if ($account) {
        Write-Log "Azure CLI authenticated (Tenant: $($account.tenantId))" "Success"
    } else {
        Write-Log "Azure CLI not authenticated. Run 'az login' first." "Error"
        exit 1
    }
} catch {
    Write-Log "Azure CLI not authenticated. Run 'az login' first." "Error"
    exit 1
}

# Check Terraform configuration
Write-Log "Checking Terraform configuration..." "Info"
if (-not (Test-Path "terraform\terraform.tfvars")) {
    Write-Log "terraform.tfvars not found. Copy from terraform.tfvars.example and configure." "Warning"
    Write-Log "Available configuration template:" "Info"
    Get-Content "terraform\terraform.tfvars.example"
    Write-Host ""
} else {
    Write-Log "terraform.tfvars found" "Success"
}

# Validate Terraform files
Write-Log "Validating Terraform configuration..." "Info"
Push-Location "terraform"
try {
    $initResult = terraform init -backend=false 2>&1
    if ($LASTEXITCODE -eq 0) {
        $validateResult = terraform validate 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Terraform configuration is valid" "Success"
        } else {
            Write-Log "Terraform configuration validation failed" "Error"
            Write-Host $validateResult
            exit 1
        }
    } else {
        Write-Log "Terraform initialization failed" "Error"
        Write-Host $initResult
        exit 1
    }
} finally {
    Pop-Location
}

# Check Azure backend resources
Write-Log "Checking Azure backend resources..." "Info"
try {
    $rg = az group show --name homelab-state-rg --output json 2>$null | ConvertFrom-Json
    if ($rg) {
        try {
            $storage = az storage account show --name homelabstatestg --resource-group homelab-state-rg --output json 2>$null | ConvertFrom-Json
            if ($storage) {
                Write-Log "Azure backend resources exist" "Success"
            } else {
                Write-Log "Storage account for Terraform state not found" "Warning"
                Write-Log "Run 'make setup-azure' to create it" "Info"
            }
        } catch {
            Write-Log "Storage account for Terraform state not found" "Warning"
            Write-Log "Run 'make setup-azure' to create it" "Info"
        }
    } else {
        Write-Log "Resource group for Terraform state not found" "Warning"
        Write-Log "Run 'make setup-azure' to create it" "Info"
    }
} catch {
    Write-Log "Resource group for Terraform state not found" "Warning"
    Write-Log "Run 'make setup-azure' to create it" "Info"
}

# Check DevContainer configuration
Write-Log "Checking DevContainer configuration..." "Info"
if (Test-Path ".devcontainer\devcontainer.json") {
    Write-Log "DevContainer configuration found" "Success"
} else {
    Write-Log "DevContainer configuration not found" "Warning"
}

# Summary
Write-Host ""
Write-Log "🎉 Validation completed!" "Success"
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Green
Write-Host "==============" -ForegroundColor Green
Write-Host "1. Ensure terraform.tfvars is configured with your values"
Write-Host "2. Run 'make setup-azure' to prepare Azure backend"
Write-Host "3. Run 'make deploy' for full deployment"
Write-Host "4. Or run 'bash deploy-talos-homelab.sh' for guided deployment"
Write-Host ""
Write-Host "🔧 Available Commands:" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host "make help              # Show all available commands"
Write-Host "make setup-azure       # Setup Azure backend"
Write-Host "make setup-keyvault    # Get Azure Key Vault configuration"
Write-Host "make deploy           # Full deployment pipeline"
Write-Host "make status           # Check cluster health"
Write-Host ""
Write-Host "📖 Documentation:" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "README.md             # Complete setup guide"
Write-Host "terraform\            # Infrastructure definitions"
Write-Host ".devcontainer\        # Development environment"
