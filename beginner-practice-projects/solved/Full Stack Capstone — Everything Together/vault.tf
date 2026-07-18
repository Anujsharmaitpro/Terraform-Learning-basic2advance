

resource "azurerm_key_vault" "nct_key_va" {
  resource_group_name        = azurerm_resource_group.nct_main_rg.name
  location                   = azurerm_resource_group.nct_main_rg.location
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  name                       = var.core_config.key_vault_name
  tags                       = local.nct_tags
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"

  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set"
    ]

    storage_permissions = [
      "Get",
    ]
  }

}


resource "azurerm_key_vault_secret" "nct_username" {
  name         = "sql-admin-username"
  value        = "nctdbadmin"
  key_vault_id = azurerm_key_vault.nct_key_va.id
 tags     = local.nct_tags
}

resource "azurerm_key_vault_secret" "nct_password" {
  name         = "sql-admin-password"
  value        = "NctCapstone@2024!"
  key_vault_id = azurerm_key_vault.nct_key_va.id
 tags     = local.nct_tags
}

resource "azurerm_key_vault_secret" "nct_key" {
  name         = "app-secret-key"
  value        = "nct-capstone-secret-key"
  key_vault_id = azurerm_key_vault.nct_key_va.id
 tags     = local.nct_tags
}

data "azurerm_key_vault" "nct_key_out" {
  name                = azurerm_key_vault.nct_key_va.name
  resource_group_name = azurerm_resource_group.nct_main_rg.name

}

output "vault_uri" {
  value = data.azurerm_key_vault.nct_key_out.vault_uri
}
