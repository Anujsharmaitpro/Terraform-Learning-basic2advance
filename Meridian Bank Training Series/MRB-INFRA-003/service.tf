resource "azurerm_service_plan" "mrb_srv_plan" {
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  location = azurerm_resource_group.mrb_main_rg.location
os_type = "Linux"
sku_name = "F1"
name = local.App_Service_Plan 
tags = local.mrb_tags   

}

resource "azurerm_linux_web_app" "mrb_web_app" {
  
resource_group_name = azurerm_resource_group.mrb_main_rg.name
location = azurerm_resource_group.mrb_main_rg.location
service_plan_id = azurerm_service_plan.mrb_srv_plan.id
name = local.App_Service
tags = local.mrb_tags

site_config {
  always_on = false
  application_stack {
      python_version = "3.11"
    }
}
app_settings = {
    "STORAGE_CONNECTION" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.vm_password.versionless_id})"
  }
lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }
 identity {
    type = "SystemAssigned"
  }

  
}


resource "azurerm_role_assignment" "app_kv_access" {
  scope                = azurerm_key_vault.mrb_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id          = azurerm_linux_web_app.mrb_web_app.identity[0].principal_id

  depends_on = [ azurerm_linux_web_app.mrb_web_app ]
}