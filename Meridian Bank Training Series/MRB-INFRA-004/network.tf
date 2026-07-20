resource "azurerm_virtual_network" "mrb_vnet" {
  name                = local.Virtual_Network_name
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  location            = azurerm_resource_group.mrb_main_rg.location
  address_space       = local.virtual_network
  tags                = local.mrb_tags

}

resource "azurerm_subnet" "mrb_subnet" {
  virtual_network_name = azurerm_virtual_network.mrb_vnet.name
  resource_group_name  = azurerm_resource_group.mrb_main_rg.name
  name                 = local.Subnet
  address_prefixes     = local.virtual_subnet

}
resource "azurerm_network_security_group" "mrb_nsg" {
  name                = local.NSG
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  location            = azurerm_resource_group.mrb_main_rg.location


  security_rule {
    name                       = "${local.NSG}-rules"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges     = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "this is an msg for Meridian Bank — Cloud Infrastructure Training Series"
  }

  tags = local.mrb_tags

}

resource "azurerm_subnet_network_security_group_association" "mrb_nsg_asso" {
  network_security_group_id = azurerm_network_security_group.mrb_nsg.id
  subnet_id                 = azurerm_subnet.mrb_subnet.id

}

resource "azurerm_network_interface" "mrb_nic" {
  for_each = var.vm_names

  name = "${local.NIC}${each.key}"
  tags = local.mrb_tags

  ip_configuration {
    name                          = "private-ip_allocation"
    subnet_id                     = azurerm_subnet.mrb_subnet.id
    private_ip_address_allocation = "Dynamic"

  }

  location            = azurerm_resource_group.mrb_main_rg.location
  resource_group_name = azurerm_resource_group.mrb_main_rg.name


}
