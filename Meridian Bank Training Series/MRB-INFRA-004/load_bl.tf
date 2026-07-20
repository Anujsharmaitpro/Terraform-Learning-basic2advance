resource "azurerm_public_ip" "mrb_pip" {
  name                = local.LB_Public_IP
  location            = azurerm_resource_group.mrb_main_rg.location
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
  tags                = local.mrb_tags
}

resource "azurerm_lb" "mrb_lb" {
  name                = local.Load_Balancer
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  location            = azurerm_resource_group.mrb_main_rg.location
  tags                = local.mrb_tags
  frontend_ip_configuration {
    name                 = "${local.Load_Balancer}-fip"
    public_ip_address_id = azurerm_public_ip.mrb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "mrb_lb_pool" {
  name = local.Backend_Pool
  loadbalancer_id = azurerm_lb.mrb_lb.id
   
}

resource "azurerm_lb_probe" "mrb_lb_probe" {
  name = local.Health_Probe
    port            = 80
  loadbalancer_id = azurerm_lb.mrb_lb.id
  protocol = "Tcp"
  }


  resource "azurerm_lb_rule" "mrb_ib_rules" {
 loadbalancer_id                = azurerm_lb.mrb_lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "${local.Load_Balancer}-fip"
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.mrb_lb_pool.id]
   probe_id  =azurerm_lb_probe.mrb_lb_probe.id

  }


  resource "azurerm_network_interface_backend_address_pool_association" "bk_nic_ass" {
    for_each = var.vm_names
  network_interface_id = azurerm_network_interface.mrb_nic[each.key].id
  ip_configuration_name = "private-ip_allocation"
  backend_address_pool_id = azurerm_lb_backend_address_pool.mrb_lb_pool.id
    
  }