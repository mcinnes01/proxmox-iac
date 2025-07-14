# Data source to get current Azure configuration
data "azurerm_client_config" "current" {}

# Generate a unique suffix for Key Vault name
resource "random_string" "kv_suffix" {
  length  = 8
  upper   = false
  special = false
}

# Resource Group for Key Vault
resource "azurerm_resource_group" "keyvault" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Key Vault
resource "azurerm_key_vault" "homelab" {
  name                = "${var.key_vault_name}-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.keyvault.location
  resource_group_name = azurerm_resource_group.keyvault.name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # Enable for Azure DevOps Service Principal access if needed
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true

  # Soft delete and purge protection
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = var.tags
}

# Access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "homelab_admin" {
  key_vault_id = azurerm_key_vault.homelab.id
  tenant_id    = var.tenant_id
  object_id    = var.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Purge"
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Create",
    "Import",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "ManageContacts",
    "ManageIssuers",
    "GetIssuers",
    "ListIssuers",
    "SetIssuers",
    "DeleteIssuers",
    "Purge"
  ]

  key_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Decrypt",
    "Encrypt",
    "UnwrapKey",
    "WrapKey",
    "Verify",
    "Sign",
    "Purge"
  ]
}

# Store secrets in Key Vault
resource "azurerm_key_vault_secret" "secrets" {
  for_each = nonsensitive(var.secrets)

  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.homelab.id
  tags         = var.tags

  depends_on = [azurerm_key_vault_access_policy.homelab_admin]
}
