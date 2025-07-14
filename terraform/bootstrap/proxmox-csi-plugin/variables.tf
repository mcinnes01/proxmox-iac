variable "proxmox" {
  description = "Proxmox configuration"
  type = object({
    cluster_name = string
    endpoint     = string
    insecure     = bool
  })
  sensitive = true
}
