resource "azurerm_key_vault" "mrb_vault" {
  sku_name = "standard"
  location = azurerm_resource_group.mrb_main_rg.location
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  name = local.key_vault
   tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 14
  purge_protection_enabled    = false
enable_rbac_authorization = true
tags = local.mrb_tags

network_acls {
  default_action = "Allow"
  bypass = "AzureServices"
}
   
}

resource "azurerm_role_assignment" "kv_role" {
  
principal_id = data.azurerm_client_config.current.object_id
scope = azurerm_key_vault.mrb_vault.id
role_definition_name = "Key Vault Secrets Officer"

}

resource "azurerm_key_vault_secret" "vm_password" {
  name         = "storage-connection-string"
  value        = "DefaultEndpointsProtocol=https;AccountName=mrbdemo;AccountKey=placeholder;"
  key_vault_id = azurerm_key_vault.mrb_vault.id

  depends_on = [azurerm_role_assignment.kv_role]
}