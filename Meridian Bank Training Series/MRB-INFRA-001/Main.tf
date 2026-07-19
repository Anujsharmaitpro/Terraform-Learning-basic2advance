resource "azurerm_resource_group" "mrb_main_rg" {

  name     = var.mrb_infra.resource_group_name
  location = var.mrb_infra.azure_location
tags = local.mrb_tags
}



resource "azurerm_storage_account" "mrb_storage" {
location = azurerm_resource_group.mrb_main_rg.location
resource_group_name = azurerm_resource_group.mrb_main_rg.name
account_replication_type = "LRS"
name = "${var.mrb_infra.storage_account_name}sa"
access_tier = "Hot"
account_tier = "Standard"
tags = local.mrb_tags

allow_nested_items_to_be_public = false
https_traffic_only_enabled = true
min_tls_version = "TLS1_2"
blob_properties {
  versioning_enabled = true
  delete_retention_policy {days = var.mrb_infra.soft_delete_days}
container_delete_retention_policy {days = var.mrb_infra.soft_delete_days}
}

}

resource "azurerm_storage_container" "mbr_container" {
  name = "${var.mrb_infra.container_name}-audit-logs"
  storage_account_name = azurerm_storage_account.mrb_storage.name
container_access_type = "private"
}