# Proxmox Configuration
proxmox = {
  endpoint  = "https://proxmox.andisoft.co.uk:8006/"
  insecure  = true
  api_token = "terraform@pve!terraform=REPLACE_WITH_YOUR_TOKEN"
}

# Cluster Configuration
cluster_name     = "homelab"
cluster_endpoint = "192.168.1.11"
cluster_gateway  = "192.168.1.254"
talos_version    = "v1.10"
proxmox_cluster  = "homelab"

# Node Configuration
nodes = {
  "talos-cp-01" = {
    host_node     = "pve"
    machine_type  = "controlplane"
    ip            = "192.168.1.11"
    mac_address   = "BC:24:11:2E:C8:00"
    vm_id         = 800
    cpu           = 4
    ram_dedicated = 8192
  }
  "talos-worker-01" = {
    host_node     = "pve"
    machine_type  = "worker"
    ip            = "192.168.1.1"
    mac_address   = "BC:24:11:2E:C8:01"
    vm_id         = 810
    cpu           = 4
    ram_dedicated = 8192
  }
}
