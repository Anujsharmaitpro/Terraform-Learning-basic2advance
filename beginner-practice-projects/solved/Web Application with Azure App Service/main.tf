resource "azurerm_resource_group" "main_rg" {
  name     = var.main_config.resource_group_name
  location = var.main_config.azure_location
  tags     = local.tags
}



resource "azurerm_key_vault" "main_kv" {
  name                       = var.main_config.key_vault_name
  location                   = azurerm_resource_group.main_rg.location
  resource_group_name        = azurerm_resource_group.main_rg.name
  enable_rbac_authorization  = false
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }
}

resource "azurerm_key_vault_secret" "secret_key1" {
  name         = "app-secret-key"
  value        = "nct-super-secret-key-2024"
  key_vault_id = azurerm_key_vault.main_kv.id
}

resource "azurerm_key_vault_secret" "secret_dbkey" {
  name         = "db-connection"
  value        = "Server=nct-dev-sql;Database=nctapp;User=nctadmin;Password=Nct@2024!"
  key_vault_id = azurerm_key_vault.main_kv.id
}

resource "azurerm_key_vault_secret" "secret_envkey" {
  name         = "app-environment"
  value        = "development"
  key_vault_id = azurerm_key_vault.main_kv.id
}



resource "azurerm_service_plan" "app_srv_plan" {
  name = "nct-dev-app-plan"
  location = azurerm_resource_group.main_rg.location
  resource_group_name = azurerm_resource_group.main_rg.name
os_type = "Linux"
sku_name = "F1"

}

resource "azurerm_linux_web_app" "web_app_name" {
  name = var.main_config.app_service_name
  service_plan_id = azurerm_service_plan.app_srv_plan.id
  location = azurerm_resource_group.main_rg.location
  resource_group_name = azurerm_resource_group.main_rg.name
  
 site_config {
  always_on         = false          # must be false on Free tier F1
  application_stack {
    python_version  = "3.11"
  }

}

    app_settings = {
  "SECRET_KEY"                  = azurerm_key_vault_secret.secret_key1.value
  "DATABASE_URL"                = azurerm_key_vault_secret.secret_dbkey.value
  "APP_ENV"                     = azurerm_key_vault_secret.secret_envkey.value
  "WEBSITE_RUN_FROM_PACKAGE"    = "1"
  "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"

  }

  
lifecycle {
  ignore_changes = [
    app_settings["WEBSITE_RUN_FROM_PACKAGE"]
  ]
}
}

data "azurerm_client_config" "current" {

}
