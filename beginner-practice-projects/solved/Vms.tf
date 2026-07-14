

resource "azurerm_virtual_machine" "my-vm" {
  
  name                  = "${var.main_config.org_prefix}-${var.main_config.environment}-vm"
  location              = azurerm_resource_group.main_rg.location
  resource_group_name   = azurerm_resource_group.main_rg.name
  network_interface_ids = [azurerm_network_interface.l_nic.id]
  vm_size               = var.main_config.vm_size

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.main_config.org_prefix}-${var.main_config.environment}-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 40

  }
  os_profile {
    computer_name  = "${var.main_config.org_prefix}-${var.main_config.environment}-linux"
    admin_username = data.azurerm_key_vault_secret.vm_admin_username.value
       admin_password = data.azurerm_key_vault_secret.vm_admin_password.value

  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  
tags = local.tags

depends_on = [ azurerm_key_vault_secret.key_secret1 , azurerm_key_vault_secret.key_secret2]

}


