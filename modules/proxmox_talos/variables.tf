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
    id          = number
    ip          = string
    controller  = optional(bool)
    cpu_cores   = optional(number, 2)
    memory_mb   = optional(number, 4096)
  }))
  description = "Map of Talos VMs to create"
}

variable "proxmox_vms_default_gateway" {
  type = string
  description = "Default gateway for VMs"
}

variable "talos_disk_image_schematic_id" {
  type   = string
  description = "Talos disk image schematic ID from factory.talos.dev"
}

variable "talos_version" {
  type    = string
  description = "Talos version to deploy"
}

variable "talos_cluster_name" {
  type    = string
  description = "Name of the Talos cluster"
}

variable "talos_remove_cni" {
  type   = bool
  default = false
  description = "Remove default CNI to install custom one (e.g., Cilium)"
}
