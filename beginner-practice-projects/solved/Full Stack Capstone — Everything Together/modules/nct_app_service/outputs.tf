output "app_service_id" {
  # FIX: Change from azurerm_service_plan to azurerm_linux_web_app
  value = azurerm_linux_web_app.web_app_lin.id
}

output "app_service_name" {
  value = azurerm_linux_web_app.web_app_lin.name
}

output "app_service_url" {
  value       = "https://${azurerm_linux_web_app.web_app_lin.default_hostname}"
  description = "The publicly accessible URL of the Azure App Service"
}