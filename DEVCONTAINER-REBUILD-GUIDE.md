# 🔄 DevContainer Rebuild Guide

## Pre-Rebuild Checklist

Before rebuilding your DevContainer, ensure you have completed these steps:

### ✅ Prerequisites
- [ ] All changes are committed to Git
- [ ] Azure CLI credentials are available (will be mounted automatically)
- [ ] No active Terraform state locks
- [ ] Docker is running and has sufficient resources

### 🧹 Clean State
- [ ] Remove any temporary files: `rm -rf terraform/.terraform* terraform/output/*`
- [ ] Ensure no background processes are running
- [ ] Close any active terminal sessions in the container

## Rebuild Process

### Method 1: VS Code Command Palette
1. **Open Command Palette**: `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. **Search and run**: `Dev Containers: Rebuild Container`
3. **Select**: `Rebuild` (this will rebuild from scratch)

### Method 2: Manual Docker Cleanup (if needed)
```bash
# Stop and remove the container
docker stop vsc-proxmox-iac-*
docker rm vsc-proxmox-iac-*

# Remove the image (optional, forces complete rebuild)
docker rmi vsc-proxmox-iac-*

# Then rebuild using VS Code
```

## Post-Rebuild Validation

### 1. Automatic Validation
Run the comprehensive test script:
```bash
# Make executable (if needed)
chmod +x test-devcontainer.sh

# Run validation
./test-devcontainer.sh
```

### 2. Manual Checks

#### Tool Versions
```bash
# Core tools
terraform version
talosctl version --client
kubectl version --client
cilium version --client
flux version --client
az version

# Additional tools
k9s version
yq --version
sops --version
jq --version
```

#### Aliases and Functions
```bash
# Test aliases
k version --client  # Should work as kubectl
tf version          # Should work as terraform
t version --client  # Should work as talosctl

# Test functions
homelab-status      # Should show cluster status
homelab-config      # Should show config paths
```

#### Terraform Validation
```bash
cd terraform
terraform init -backend=false
terraform validate
terraform fmt -check
```

#### Azure Integration
```bash
# Check Azure mounting
ls -la ~/.azure/

# Test Azure CLI
az account show
az account list-locations --query "[?name=='East US'].name" -o tsv
```

## Expected DevContainer Features

### 📦 Installed Tools
- **Infrastructure**: Terraform, Azure CLI
- **Kubernetes**: kubectl, helm, k9s
- **Talos**: talosctl
- **Networking**: cilium CLI
- **GitOps**: flux CLI
- **Security**: sops
- **Utilities**: jq, yq, git, make

### 🔧 Configuration
- **Git**: Proper line endings (LF), no autocrlf
- **Aliases**: k, tf, t, cs shortcuts
- **Functions**: homelab-status, homelab-config, homelab-logs
- **Environment**: EDITOR, GIT_EDITOR set to VS Code

### 📁 Directory Structure
```
/workspaces/proxmox-iac/
├── .devcontainer/          # Container configuration
├── terraform/              # Infrastructure code
│   ├── azure-keyvault/     # Key Vault module
│   ├── talos/              # Talos cluster
│   └── bootstrap/          # Optional components
├── kubernetes/             # K8s configurations
├── Makefile               # Operational commands
├── deploy-talos-homelab.sh # Deployment script
├── validate-setup.sh      # Validation script
└── test-devcontainer.sh   # Container test script
```

### 🔐 Security Features
- **Azure credentials**: Mounted from host ~/.azure
- **SSH directory**: Created with proper permissions
- **No secrets**: In repository or container image

## Troubleshooting

### Common Issues

#### 1. Tools Not Found
**Symptom**: Command not found errors
**Solution**: 
```bash
# Check if setup script ran
ls -la ~/.bashrc

# Re-run setup if needed
bash .devcontainer/setup.sh

# Reload shell
source ~/.bashrc
```

#### 2. Azure Credentials Not Available
**Symptom**: `az account show` fails
**Solution**:
```bash
# Check mount
ls -la ~/.azure/

# Re-authenticate if needed
az login
```

#### 3. Terraform Issues
**Symptom**: Provider or module errors
**Solution**:
```bash
cd terraform
rm -rf .terraform*
terraform init -backend=false
terraform validate
```

#### 4. Permission Issues
**Symptom**: SSH or file permission errors
**Solution**:
```bash
# Fix SSH permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/* 2>/dev/null || true

# Fix workspace permissions
sudo chown -R vscode:vscode /workspaces/proxmox-iac/
```

### 5. Container Resource Issues
**Symptom**: Out of memory or disk space
**Solution**:
- Increase Docker resources in Docker Desktop
- Clean up unused containers: `docker system prune`
- Restart Docker Desktop

## Validation Checklist

After rebuild, verify these items work:

### ✅ Core Functionality
- [ ] All tools are installed and working
- [ ] Terraform validates successfully
- [ ] Azure CLI can authenticate
- [ ] Aliases and functions are available
- [ ] Git configuration is correct

### ✅ Project Specific
- [ ] Can run `make help`
- [ ] Can run `./validate-setup.sh`
- [ ] Terraform modules initialize correctly
- [ ] File permissions are correct
- [ ] VS Code extensions are loaded

### ✅ Ready for Deployment
- [ ] Can copy and edit terraform.tfvars
- [ ] Azure backend can be created
- [ ] Deployment script is executable
- [ ] All documentation is accessible

## Success Indicators

When the rebuild is successful, you should see:
1. ✅ All tools respond with version information
2. ✅ Terraform validation passes
3. ✅ Azure CLI shows your account
4. ✅ Aliases work as expected
5. ✅ Functions provide useful output
6. ✅ No permission errors

Your DevContainer is now ready for Talos cluster deployment! 🚀
