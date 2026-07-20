

output "all_out" {
  
  value = {
name = azurerm_resource_group.mrb_main_rg.name

appid= azurerm_linux_web_app.mrb_web_app.identity[0].principal_id
kv= azurerm_key_vault.mrb_vault.id
  }
}


output "app_service_url" {
  value       = "https://${azurerm_linux_web_app.mrb_web_app.default_hostname}"
  description = "The default URL of the App Service"
}


# Retrieve an existing Key Vault
data "azurerm_key_vault" "my_uri" {
  name                =  azurerm_key_vault.mrb_vault.name
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
}

# Output the Key Vault URI
output "key_vault_uri" {
  value = data.azurerm_key_vault.my_uri.vault_uri
}
