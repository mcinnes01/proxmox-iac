# Talos Kubernetes Homelab on Proxmox

**Complete Infrastructure-as-Code solution for deploying a production-grade Kubernetes cluster using Talos Linux on Proxmox VE**

This project implements modern best practices from the community including:
- [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) - GitOps patterns
- [jhulndev/terraform-talos-image-factory](https://github.com/jhulndev/terraform-talos-image-factory) - Image automation
- [Stonegarden Talos Proxmox Guide](https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/) - Complete architecture

## 🚀 Features

### Infrastructure & Security
- **Talos Linux**: Immutable, secure, API-driven Kubernetes OS
- **Terraform Automation**: Complete Proxmox infrastructure provisioning
- **Azure Integration**: State management and secrets via Azure Key Vault/Storage
- **Image Factory**: Automated Talos image building with custom extensions
- **DevContainer**: Consistent development environment with all tools

### Kubernetes & Networking
- **Cilium CNI**: Advanced networking with Gateway API, BGP, L2 announcements
- **Flux GitOps**: Declarative application deployment and configuration
- **Certificate Management**: Automated SSL/TLS with cert-manager
- **DNS Integration**: External DNS with Cloudflare support
- **Storage**: Proxmox CSI plugin for persistent volumes

### Monitoring & Operations
- **Sealed Secrets**: Secure secret management in Git
- **Hubble**: Network observability and troubleshooting
- **Health Checks**: Automated cluster validation
- **Upgrade Management**: Rolling updates with zero downtime

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Cloud                         │
│  ┌─────────────────┐  ┌─────────────────────────────────┐ │
│  │   Key Vault     │  │      Storage Account           │ │
│  │   (Secrets)     │  │    (Terraform State)           │ │
│  └─────────────────┘  └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                            │
                            │ (State & Secrets)
                            ▼
┌─────────────────────────────────────────────────────────┐
│                 Proxmox VE Cluster                     │
│                                                         │
│  ┌──────────────────┐    ┌──────────────────────────────┐ │
│  │  Talos Control   │    │     Talos Workers            │ │
│  │     Plane        │    │                              │ │
│  │                  │    │  ┌────────┐  ┌────────────┐  │ │
│  │  ┌────────────┐  │    │  │Worker-1│  │ Worker-N   │  │ │
│  │  │Control-1   │  │    │  │        │  │            │  │ │
│  │  │            │  │    │  └────────┘  └────────────┘  │ │
│  │  └────────────┘  │    │                              │ │
│  └──────────────────┘    └──────────────────────────────┘ │
│                                                         │
│         Cilium CNI + Gateway API + L2 Announcements     │
└─────────────────────────────────────────────────────────┘
                            │
                            │ (GitOps)
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    GitHub Repository                    │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────────────────────┐ │
│  │   Kubernetes    │  │        Flux System              │ │
│  │   Manifests     │  │     (GitOps Controller)         │ │
│  └─────────────────┘  └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
.
├── .devcontainer/              # Development container configuration
│   ├── devcontainer.json       # Container spec with all tools
│   └── setup.sh               # Tool installation script
├── terraform/                  # Infrastructure as Code
│   ├── providers.tf           # Terraform provider configuration
│   ├── variables.tf           # Variable definitions
│   ├── main.tf               # Main infrastructure calls
│   ├── outputs.tf            # Output definitions
│   ├── azure-keyvault/       # Azure Key Vault for secrets
│   │   ├── main.tf           # Key Vault infrastructure
│   │   ├── variables.tf      # Key Vault variables
│   │   └── outputs.tf        # Key Vault outputs
│   ├── talos/                # Talos cluster module
│   │   ├── image.tf          # Talos Image Factory integration
│   │   ├── talos-config.tf   # Cluster bootstrap configuration
│   │   ├── virtual-machines.tf # Proxmox VM definitions
│   │   ├── image/
│   │   │   └── schematic.yaml # Custom image specification
│   │   ├── machine-config/    # Node configuration templates
│   │   │   ├── control-plane.yaml.tftpl
│   │   │   └── worker.yaml.tftpl
│   │   └── inline-manifests/  # Bootstrap manifests
│   │       └── cilium-install.yaml
│   └── bootstrap/             # Optional cluster bootstrapping
│       ├── sealed-secrets/    # Secure secret management
│       ├── proxmox-csi-plugin/ # Persistent volume support
│       └── volumes/           # Volume provisioning
├── kubernetes/                # Kubernetes configurations
│   ├── cilium/               # CNI configuration
│   │   └── values.yaml       # Cilium feature configuration
│   ├── apps/                 # Application deployments
│   ├── flux-system/          # GitOps configuration
│   └── infrastructure/       # Infrastructure components
└── scripts/                  # Utility scripts
```

## 🚀 Quick Start

### Prerequisites

1. **Proxmox VE 8.2+** with API access
2. **Azure Subscription** for state and secrets management
3. **Docker** for DevContainer environment
4. **Git** for repository management

### Step 1: Environment Setup

1. Clone this repository:
```bash
git clone <your-repo>
cd proxmox-iac
```

2. Open in DevContainer (VS Code):
```bash
code .
# Select "Reopen in Container" when prompted
```

3. Configure Azure authentication:
```bash
# Login to Azure
az login

# Create resource group for state management
az group create --name homelab-state-rg --location eastus

# Create storage account for Terraform state
az storage account create \
  --name homelabstatestg \
  --resource-group homelab-state-rg \
  --location eastus \
  --sku Standard_LRS

# Get your Azure details for Key Vault access
az ad signed-in-user show --query id -o tsv  # Note this Object ID
```

### Step 2: Proxmox Configuration

1. Create API token in Proxmox:
   - Navigate to Datacenter → Permissions → API Tokens
   - Create token for `root@pam` user
   - Note the token ID and secret

2. Configure Terraform variables:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit with your Proxmox and Azure details
```

### Step 3: Azure Key Vault Setup (Optional but Recommended)

The deployment includes Azure Key Vault for secure secrets management:

1. **Automatic Configuration**: The deployment script will automatically:
   - Detect your Azure tenant and user details
   - Create a Key Vault with appropriate access policies
   - Configure Terraform to store sensitive outputs

2. **Manual Configuration**: Edit `terraform.tfvars`:
```hcl
# Azure Key Vault Configuration
azure = {
  tenant_id = "your-azure-tenant-id"
  object_id = "your-azure-object-id"  # From: az ad signed-in-user show --query id -o tsv
  location  = "East US"
}

enable_keyvault = true

# Store sensitive data in Key Vault
keyvault_secrets = {
  "proxmox-api-token"  = "your-proxmox-api-token"
  "flux-github-token"  = "your-github-pat"
  "cluster-ca-cert"    = "base64-encoded-ca-cert"
}
```

3. **Benefits of Key Vault Integration**:
   - Secure storage of sensitive cluster data
   - Centralized secrets management
   - Integration with Azure RBAC
   - Audit logging for secret access
   - No secrets in Terraform state files

### Step 4: Deploy Infrastructure

1. Initialize Terraform:
```bash
terraform init
```

2. Plan deployment:
```bash
terraform plan
```

3. Deploy cluster:
```bash
terraform apply
```

4. Wait for cluster bootstrap (5-10 minutes)

### Step 4: Access Your Cluster

1. Configure kubectl:
```bash
# Generated automatically in terraform/output/
export KUBECONFIG=$PWD/terraform/output/kube-config.yaml
kubectl get nodes
```

2. Verify Talos:
```bash
# Configure talosctl
export TALOSCONFIG=$PWD/terraform/output/talos-config.yaml
talosctl health
```

3. Check Cilium:
```bash
cilium status
```

## 🛠️ Management Operations

### Cluster Scaling

Add worker nodes by updating the `nodes` variable in `terraform/main.tf`:

```hcl
nodes = {
  "talos-cp-01" = {
    # ... existing control plane
  }
  "talos-worker-01" = {
    # ... existing worker
  }
  "talos-worker-02" = {  # New worker
    host_node     = "pve"
    machine_type  = "worker"
    ip            = "192.168.1.4"
    mac_address   = "BC:24:11:2E:C8:02"
    vm_id         = 811
    cpu           = 4
    ram_dedicated = 8192
  }
}
```

Apply changes:
```bash
terraform apply
```

### Cluster Upgrades

1. Update Talos version in `terraform/talos/variables.tf`
2. Apply rolling upgrade:
```bash
terraform apply
```

### Backup & Recovery

Export cluster configuration:
```bash
# Backup Talos config
talosctl cluster show > cluster-backup.yaml

# Backup etcd
talosctl etcd snapshot
```

## 🔧 Configuration Options

### Custom Talos Images

Modify `terraform/talos/image/schematic.yaml` to add system extensions:

```yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/i915-ucode
      - siderolabs/intel-ucode
      - siderolabs/qemu-guest-agent
      - siderolabs/nvidia-container-toolkit  # Add GPU support
```

### Cilium Features

Configure advanced networking in `kubernetes/cilium/values.yaml`:

```yaml
# Enable Gateway API
gatewayAPI:
  enabled: true

# Enable L2 announcements for LoadBalancer IPs  
l2announcements:
  enabled: true

# Enable Hubble for observability
hubble:
  enabled: true
  ui:
    enabled: true
```

### Storage Configuration

Enable Proxmox CSI plugin for persistent volumes:

```hcl
module "proxmox_csi_plugin" {
  source = "./bootstrap/proxmox-csi-plugin"
  # ... configuration
}
```

## 🐛 Troubleshooting

### Common Issues

**Cluster Bootstrap Fails:**
```bash
# Check Talos logs
talosctl logs -f

# Verify connectivity
talosctl health
```

**Pods Not Starting:**
```bash
# Check Cilium status
cilium status

# View pod events
kubectl describe pod <pod-name>
```

**Storage Issues:**
```bash
# Check CSI plugin
kubectl get pods -n csi-proxmox

# Verify PV/PVC status
kubectl get pv,pvc -A
```

### Debug Commands

```bash
# Cluster health overview
homelab-status

# Detailed Talos status
talosctl health --nodes <node-ip>

# Cilium connectivity test
cilium connectivity test

# Flux reconciliation
flux reconcile source git flux-system
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes in DevContainer
4. Test thoroughly
5. Submit pull request

## 📖 References

- [Talos Documentation](https://www.talos.dev/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Flux Documentation](https://fluxcd.io/)
- [Proxmox VE Documentation](https://pve.proxmox.com/)

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**Built with ❤️ for the homelab community**
