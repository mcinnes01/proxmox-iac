# Proxmox K3s Cluster with Terraform

A complete Terraform configuration for deploying a highly available K3s cluster on Proxmox VE following the [HeekoOfficial/terraform-proxmox-k3s](https://github.com/HeekoOfficial/terraform-proxmox-k3s) pattern.

## Features

- **Fully Automated**: No manual intervention required. Pure Terraform with no Ansible dependencies.
- **High Availability**: Multi-master K3s cluster with external database (MariaDB).
- **Load Balancer**: Built-in nginx load balancer for K3s API and ingress.
- **Static MAC Addresses**: Reproducible DHCP reservations using the `macaddress` provider.
- **Node Pools**: Flexible worker node pools for different workload types.
- **Cloud-Init**: Automated VM configuration and K3s installation.
- **External Database**: MariaDB on support node for cluster state storage.

## Architecture

This configuration creates:

1. **Support Node**: MariaDB database server and nginx load balancer
2. **Master Nodes**: K3s control plane nodes (typically 2 for HA)
3. **Worker Node Pools**: Flexible worker nodes grouped by pool

### Network Layout

- **Support Node**: First IP in control plane subnet (e.g., 192.168.1.200)
- **Master Nodes**: Subsequent IPs in control plane subnet (e.g., 192.168.1.201, 192.168.1.202)
- **Worker Nodes**: IPs from dedicated worker subnets (e.g., 192.168.1.208/28)

## Prerequisites

### Proxmox Requirements

- Proxmox VE 7.0 or later
- Sufficient resources for all nodes
- VM template with:
  - Cloud-init support
  - Ubuntu 20.04/22.04 or similar Debian-based OS
  - Template size ≤ 10GB (smallest node disk size)

### Network Requirements

- **Two CIDR ranges NOT in DHCP scope**:
  - Control plane subnet (for support + master nodes)
  - Worker node subnets (for worker pools)
- **Static IP ranges**: Reserve these IPs outside DHCP to prevent conflicts

### Terraform Requirements

- Terraform ≥ 1.0
- Required providers:
  - `Telmate/proxmox`
  - `ivoronin/macaddress`
  - `hashicorp/random`
  - `hashicorp/external`

## Quick Start

### 1. Clone and Configure

```bash
git clone <this-repository>
cd terraform/proxmox-k3s
```

### 2. Provider Configuration

Copy and customize the provider configuration:

```bash
cp provider.tf.example main.tf
# Edit main.tf with your Proxmox API URL
```

### 3. Variables Configuration

Copy and customize the variables:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your environment settings
```

### 4. Authentication

Set Proxmox authentication via environment variables:

```bash
export PM_USER="terraform-prov@pve"
export PM_PASS="your-password"
```

### 5. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 6. Get Kubeconfig

```bash
terraform output -raw k3s_kubeconfig > kubeconfig.yaml
export KUBECONFIG="kubeconfig.yaml"
kubectl get nodes
```

## Configuration

### Essential Variables

```hcl
# terraform.tfvars
proxmox_node         = "pve"                    # Proxmox node name
node_template        = "ubuntu-template"        # VM template name
network_gateway      = "192.168.1.1"           # Network gateway
lan_subnet          = "192.168.1.0/24"         # LAN subnet
control_plane_subnet = "192.168.1.200/29"      # Control plane IPs
```

### Node Pool Configuration

```hcl
node_pools = [
  {
    name   = "default"
    size   = 2
    subnet = "192.168.1.208/28"
    
    # Optional overrides
    cores    = 4
    memory   = 8192
    template = "custom-template"
  },
  {
    name   = "gpu"
    size   = 1
    subnet = "192.168.1.224/28"
    taints = ["gpu=true:NoSchedule"]
  }
]
```

### K3s Configuration

```hcl
k3s_disable_components = [
  "traefik",      # Disable default ingress
  "servicelb"     # Disable default load balancer
]

api_hostnames = [
  "k3s.local",
  "kubernetes.local"
]
```

## Node Pools and Scaling

### Adding Worker Nodes

To add a new worker pool:

```hcl
node_pools = [
  # Existing pools...
  {
    name   = "compute"
    size   = 3
    subnet = "192.168.1.240/28"
    cores  = 4
    memory = 8192
  }
]
```

Run `terraform apply` to add the new pool.

### Rolling Updates

To update nodes (e.g., new template):

1. **Add new pool** with updated configuration
2. **Cordon old nodes**: `kubectl cordon <node-name>`
3. **Drain workloads**: `kubectl drain <node-name> --ignore-daemonsets`
4. **Remove old pool** from configuration
5. **Apply changes**: `terraform apply`

## Networking

### IP Allocation

- **Support Node**: `cidrhost(control_plane_subnet, 0)`
- **Master Nodes**: `cidrhost(control_plane_subnet, 1+)`
- **Worker Nodes**: `cidrhost(pool_subnet, 0+)`

### DHCP Considerations

**CRITICAL**: Exclude these IP ranges from DHCP:

```
Control Plane: 192.168.1.200-207
Worker Pools:  192.168.1.208-223, 192.168.1.224-239, etc.
```

Configure your router to exclude these ranges to prevent IP conflicts.

## Security

### SSH Access

This configuration uses cloud-init for VM setup but doesn't configure SSH keys by default. For production use:

1. Add SSH public keys to your VM template
2. Or modify the configuration to include SSH key management

### Firewall

- Enable Proxmox firewall for VMs
- Configure appropriate security groups
- Consider network segmentation

## Troubleshooting

### Common Issues

1. **Template not found**: Ensure VM template exists and is accessible
2. **IP conflicts**: Verify DHCP exclusions are configured
3. **SSH connection failed**: Check cloud-init configuration and SSH keys
4. **Database connection failed**: Verify MariaDB setup on support node

### Debugging

Enable detailed logging:

```bash
export TF_LOG=DEBUG
terraform apply
```

Check Terraform logs:

```bash
tail -f terraform-plugin-proxmox.log
```

### Validation

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check K3s on nodes
ssh user@node-ip "sudo k3s kubectl get nodes"

# Check database connectivity
ssh user@support-ip "sudo mariadb -u k3s -p k3s -e 'SHOW TABLES;'"
```

## Outputs

| Output | Description |
|--------|-------------|
| `k3s_kubeconfig` | Kubernetes configuration file |
| `support_node_ip` | Support node IP address |
| `master_node_ips` | Master node IP addresses |
| `k3s_server_token` | K3s server token (sensitive) |
| `k3s_db_password` | Database password (sensitive) |

## Advanced Configuration

### Custom Templates

Use different templates per node pool:

```hcl
node_pools = [
  {
    name     = "cpu"
    template = "ubuntu-cpu-template"
    # ...
  },
  {
    name     = "gpu"
    template = "ubuntu-gpu-template"
    # ...
  }
]
```

### Proxy Configuration

For environments requiring HTTP proxy:

```hcl
http_proxy = "http://proxy.company.com:8080"
```

### Storage Configuration

Customize storage per node pool:

```hcl
node_pools = [
  {
    name         = "storage"
    storage_type = "scsi"
    storage_id   = "fast-ssd"
    disk_size    = "100G"
    # ...
  }
]
```

## Contributing

This configuration follows the HeekoOfficial/terraform-proxmox-k3s pattern. When contributing:

1. Maintain compatibility with the original design
2. Test changes thoroughly
3. Update documentation
4. Follow Terraform best practices

## License

This configuration is provided as-is. Refer to the original HeekoOfficial repository for licensing terms.

## References

- [HeekoOfficial/terraform-proxmox-k3s](https://github.com/HeekoOfficial/terraform-proxmox-k3s)
- [K3s Documentation](https://k3s.io/)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Terraform Proxmox Provider](https://github.com/Telmate/terraform-provider-proxmox)
