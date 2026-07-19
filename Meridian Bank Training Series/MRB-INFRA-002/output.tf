


output "MRG_OUT" {
  value = {
    resource_group_name = azurerm_resource_group.mrb_main_rg.name
    vnet                = azurerm_virtual_network.mrb_vnet.name
    subnet              = azurerm_subnet.mrb_subnet.name
    t2 = data.azurerm_client_config.current.object_id
pip =  azurerm_public_ip.mrb_pip.name
    nsg-rule =  azurerm_network_security_group.mrb_nsg.name

    testpass = nonsensitive(azurerm_key_vault_secret.vm_password.value)

    vmid = azurerm_linux_virtual_machine.mrb_vm.identity[0].principal_id
  }
}
