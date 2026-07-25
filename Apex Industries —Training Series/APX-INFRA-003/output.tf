
output "ALL_OUT" {
  value = {

storage_account_name = azurerm_storage_account.apx_sa1.name
group_object_id =  azuread_group.apx_sa_readers.id

lifecycle_policy_id = azurerm_storage_management_policy.apx_storage_access.id
role_assignment_id = azurerm_role_assignment.apx_storage_access.id

  }


}







