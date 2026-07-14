output "All_out" {

  value = {
      name     = var.main_config.resource_group_name
location = var.main_config.azure_location
object_id  = data.azurerm_client_config.current.object_id
subscription_id = data.azurerm_client_config.current.subscription_id
tenant_id = data.azurerm_client_config.current.tenant_id
key_vault_id = azurerm_key_vault.nct_kv.id
user = nonsensitive(data.azurerm_key_vault_secret.vm_admin_username.value)

  }
}