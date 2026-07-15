


# # data "azurerm_client_config" "current" {

# # }



# # data "azurerm_key_vault_secret" "app_secret_key" {
# #   depends_on   = [azurerm_key_vault_secret.secret_key1]
# #   name         = "app-secret-key"
# #   key_vault_id = azurerm_key_vault.main_kv.id
# # }

# # data "azurerm_key_vault_secret" "db_connection" {
# #   depends_on   = [azurerm_key_vault_secret.secret_dbkey]
# #   name         = "db-connection"
# #   key_vault_id = azurerm_key_vault.main_kv.id
# # }


# # data "azurerm_key_vault_secret" "app_environment" {
# #   depends_on   = [azurerm_key_vault_secret.secret_envkey]
# #   name         = "app-environment"
# #   key_vault_id = azurerm_key_vault.main_kv.id
# # }

# output "secret_value_app" {
#   value     = data.azurerm_key_vault_secret.app_secret_key.value
#   sensitive = true
# }
# output "secret_value_db" {
#   value     = data.azurerm_key_vault_secret.db_connection.value
#   sensitive = true
# }
# output "secret_value_env" {
#   value     = data.azurerm_key_vault_secret.app_environment.value
#   sensitive = true
# }