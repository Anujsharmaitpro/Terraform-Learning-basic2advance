output "all_out" {

  value = {

    rg_name               = azurerm_resource_group.nct_main_rg.name
    key_vault_name        = azurerm_key_vault.nct_key_va.name
    key1                  = azurerm_mssql_firewall_rule.nct_firewall_rule
    sql_connection_string = nonsensitive(local.sql_connection_string)
    hack                  = nonsensitive(azurerm_key_vault_secret.nct_key.value)

    email = azurerm_monitor_action_group.nci_action_gp

    for_each = azurerm_monitor_metric_alert.nct_alerts

  }
}

# # ./outputs.tf (Root directory)

# output "final_webapp_name" {
#   value       = module.webapp.nct_app_service
#   description = "The web app name retrieved from the child module"
# }