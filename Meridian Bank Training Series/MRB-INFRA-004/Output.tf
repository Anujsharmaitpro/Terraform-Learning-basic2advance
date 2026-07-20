

output "all_out" {

  value = {
    name = azurerm_resource_group.mrb_main_rg.name
    nsg  = azurerm_network_security_group.mrb_nsg.name
    # vm-name = azurerm_linux_virtual_machine.mrb_vm
    ap_test = local.fname
  }
}


output "vm_names_list" {
  value = [for mrb_vm in azurerm_linux_virtual_machine.mrb_vm : mrb_vm.name]
}
