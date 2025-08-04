# HomeLab Kubernetes Platform

A complete Infrastructure as Code solution for deploying a production-ready Kubernetes platform on Proxmox, featuring Talos Linux, GitOps with Flux, and comprehensive observability.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Proxmox Host  │    │  Talos Master   │    │ Talos Workers   │
│  192.168.1.10   │────│ 192.168.1.11    │────│ 192.168.1.5-7   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Kubernetes    │
                    │   Platform      │
                    │                 │
                    │ • Flux GitOps   │
                    │ • MetalLB LB    │
                    │ • Longhorn CSI  │
                    │ • Cilium CNI    │
                    │ • Cert-Manager  │
                    │ • Observability │
                    └─────────────────┘
```

This setup creates a complete Kubernetes platform with a single `terraform apply` command, inspired by the [homelab-k8s-platform](https://github.com/ynovytskyy/homelab-k8s-platform) approach but using **Flux instead of ArgoCD** for GitOps.

## 🚀 Quick Start

### Prerequisites

- **Proxmox VE** running on 192.168.1.10
- **Terraform** v1.0+
- **kubectl** for cluster access
- **Git** for version control

### Network Configuration

- **Proxmox Server**: 192.168.1.10
- **Control Plane**: 192.168.1.11  
- **Worker Nodes**: 192.168.1.5-7
- **LoadBalancer Pool**: 192.168.1.50-60
- **Gateway**: 192.168.1.1

### Storage Configuration

Your Proxmox storage pools:
- **local** (30GB) - ISOs, templates, backups
- **local-lvm** (398GB) - Main storage pool
- **storage2** (238GB) - Additional LVM storage for VMs ✨

## 📋 Deployment Steps

### 1. Setup Proxmox Authentication

```bash
# Create Terraform user and API token in Proxmox
./scripts/setup-proxmox-auth.sh
```

### 2. Configure Variables

```bash
# Copy example configuration
cp example.tfvars terraform.tfvars

# Edit with your settings (mainly proxmox_password)
nano terraform.tfvars
```

### 3. Deploy Infrastructure

```bash
# Initialize and deploy
terraform init
terraform apply -var-file=terraform.tfvars

# Extract cluster access configs
mkdir -p ~/.kube ~/.talos
terraform output -raw kube_config > ~/.kube/config
terraform output -raw talos_config > ~/.talos/config

# Verify cluster
kubectl get nodes
```

## 🏗️ Platform Components

### Core Infrastructure
- **[Talos Linux](https://www.talos.dev/)** - Immutable Kubernetes OS
- **[Cilium](https://cilium.io/)** - eBPF-based networking & security
- **[Longhorn](https://longhorn.io/)** - Distributed persistent storage
- **[MetalLB](https://metallb.universe.tf/)** - Bare metal load balancer

### GitOps & Platform Services
- **[Flux](https://fluxcd.io/)** - GitOps continuous delivery (instead of ArgoCD)
- **Cert-Manager** - Automatic TLS certificates
- **External-DNS** - Automatic DNS management
- **Monitoring Stack** - Prometheus, Grafana, Loki

## 📁 Project Structure

```
.
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions  
├── output.tf              # Output definitions
├── example.tfvars         # Example configuration
├── modules/               # Terraform modules
│   ├── proxmox_talos/     # Proxmox VM + Talos cluster
│   ├── metallb/           # Load balancer setup
│   ├── longhorn/          # Storage system
│   └── flux/              # GitOps with Flux
├── scripts/               # Helper scripts
│   └── setup-proxmox-auth.sh
└── docs/                  # Documentation
```

## ⚙️ Module Details

### `proxmox_talos`
- Creates VMs on Proxmox using **storage2** for optimal performance
- Deploys Talos Linux with custom schematic (includes QEMU guest agent, iSCSI tools)
- Bootstraps Kubernetes cluster with CNI disabled (for Cilium)
- Provides kubeconfig and talosconfig outputs

### `metallb`
- Configures MetalLB in L2 mode
- Creates IP address pool (192.168.1.50-60)
- Enables LoadBalancer services on bare metal

### `longhorn`
- Deploys distributed storage across worker nodes
- Provides persistent volumes for stateful applications
- Web UI for storage management

### `flux`
- Installs Flux GitOps operator
- Configures Git repository synchronization (if specified)
- Manages application deployment from Git

## 🔧 Customization

### Adding More Workers

```hcl
# In terraform.tfvars
proxmox_vms_talos = {
  controller1 = { id = 100, ip = "192.168.1.11/24", controller = true }
  worker1 = { id = 110, ip = "192.168.1.5/24" }
  worker2 = { id = 111, ip = "192.168.1.6/24" }
  worker3 = { id = 112, ip = "192.168.1.7/24" }
  worker4 = { id = 113, ip = "192.168.1.8/24" }  # Add more
}
```

### GitOps Setup

```hcl
# In terraform.tfvars - enable Flux GitOps
git_repository = "https://github.com/your-username/homelab-gitops"
git_branch = "main"
```

### Resource Allocation
- **Control Plane**: 4 CPU cores, 4GB RAM, 50GB disk
- **Workers**: 3 CPU cores, 3GB RAM, 40GB disk
- **Storage**: Uses your 238GB `storage2` LVM pool

## 🔍 Monitoring & Operations

### Useful Commands

```bash
# Cluster status
kubectl get nodes,pods --all-namespaces

# Talos operations
talosctl --nodes 192.168.1.11 dashboard
talosctl --nodes 192.168.1.11 health

# Storage verification  
kubectl get pv,pvc,storageclass

# Load balancer status
kubectl -n metallb-system get all
kubectl get svc --all-namespaces | grep LoadBalancer

# GitOps status (if enabled)
kubectl -n flux-system get all
```

### Accessing Services

```bash
# Port-forward to access internal services
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80

# View MetalLB assignments
kubectl describe svc <service-name>
```

## 🚨 Troubleshooting

### Common Issues

1. **VM Creation Fails**
   ```bash
   # Check storage availability
   pvesm status
   # Verify network connectivity
   ping 192.168.1.10
   ```

2. **Talos Bootstrap Issues**
   ```bash
   # Check machine health
   talosctl --nodes 192.168.1.11 health
   # View logs
   talosctl --nodes 192.168.1.11 logs controller-runtime
   ```

3. **Flux Not Syncing**
   ```bash
   # Check Flux status
   kubectl -n flux-system get gitrepository,kustomization
   # Force reconciliation
   flux reconcile source git homelab-gitops
   ```

## 📚 Key Differences from Original

This implementation follows the excellent [homelab-k8s-platform](https://github.com/ynovytskyy/homelab-k8s-platform) structure but includes these changes:

✅ **Flux instead of ArgoCD** - More lightweight GitOps solution  
✅ **Your network layout** - Master on .11, workers on .5-.7  
✅ **Storage2 integration** - Uses your 238GB LVM storage pool  
✅ **Enhanced documentation** - Comprehensive setup guide  
✅ **Preserved scripts** - Keeps your Proxmox auth setup script  

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## 📄 License

MIT License - feel free to use this for your homelab!

## 🆘 Support

- 📖 Check troubleshooting section above
- 🐛 Open an issue for bugs
- 💡 Discussions for questions and ideas

---

**Happy HomeLab-ing!** 🏠⚡
