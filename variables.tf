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
