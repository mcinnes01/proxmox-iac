# Provider Configuration
# Using the bpg/proxmox provider (actively maintained fork)

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  username  = var.proxmox_username
  password  = var.proxmox_password
  insecure  = var.proxmox_insecure
  
  ssh {
    agent = true
  }
}
