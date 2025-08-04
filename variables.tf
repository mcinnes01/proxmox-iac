variable "proxmox_node_name" {
  type = string
  description = "Proxmox node name"
}

variable "proxmox_admin_endpoint" {
  type = string
  description = "Proxmox admin endpoint URL"
}

variable "proxmox_username" {
  type = string
  description = "Proxmox username"
}

variable "proxmox_password" {
  type = string
  description = "Proxmox password"
  sensitive = true
}

variable "proxmox_insecure" {
  type = bool
  default = false
  description = "Allow insecure TLS connections to Proxmox"
}

variable "proxmox_vms_talos" {
  type = map(object({
    id     = number
    ip     = string
    controller = optional(bool)
  }))
  description = "Map of Talos VMs to create"
}

variable "proxmox_vms_default_gateway" {
  type = string
  description = "Default gateway for VMs"
}

variable "metallb_pool_addresses" {
  type = string
  description = "MetalLB IP address pool range"
}

variable "git_repository" {
  type = string
  description = "Git repository URL for Flux GitOps"
  default = ""
}

variable "git_branch" {
  type = string
  description = "Git branch for Flux GitOps"
  default = "main"
}

# GitHub App configuration for Flux authentication
variable "github_token" {
  type = string
  description = "GitHub personal access token for creating GitHub App"
  sensitive = true
  default = ""
}

variable "github_app_name" {
  type = string
  description = "Name for the GitHub App (will be created automatically)"
  default = "flux-homelab-app"
}

variable "github_app_id" {
  type = string
  description = "GitHub App ID (from manually created app)"
  default = ""
}

variable "github_app_installation_id" {
  type = string
  description = "GitHub App Installation ID (from manually created app)"
  default = ""
}

variable "github_app_private_key" {
  type = string
  description = "GitHub App private key in PEM format (from manually created app)"
  sensitive = true
  default = ""
}

variable "flux_path" {
  type = string
  description = "Path in repository where Flux manifests are stored"
  default = "./flux"
}
