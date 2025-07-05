# Proxmox K3s User Guide

## Authentication & User Management

This guide explains how to set up secure authentication for your Proxmox K3s deployment.

### Overview

The deployment script automatically creates a dedicated `terraform-prov@pve` user with minimal privileges for secure operations. This follows security best practices by avoiding direct root access for infrastructure provisioning.

### Authentication Flow

1. **Initial Setup**: Script uses root credentials (password or API token) to create the dedicated user
2. **User Creation**: Creates `terraform-prov@pve` with random password and `PVEVMAdmin` role
3. **Configuration Update**: Updates `terraform.tfvars` with new user credentials
4. **Deployment**: Uses dedicated user for all Terraform operations

### Setup Options

#### Option 1: Automatic User Creation (Recommended)

```bash
# 1. Configure your deployment
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
nano terraform/terraform.tfvars  # Edit with your settings

# 2. Deploy (will prompt for root credentials to create user)
./deploy-k3s.sh deploy
```

The script will:
- Detect that authentication is not configured
- Prompt for root credentials (password or API token)
- Create `terraform-prov@pve` user with random password
- Update `terraform.tfvars` with new credentials
- Proceed with deployment

#### Option 2: Manual User Creation

```bash
# Create user first
./deploy-k3s.sh create-user

# Then deploy
./deploy-k3s.sh deploy
```

#### Option 3: Environment Variables

```bash
# Set authentication via environment variables
export PM_USER="terraform-prov@pve"
export PM_PASS="your-password"

# Or using API token
export PM_USER="terraform-prov@pve"
export PM_API_TOKEN_ID="terraform-token"
export PM_API_TOKEN_SECRET="your-token-secret"

# Deploy
./deploy-k3s.sh deploy
```

### User Permissions

The `terraform-prov@pve` user is assigned the `PVEVMAdmin` role, which provides:

- ✅ VM management (create, modify, delete)
- ✅ Template access
- ✅ Network configuration
- ✅ Storage operations
- ❌ User management
- ❌ Cluster administration
- ❌ Backup operations

This follows the principle of least privilege - only the permissions needed for VM provisioning.

### Security Best Practices

#### 1. Use Dedicated Users
- ✅ Create `terraform-prov@pve` for infrastructure operations
- ❌ Don't use root@pam for day-to-day operations

#### 2. Secure Credential Storage
- ✅ `terraform.tfvars` is git-ignored and contains sensitive data
- ✅ Use environment variables for CI/CD pipelines
- ❌ Don't commit credentials to version control

#### 3. API Tokens (Production)
For production deployments, consider using API tokens instead of passwords:

```bash
# In Proxmox web UI:
# 1. Go to Datacenter → API Tokens
# 2. Create token for terraform-prov@pve
# 3. Set privilege separation = unchecked
# 4. Copy token ID and secret

# In your deployment:
export PM_USER="terraform-prov@pve"
export PM_API_TOKEN_ID="terraform-token"
export PM_API_TOKEN_SECRET="your-token-secret"
```

#### 4. Regular Rotation
- Change passwords periodically
- Rotate API tokens regularly
- Update `terraform.tfvars` with new credentials

### Troubleshooting

#### User Already Exists
```bash
# If user exists but password is unknown
./deploy-k3s.sh create-user  # Will update password
```

#### Permission Denied
```bash
# Check user permissions in Proxmox UI
# Ensure PVEVMAdmin role is assigned at path "/"
```

#### Authentication Failed
```bash
# Verify credentials
curl -k "https://your-proxmox:8006/api2/json/version" \
  -u "terraform-prov@pve:your-password"
```

### Manual User Creation in Proxmox UI

If you prefer to create the user manually:

1. **Login to Proxmox Web UI** as root
2. **Navigate to Datacenter** → Permissions → Users
3. **Add User**:
   - User name: `terraform-prov`
   - Realm: `pve`
   - Password: Generate secure password
   - Email: Optional
4. **Assign Role**:
   - Go to Datacenter → Permissions → Add → User Permission
   - Path: `/`
   - User: `terraform-prov@pve`
   - Role: `PVEVMAdmin`
5. **Update terraform.tfvars**:
   ```hcl
   proxmox_username = "terraform-prov@pve"
   proxmox_password = "your-secure-password"
   ```

### Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `PM_USER` | Proxmox username | `terraform-prov@pve` |
| `PM_PASS` | Proxmox password | `your-password` |
| `PM_API_TOKEN_ID` | API token ID | `terraform-token` |
| `PM_API_TOKEN_SECRET` | API token secret | `12345678-1234-1234-1234-123456789012` |

### Advanced Configuration

#### Multiple Realms
```hcl
# For Active Directory integration
proxmox_username = "terraform-prov@ad"
```

#### Custom API Endpoint
```hcl
# Custom port or path
proxmox_api_url = "https://pve.example.com:8007/api2/json"
```

#### Debug Mode
```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
./deploy-k3s.sh deploy
```

## Quick Reference

```bash
# Complete deployment flow
./deploy-k3s.sh deploy         # Deploy cluster (creates user if needed)
./deploy-k3s.sh create-user    # Create user only
./deploy-k3s.sh validate       # Validate configuration
./deploy-k3s.sh info           # Show cluster info
./deploy-k3s.sh destroy        # Destroy cluster
```

For more details, see the main [README.md](README.md) and [terraform documentation](terraform/README.md).
