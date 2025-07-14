output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.homelab.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.homelab.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.homelab.vault_uri
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.keyvault.name
}

output "secret_references" {
  description = "Map of secret names to their Key Vault references"
  value = {
    for name, secret in azurerm_key_vault_secret.secrets :
    name => {
      id      = secret.id
      version = secret.version
      value   = secret.value
    }
  }
  sensitive = true
}
