output "custom_role_id" {
  value       = azurerm_role_definition.vm_operator.role_definition_id
  description = "The ID of the Custom RBAC Role Definition"
}

output "dynamic_group_object_id" {
  value       = azuread_group.engineering_dept.object_id
  description = "The Object ID of the Dynamic Entra ID Group"
}

output "app_client_id" {
  value       = azuread_application.reporting_tool.client_id
  description = "The Application (Client) ID of the App Registration"
}

output "app_role_assignment_id" {
  value       = azuread_app_role_assignment.grant_consent.id
  description = "The ID of the Admin Consent App Role Assignment"
}