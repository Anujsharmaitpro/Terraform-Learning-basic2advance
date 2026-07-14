resource "azurerm_resource_group" "main_rg" {
  name     = var.main_config.resource_group_name
  location = var.main_config.azure_location
tags = local.tags
}





resource "azurerm_key_vault" "nct_kv" {
  name                        = var.main_config.key_vault_name
  location                    = azurerm_resource_group.main_rg.location
  resource_group_name         = azurerm_resource_group.main_rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  tags = local.tags

  sku_name = "standard"


  
network_acls {
    default_action = "Allow"
    bypass = "AzureServices"
}

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge",
    ]

    storage_permissions = [
      "Get",
    ]
  }

  
}

resource "azurerm_key_vault_secret" "key_secret1" {
  name         = "vm-admin-username"
value        = "nctadmin"
  key_vault_id = azurerm_key_vault.nct_kv.id
  tags = merge(local.tags, { SecretType = "infrastructure" })
}

resource "azurerm_key_vault_secret" "key_secret2" {
  name         = "vm-admin-password"
value        = "Nct@Secure2024!"
  key_vault_id = azurerm_key_vault.nct_kv.id
  tags = merge(local.tags, { SecretType = "infrastructure" })
}

resource "azurerm_key_vault_secret" "key_secret3" {
name         = "allowed-ssh-ip"
value        = "205.254.171.76"
  key_vault_id = azurerm_key_vault.nct_kv.id
  tags = merge(local.tags, { SecretType = "infrastructure" })
}