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

variable "azure" {
  description = "Azure configuration for Key Vault"
  type = object({
    tenant_id = string
    object_id = string
    location  = string
  })
  default = {
    tenant_id = ""
    object_id = ""
    location  = "East US"
  }
}

variable "enable_keyvault" {
  description = "Enable Azure Key Vault for secrets management"
  type        = bool
  default     = true
}

variable "keyvault_secrets" {
  description = "Secrets to store in Azure Key Vault"
  type        = map(string)
  default     = {}
  sensitive   = true
}
