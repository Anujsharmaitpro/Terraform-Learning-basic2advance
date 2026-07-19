


output "MRG_OUT" {
  value = {

    mrg_name = nonsensitive(local.mrb_name)
    main_rg  = nonsensitive(azurerm_resource_group.mrb_main_rg.name)

sanem = nonsensitive(azurerm_storage_account.mrb_storage.name)
conname =  nonsensitive(azurerm_storage_container.mbr_container.name)

  }

}

output "blob_endpoint" {
  description = "The primary endpoint URL for blob storage"
  value       = azurerm_storage_account.mrb_storage.primary_blob_endpoint
}
