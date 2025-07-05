# Provider Configuration
# This file should be copied to main.tf and customized for your environment

provider "proxmox" {
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_debug      = true
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }

  # Configuration from variables
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_username
  pm_tls_insecure = var.proxmox_insecure

  # Use either password or API token authentication
  pm_password         = var.proxmox_password != "" ? var.proxmox_password : null
  pm_api_token_id     = var.proxmox_api_token_id != "" ? var.proxmox_api_token_id : null
  pm_api_token_secret = var.proxmox_api_token_secret != "" ? var.proxmox_api_token_secret : null
}
