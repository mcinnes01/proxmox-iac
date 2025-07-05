# Proxmox K3s Configuration
# Based on HeekoOfficial/terraform-proxmox-k3s pattern

# Proxmox Configuration
proxmox_node          = "gateway"
node_template         = "ubuntu-24.04-cloud-init"
proxmox_resource_pool = "homelab-k3s"

# Network Configuration
network_gateway = "192.168.1.1"
lan_subnet      = "192.168.1.0/24"

# Control plane subnet: 192.168.1.2 -> 192.168.1.9 (8 IPs available)
control_plane_subnet = "192.168.1.2/29"

# SSH Keys
authorized_keys_file = "authorized_keys"

# Cluster Configuration
cluster_name       = "homelab"
master_nodes_count = 1

# Support Node Settings
support_node_settings = {
  cores     = 2
  memory    = 4096
  disk_size = "40G"
}

# Master Node Settings  
master_node_settings = {
  cores     = 2
  memory    = 4096
  disk_size = "40G"
  user      = "k3s"
}

# Worker Node Pools
node_pools = [
  {
    name = "workers"
    size = 2
    # Worker subnet: 192.168.1.9 -> 192.168.1.25 (16 IPs available)
    subnet = "192.168.1.9/28"
  }
]

# K3s Configuration
k3s_disable_components = [
  "traefik",
  "servicelb"
]

# DNS Settings
nameserver = "1.1.1.1"

# Proxy Settings (empty if not needed)
http_proxy = ""
