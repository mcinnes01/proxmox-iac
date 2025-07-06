# Proxmox K3s Infrastructure as Code

A fully automated Terraform configuration for deploying K3s clusters on Proxmox VE using the **bpg/proxmox** provider (actively maintained fork).

## Overview

This repository provides Infrastructure as Code for creating production-ready K3s clusters on Proxmox VE using:

- **Pure Terraform**: No Ansible or manual steps required
- **bpg/proxmox Provider**: Modern, actively maintained Proxmox integration
- **Static MAC Addresses**: Reproducible DHCP reservations
- **Automated Templates**: Automatic Ubuntu cloud image download and template creation
- **External Database**: MariaDB for cluster state
- **Load Balancer**: Built-in nginx for K3s API

## Features

- **Fully Automated**: Cloud image download, template creation, and VM deployment
- **High Availability**: Multi-master K3s cluster with external database
- **Modern Provider**: Uses bpg/proxmox provider with latest features
- **Cloud-Init**: Automated VM configuration and K3s installation
- **Reproducible**: Static MAC addresses for consistent DHCP reservations

## Quick Start

1. **Configure your deployment**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   nano terraform.tfvars  # Edit with your settings
   ```

2. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Access your cluster**:
   ```bash
   # SSH keys and kubeconfig will be generated automatically
   export KUBECONFIG="$(pwd)/kubeconfig.yaml"
   kubectl get nodes
   ```

## Architecture

This configuration creates:

1. **Ubuntu Template**: Creates a basic Ubuntu template for VM cloning
2. **Support Node**: MariaDB database server and nginx load balancer  
3. **Master Nodes**: K3s control plane nodes (configurable count)
4. **Worker Nodes**: K3s worker nodes (optional, configurable pools)

## Configuration

Key configuration options in `terraform.tfvars`:

```hcl
# Proxmox Connection
proxmox_api_url  = "https://192.168.1.1:8006/api2/json"
proxmox_username = "terraform-prov@pve"
proxmox_password = "your-password"

# Network Configuration
network_gateway = "192.168.1.1"
lan_subnet      = "192.168.1.0/24"
control_plane_subnet = "192.168.1.0/29"

# Cluster Configuration
cluster_name       = "homelab"
master_nodes_count = 1

# Node Settings
support_node_settings = {
  cores          = 1
  memory         = 2048
  storage_id     = "local-lvm"
  disk_size      = "20G"
  network_bridge = "vmbr0"
}

master_node_settings = {
  cores          = 1
  memory         = 2048
  storage_id     = "local-lvm"
  disk_size      = "20G"
  network_bridge = "vmbr0"
}
```

## Provider Information

This configuration uses the **bpg/proxmox** provider instead of the legacy Telmate provider:

- **Source**: `bpg/proxmox`
- **Version**: `>= 0.79.0`
- **Features**: Modern API support, better cloud-init integration, improved resource management
- **Documentation**: [https://registry.terraform.io/providers/bpg/proxmox/latest](https://registry.terraform.io/providers/bpg/proxmox/latest)

## Requirements

- Proxmox VE 7.0+
- Terraform 1.0+
- Network access to Ubuntu cloud images
- `local-lvm` storage (or configure alternative storage)
- SSH access to Proxmox host (for template creation)

## File Structure

```
├── terraform/
│   ├── main.tf              # Provider configuration
│   ├── versions.tf          # Provider version constraints
│   ├── variables.tf         # Variable definitions
│   ├── terraform.tfvars     # Configuration values
│   ├── support_node.tf      # Support node (DB + LB) + Template
│   ├── master_nodes.tf      # K3s master nodes
│   └── outputs.tf           # Output values
├── .devcontainer/           # VS Code dev container
└── README.md               # This file
```

## Outputs

After deployment, Terraform provides:

- **support_node_ip**: IP address of the support node
- **master_node_ips**: List of master node IP addresses
- **k3s_server_token**: K3s server token (sensitive)
- **Database passwords**: MariaDB passwords (sensitive)

## Development

This repository includes a VS Code devcontainer with all required tools:

- Terraform
- kubectl
- Docker
- GitHub CLI
- Python tools

## License

This project is open source and available under the MIT License.
```

Or create it in Proxmox web UI:
1. Go to Datacenter → Permissions → Users
