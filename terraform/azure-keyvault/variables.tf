variable "resource_group_name" {
  description = "Name of the resource group for Key Vault"
  type        = string
  default     = "homelab-keyvault-rg"
}

variable "location" {
  description = "Azure region for Key Vault"
  type        = string
  default     = "East US"
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = "homelab-secrets-kv"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "homelab"
    Purpose     = "secrets-management"
    ManagedBy   = "terraform"
  }
}

variable "secrets" {
  description = "Map of secrets to store in Key Vault"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "object_id" {
  description = "Object ID of the user/service principal to grant access"
  type        = string
}
