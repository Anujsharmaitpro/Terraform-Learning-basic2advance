output "All_out" {

  value = {
    name            = var.main_config.resource_group_name
    location        = var.main_config.azure_location
    object_id       = data.azurerm_client_config.current.object_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    tenant_id       = data.azurerm_client_config.current.tenant_id

     app_name = var.main_config.app_service_name

  }
}

output "app_service_url" {
  value       = "https://${azurerm_linux_web_app.web_app_name.default_hostname}"
  description = "The live URL of the Linux Web App."
}
