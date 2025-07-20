# Proxmox Configuration
# Generated automatically by setup-proxmox-auth.sh

proxmox_api_url = "https://192.168.1.10:8006/api2/json"
proxmox_username = ""
proxmox_password = ""
proxmox_api_token_id = "terraform-prov@pve!terraform"
proxmox_api_token_secret = "a1ce857d-4895-407c-86ad-a8959d084a6a"
proxmox_insecure = true

# Network Configuration
network_gateway = "192.168.1.254"
nameserver = "192.168.1.254"

# Proxmox Node Settings
proxmox_node = "gateway"
vm_datastore = "local-lvm"

# Enable Talos cluster
enable_talos_cluster = true
