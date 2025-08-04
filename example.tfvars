# Proxmox node configuration
proxmox_node_name = "gateway"  # Your Proxmox node name
proxmox_admin_endpoint = "https://192.168.1.10:8006/"
proxmox_username = "admin@pam"
proxmox_password = "your-proxmox-password"
proxmox_insecure = true

# Network configuration
# Gateway/DNS: 192.168.1.254 (UDM Pro handles routing and DNS resolution)
# Internal DNS: proxmox.andisoft.co.uk → 192.168.1.10, home.andisoft.co.uk → 192.168.1.1
proxmox_vms_default_gateway = "192.168.1.254"

# VM Configuration with your specific requirements
proxmox_vms_talos = {
  # Control plane node: 1 CPU, 3GB RAM on 192.168.1.11
  controller1 = {
    id          = 100
    ip          = "192.168.1.11/24"
    controller  = true
    cpu_cores   = 1
    memory_mb   = 3072  # 3GB
  }
  # Worker node: 3 CPU, 9GB RAM on 192.168.1.5 (within 192.168.1.1-9 range)
  worker1 = {
    id          = 110
    ip          = "192.168.1.5/24"
    cpu_cores   = 3
    memory_mb   = 9216  # 9GB
  }
}

# MetalLB LoadBalancer IP pool
# 192.168.1.1 reserved for Home Assistant (home.andisoft.co.uk)
# 192.168.1.20-30 for other services (ingress controllers, databases, etc.)
metallb_pool_addresses = "192.168.1.1-192.168.1.1,192.168.1.20-192.168.1.30"

# GitOps configuration (optional - leave empty to skip Flux setup)
git_repository = ""  # Set to "https://github.com/mcinnes01/proxmox-iac" to enable Flux
git_branch = "main"

# GitHub token for creating GitHub App (required for Terraform to create the app)
# Create at: https://github.com/settings/tokens (Classic token)
# Required permissions: admin:repo_hook, repo
github_token = ""  # Your GitHub Personal Access Token

# GitHub App configuration (automatically filled by Terraform, or manual override)
github_app_name = "flux-homelab-app"
github_app_id = ""              # Auto-filled by Terraform
github_app_installation_id = "" # Auto-filled by Terraform  
github_app_private_key = ""     # Auto-filled by Terraform

# Path in repository where Flux manifests are stored
flux_path = "./flux"
