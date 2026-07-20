resource "azurerm_linux_virtual_machine" "mrb_vm" {

  for_each              = toset(var.vm_names)
  name                  = "${local.Virtual_Machine}-${each.value}"
  location              = azurerm_resource_group.mrb_main_rg.location
  resource_group_name   = azurerm_resource_group.mrb_main_rg.name
  tags                  = local.mrb_tags
  size                  = var.mrb_infra.vm_size
  network_interface_ids = [azurerm_network_interface.mrb_nic[each.key].id]
  admin_username        = var.mrb_infra.admin_username



  disable_password_authentication = true
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }


  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.mrb_infra.admin_username
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }
  # Reads the script from your local project folder and encodes it
  custom_data = filebase64("${path.module}/userdata.sh")
}
