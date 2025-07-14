variable "proxmox_api" {
  description = "Proxmox API configuration"
  type = object({
    endpoint     = string
    insecure     = bool
    api_token    = string
    cluster_name = string
  })
  sensitive = true
}

variable "volumes" {
  description = "Volume configurations"
  type = map(
    object({
      node    = string
      size    = string
      storage = optional(string, "local-lvm")
      vmid    = optional(number, 9999)
      format  = optional(string, "raw")
    })
  )
}
