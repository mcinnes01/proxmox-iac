variable "proxmox" {
  description = "Proxmox configuration"
  type = object({
    name         = string
    cluster_name = string
    endpoint     = string
    insecure     = bool
    username     = string
    api_token    = string
  })
  sensitive = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "homelab"
}

variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint IP"
  type        = string
  default     = "192.168.1.11"
}

variable "cluster_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.1.254"
}

variable "talos_version" {
  description = "Talos version to use"
  type        = string
  default     = "v1.10"
}

variable "proxmox_cluster" {
  description = "Proxmox cluster name"
  type        = string
  default     = "homelab"
}

variable "nodes" {
  description = "Map of cluster nodes configuration"
  type = map(object({
    host_node     = string
    machine_type  = string
    ip            = string
    mac_address   = string
    vm_id         = number
    cpu           = number
    ram_dedicated = number
  }))
}
