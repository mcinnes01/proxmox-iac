variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.1.1:8006/api2/json)"
  type        = string
  validation {
    condition     = can(regex("^https?://.*", var.proxmox_api_url))
    error_message = "The proxmox_api_url must be a valid URL starting with http:// or https://."
  }
}

variable "proxmox_username" {
  description = "Proxmox username for authentication (e.g., terraform-prov@pve or root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password for authentication (leave empty if using API token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (e.g., terraform)"
  type        = string
  default     = ""
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

# SSH Configuration
variable "ssh_user" {
  description = "SSH username for connecting to nodes"
  type        = string
  default     = "k3s"
}

variable "ssh_private_key_file" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# Proxmox Node Configuration
variable "proxmox_node" {
  description = "Proxmox node to create VMs on."
  type        = string
}

variable "network_gateway" {
  description = "IP address of the network gateway."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", var.network_gateway))
    error_message = "The network_gateway value must be a valid ip."
  }
}

variable "lan_subnet" {
  description = <<EOF
Subnet used by the LAN network. Note that only the bit count number at the end
is acutally used, and all other subnets provided are secondary subnets.
EOF
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", var.lan_subnet))
    error_message = "The lan_subnet value must be a valid cidr range."
  }
}

variable "control_plane_subnet" {
  description = <<EOF
Subnet used by the control plane (master) nodes.
EOF
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", var.control_plane_subnet))
    error_message = "The control_plane_subnet value must be a valid cidr range."
  }
}

variable "cluster_name" {
  default     = "k3s"
  type        = string
  description = "Name of the cluster used for prefixing cluster components (ie nodes)."
}

variable "node_template" {
  type        = string
  description = <<EOF
Proxmox vm to use as a base template for all nodes. Can be a template or
another vm that supports cloud-init.
EOF
}

variable "proxmox_resource_pool" {
  description = "Resource pool name to use in proxmox to better organize nodes."
  type        = string
  default     = ""
}

variable "support_node_settings" {
  type = object({
    cores          = optional(number),
    sockets        = optional(number),
    memory         = optional(number),
    storage_type   = optional(string),
    storage_id     = optional(string),
    disk_size      = optional(string),
    user           = optional(string),
    db_name        = optional(string),
    db_user        = optional(string),
    network_bridge = optional(string),
    network_tag    = optional(number),
  })
  default = {}
}

variable "master_nodes_count" {
  description = "Number of master nodes."
  default     = 2
  type        = number
}

variable "master_node_settings" {
  type = object({
    cores          = optional(number),
    sockets        = optional(number),
    memory         = optional(number),
    storage_type   = optional(string),
    storage_id     = optional(string),
    disk_size      = optional(string),
    user           = optional(string),
    network_bridge = optional(string),
    network_tag    = optional(number),
  })
  default = {}
}

variable "node_pools" {
  description = "Node pool definitions for the cluster."
  type = list(object({
    name   = string,
    size   = number,
    subnet = string,

    taints = optional(list(string)),

    cores        = optional(number),
    sockets      = optional(number),
    memory       = optional(number),
    storage_type = optional(string),
    storage_id   = optional(string),
    disk_size    = optional(string),
    user         = optional(string),
    network_tag  = optional(number),

    template = optional(string),

    network_bridge = optional(string),
  }))
}

variable "api_hostnames" {
  description = "Alternative hostnames for the API server."
  type        = list(string)
  default     = []
}

variable "k3s_disable_components" {
  description = "List of components to disable. Ref: https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/#kubernetes-components"
  type        = list(string)
  default     = []
}

variable "http_proxy" {
  default     = ""
  type        = string
  description = "http_proxy"
}

variable "nameserver" {
  default     = ""
  type        = string
  description = "nameserver"
}
