# Proxmox Configuration
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.1.10:8006/api2/json"
}

variable "proxmox_username" {
  description = "Proxmox username (optional if using API token)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox password (optional if using API token)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  default     = "terraform-prov@pve!terraform-token"
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Allow insecure connections to Proxmox"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "gateway"
}

variable "vm_datastore" {
  description = "Datastore to use for VM disks"
  type        = string
  default     = "local-lvm"
}

# Network Configuration
variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.1.254"
}

variable "nameserver" {
  description = "DNS nameserver IP"
  type        = string
  default     = "192.168.1.254"
}

variable "network_cidr" {
  description = "Network CIDR for the cluster"
  type        = string
  default     = "192.168.1.0/24"
}

# Talos Configuration
variable "talos_version" {
  description = "Talos version to use"
  type        = string
  default     = "v1.8.1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.31.1"
}

variable "enable_talos_cluster" {
  description = "Enable Talos cluster deployment"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "homelab"
}

variable "cluster_endpoint" {
  description = "Cluster endpoint IP (should be control plane node IP)"
  type        = string
  default     = "192.168.1.11"
}

# VM Configuration
variable "control_plane_nodes" {
  description = "Control plane node configuration"
  type = map(object({
    ip_address   = string
    mac_address  = string
    vm_id        = number
    cpu_cores    = number
    memory_mb    = number
    disk_size_gb = number
  }))
  default = {
    "talos-cp-01" = {
      ip_address   = "192.168.1.11"
      mac_address  = "BC:24:11:2E:C8:01"
      vm_id        = 810
      cpu_cores    = 4
      memory_mb    = 8192
      disk_size_gb = 100
    }
  }
}

variable "worker_nodes" {
  description = "Worker node configuration"
  type = map(object({
    ip_address   = string
    mac_address  = string
    vm_id        = number
    cpu_cores    = number
    memory_mb    = number
    disk_size_gb = number
  }))
  default = {
    "talos-worker-01" = {
      ip_address   = "192.168.1.1"
      mac_address  = "BC:24:11:2E:C8:00"
      vm_id        = 800
      cpu_cores    = 6
      memory_mb    = 16384
      disk_size_gb = 200
    }
  }
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for services"
  type        = string
  default     = "andisoft.co.uk"
}

variable "internal_domain" {
  description = "Internal domain for cluster services"
  type        = string
  default     = "home.andisoft.co.uk"
}
