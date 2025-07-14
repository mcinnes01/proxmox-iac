variable "proxmox_api" {
  description = "Proxmox API configuration"
  type = object({
    endpoint  = string
    insecure  = bool
    api_token = string
  })
  sensitive = true
}

variable "volume" {
  description = "Volume configuration"
  type = object({
    name    = string
    node    = string
    size    = string
    storage = optional(string, "local-lvm")
    vmid    = optional(number, 9999)
    format  = optional(string, "raw")
  })
}
