resource "azurerm_resource_group" "mrb_main_rg" {
  name     = local.mrb_rgname
  location = var.mrb_infra.azure_location
  tags     = local.mrb_tags
}