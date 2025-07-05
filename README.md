# Proxmox K3s Infrastructure as Code

A fully automated Terraform configuration for deploying K3s clusters on Proxmox VE, following the [HeekoOfficial/terraform-proxmox-k3s](https://github.com/HeekoOfficial/terraform-proxmox-k3s) pattern for pure Terraform automation with no manual intervention.

## Overview

This repository provides Infrastructure as Code for creating production-ready K3s clusters on Proxmox VE using:

- **Pure Terraform**: No Ansible or manual steps required
- **Telmate/proxmox Provider**: Industry-standard Proxmox integration
- **Static MAC Addresses**: Reproducible DHCP reservations
- **Node Pools**: Flexible worker node management
- **External Database**: MariaDB for cluster state
- **Load Balancer**: Built-in nginx for K3s API

## Architecture

### Components

1. **Support Node**: MariaDB database + nginx load balancer
2. **Master Nodes**: K3s control plane (HA configuration)
3. **Worker Node Pools**: Scalable worker nodes by pool

### Network Design

- **Control Plane Subnet**: Support + master nodes
- **Worker Subnets**: Dedicated subnets per node pool
- **Static IP Assignment**: Deterministic IP allocation
- **DHCP Exclusions**: Prevents IP conflicts

## Quick Start

### Prerequisites

- Proxmox VE 7.0+
- Ubuntu cloud-init template
- Two non-DHCP IP ranges
- Terraform 1.0+

### Basic Deployment

```bash
cd terraform/proxmox-k3s

# Copy and configure
cp provider.tf.example main.tf
cp terraform.tfvars.example terraform.tfvars

# Edit configuration files
vim main.tf        # Set Proxmox API URL
vim terraform.tfvars  # Configure your environment

# Authenticate
export PM_USER="terraform-prov@pve"
export PM_PASS="your-password"

# Deploy
terraform init
terraform apply

# Get kubeconfig
terraform output -raw k3s_kubeconfig > kubeconfig.yaml
export KUBECONFIG="kubeconfig.yaml"
kubectl get nodes
```

## Key Features

### HeekoOfficial Pattern Compliance

- **Telmate Provider**: Uses `Telmate/proxmox` provider (industry standard)
- **Static MACs**: Reproducible network configuration
- **Node Pools**: Flexible scaling and workload isolation
- **Cloud-Init**: Automated VM configuration
- **Remote Provisioners**: Direct K3s installation via SSH

### Production Ready

- **High Availability**: Multi-master with external datastore
- **External Database**: MariaDB on dedicated support node  
- **Load Balancing**: nginx proxy for K3s API
- **Rolling Updates**: Zero-downtime node pool updates
- **Security**: Firewall-enabled VMs with proper isolation

### Flexible Configuration

```hcl
# Multiple node pools with different specs
node_pools = [
  {
    name   = "general"
    size   = 3
    subnet = "192.168.1.208/28"
    cores  = 2
    memory = 4096
  },
  {
    name     = "compute"
    size     = 2
    subnet   = "192.168.1.224/28"
    cores    = 8
    memory   = 16384
    template = "ubuntu-compute-template"
  }
]
```

## Repository Structure

```
terraform/proxmox-k3s/
├── versions.tf              # Provider requirements
├── variables.tf             # Input variables
├── support_node.tf          # Support node (DB + LB)
├── master_nodes.tf          # K3s masters
├── worker_nodes.tf          # K3s worker pools
├── outputs.tf               # Cluster outputs
├── scripts/
│   ├── install-support-apps.sh.tftpl    # MariaDB + nginx setup
│   └── install-k3s-server.sh.tftpl      # K3s installation
├── provider.tf.example      # Provider configuration template
├── terraform.tfvars.example # Variables template
└── README.md                # Detailed documentation
```

## Configuration Examples

### Minimal Configuration

```hcl
# terraform.tfvars
proxmox_node         = "pve"
node_template        = "ubuntu-template"
network_gateway      = "192.168.1.1"
lan_subnet          = "192.168.1.0/24"
control_plane_subnet = "192.168.1.200/29"

node_pools = [
  {
    name   = "default"
    size   = 2
    subnet = "192.168.1.208/28"
  }
]
```

### Advanced Configuration

```hcl
# Custom node specifications
support_node_settings = {
  cores  = 4
  memory = 8192
  user   = "k3s"
}

master_node_settings = {
  cores  = 4
  memory = 8192
}

# Multiple worker pools
node_pools = [
  {
    name   = "general"
    size   = 3
    subnet = "192.168.1.208/28"
  },
  {
    name   = "gpu"
    size   = 1
    subnet = "192.168.1.224/28"
    taints = ["gpu=true:NoSchedule"]
    template = "ubuntu-gpu-template"
  }
]

# K3s customization
k3s_disable_components = ["traefik", "servicelb"]
api_hostnames = ["k3s.local"]
```

## Network Planning

### IP Range Requirements

You need **two non-DHCP IP ranges**:

1. **Control Plane**: Support + master nodes
   - Example: `192.168.1.200/29` (8 IPs)
   - Support: 192.168.1.200
   - Masters: 192.168.1.201, 192.168.1.202

2. **Worker Pools**: One subnet per pool
   - Example: `192.168.1.208/28` (16 IPs)
   - Workers: 192.168.1.208, 192.168.1.209, etc.

### DHCP Exclusions

**Critical**: Configure your router to exclude these ranges from DHCP to prevent IP conflicts.

## Operations

### Scaling

Add worker nodes by modifying node pools:

```hcl
node_pools = [
  {
    name   = "default"
    size   = 5  # Increased from 2
    subnet = "192.168.1.208/28"
  }
]
```

### Rolling Updates

Update node templates using rolling deployment:

1. Add new pool with updated template
2. Cordon and drain old nodes
3. Remove old pool configuration

### Monitoring

```bash
# Cluster health
kubectl get nodes
kubectl get pods -A

# Individual node status
ssh k3s@node-ip "sudo systemctl status k3s"

## Features

- **Pure Terraform**: No external dependencies or state management
- **Automated K3s Deployment**: Complete cluster setup in one command
- **Network Isolation**: Proper VLAN and subnet configuration
- **Secure by Default**: SSH key authentication and proper firewall rules
- **Scalable**: Easy to add/remove nodes
- **Production Ready**: Based on proven patterns and best practices

## Support

For issues specific to this configuration:
1. Check the [detailed README](terraform/proxmox-k3s/README.md)
2. Review [HeekoOfficial documentation](https://github.com/HeekoOfficial/terraform-proxmox-k3s)
3. Validate your Proxmox template and network configuration

## License

This configuration follows the MIT license pattern from the original HeekoOfficial repository.
