resource "azurerm_mssql_server" "nct_mssql" {
  name                         = var.core_config.sql_server_name
  resource_group_name          = azurerm_resource_group.nct_main_rg.name
  location                     = azurerm_resource_group.nct_main_rg.location
  version                      = "12.0"
  minimum_tls_version          = "1.2"
  administrator_login          = azurerm_key_vault_secret.nct_username.value
  administrator_login_password = azurerm_key_vault_secret.nct_password.value
 tags     = local.nct_tags
}

resource "azurerm_mssql_database" "nct_sql_db" {
  server_id   = azurerm_mssql_server.nct_mssql.id
  name        = var.core_config.sql_database_name
  max_size_gb = 2
  sku_name    = "Basic"
 tags     = local.nct_tags

}

resource "azurerm_mssql_firewall_rule" "nct_firewall_rule" {
  server_id = azurerm_mssql_server.nct_mssql.id
  for_each  = merge(local.sql_firewall_rules...)

  start_ip_address = each.value
  name             = each.key
  end_ip_address   = each.value

}



