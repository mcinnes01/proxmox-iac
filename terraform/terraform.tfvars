# Proxmox Configuration
# To get API token:
# 1. Go to Proxmox → Datacenter → Permissions → API Tokens → Add
# 2. User: terraform@pve, Token ID: terraform, Privilege Separation: UNCHECKED
# 3. Copy the full token including UUID: terraform@pve!terraform=your-uuid-here
# 4. Ensure terraform@pve user exists with PVEAdmin role on path /
proxmox = {
  name         = "homelab"
  cluster_name = "homelab"
  endpoint     = "https://192.168.1.10:8006/"
  insecure     = true
  username     = "terraform@pve"
  api_token    = "terraform@pve!terraform=REPLACE_WITH_YOUR_TOKEN_UUID_HERE"
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
    cpu           = 1
    ram_dedicated = 3072
  }
  "talos-worker-01" = {
    host_node     = "pve"
    machine_type  = "worker"
    ip            = "192.168.1.3"
    mac_address   = "BC:24:11:2E:C8:01"
    vm_id         = 810
    cpu           = 3
    ram_dedicated = 9216
  }
}
