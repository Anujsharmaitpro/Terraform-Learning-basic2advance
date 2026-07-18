resource "azurerm_resource_group" "nct_main_rg" {
  name     = "${local.org_fname}-010-rg"
  location = var.core_config.azure_location
  tags     = local.nct_tags
}

module "web_app" {
  source                = "./modules/nct_app_service"
  sql_connection_string = local.sql_connection_string
  azure_location        = var.core_config.azure_location
  tags                  = local.nct_tags
  resource_group_name   = azurerm_resource_group.nct_main_rg.name
  app_secret_key        = azurerm_key_vault_secret.nct_key.value
  org_prefix            = var.core_config.org_prefix
  workload              = "${local.org_fname}-web"
  environment           = var.core_config.environment


}

module "api_app" {
  source                = "./modules/nct_app_service"
  sql_connection_string = local.sql_connection_string
  azure_location        = var.core_config.azure_location
  tags                  = local.nct_tags
  resource_group_name   = azurerm_resource_group.nct_main_rg.name
  app_secret_key        = azurerm_key_vault_secret.nct_key.value
  org_prefix            = var.core_config.org_prefix
  workload              = "${local.org_fname}-api"
  environment           = var.core_config.environment
}


