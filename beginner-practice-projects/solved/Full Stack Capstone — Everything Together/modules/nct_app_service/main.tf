resource "azurerm_service_plan" "nct_app_srv_plan" {
  os_type             = "Linux"
  sku_name            = "F1"
  resource_group_name = var.resource_group_name
  location            = var.azure_location
  name                = "${var.org_prefix}-${var.environment}-${var.workload}-plan"
  tags                = var.tags
}

resource "azurerm_linux_web_app" "web_app_lin" {
  name                = "${var.org_prefix}-${var.environment}-${var.workload}-jd"
  resource_group_name = var.resource_group_name
  location            = var.azure_location
  service_plan_id     = azurerm_service_plan.nct_app_srv_plan.id
  tags                = var.tags

  site_config {
    always_on = false
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    DATABASE_URL   = var.sql_connection_string
    APP_SECRET_KEY = var.app_secret_key
  }

  lifecycle { ignore_changes = [app_settings["WEBSITE_RUN_FROM_PACKAGE"]] }
}