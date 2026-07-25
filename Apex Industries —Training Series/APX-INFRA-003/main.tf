resource "azurerm_resource_group" "apx_main_rg" {
  name = "${local.rgname}-rg"
location = var.org_infra.azure_location
tags = local.tags
}


resource "azurerm_storage_account" "apx_sa1" {
  name = "${local.storagename}sa"
  location = azurerm_resource_group.apx_main_rg.location
  tags = local.tags
resource_group_name = azurerm_resource_group.apx_main_rg.name
  account_tier = "Standard"
  account_replication_type = "LRS"
  
  access_tier = "Hot"
  
}


resource "azuread_group" "apx_sa_readers" {
    display_name = var.org_infra.group_name 
     security_enabled = true
    owners = [data.azuread_client_config.current.object_id]
     description      = "Members of the engineering team , who can acess the storage"
}


resource "azurerm_role_assignment" "apx_storage_access" {
  scope                = azurerm_storage_account.apx_sa1.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id           = azuread_group.apx_sa_readers.object_id
}

resource "azurerm_storage_management_policy" "apx_storage_access" {
   storage_account_id = azurerm_storage_account.apx_sa1.id

  rule {
    name    = "auto-delete-old-blobs"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
      
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 90
      }
    }
  }
}
