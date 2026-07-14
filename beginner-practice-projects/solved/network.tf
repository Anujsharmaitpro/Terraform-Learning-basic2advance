

resource "azurerm_virtual_network" "msvan-vnet" {
  name                = "${var.main_config.org_prefix}-${var.main_config.environment}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main_rg.location
  resource_group_name = azurerm_resource_group.main_rg.name


}

resource "azurerm_subnet" "msvan_subnet" {
  name                 = "${var.main_config.org_prefix}-${var.main_config.environment}-subnet"
  resource_group_name  = azurerm_resource_group.main_rg.name
  virtual_network_name = azurerm_virtual_network.msvan-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "l_nic" {
 
  name                = "${var.main_config.org_prefix}-${var.main_config.environment}-nic"
  location            = azurerm_resource_group.main_rg.location
  resource_group_name = azurerm_resource_group.main_rg.name


  ip_configuration {
    name                          = "${var.main_config.org_prefix}-${var.main_config.environment}-internal"
    subnet_id                     = azurerm_subnet.msvan_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my-publicip.id
  }
}


resource "azurerm_network_security_group" "msvan-nsg" {
 
  name                = "Nsg-${var.main_config.org_prefix}-${var.main_config.environment}"
  location            = azurerm_resource_group.main_rg.location
  resource_group_name = azurerm_resource_group.main_rg.name

  security_rule {
    name                       = "Alow_port"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22","80","443"]
    source_address_prefix      = data.azurerm_key_vault_secret.allowed_ssh_ip.value
    destination_address_prefix = "*"
  }

depends_on = [ azurerm_key_vault_secret.key_secret3 ]
}

# # resource "azurerm_network_interface_security_group_association" "name" {
# #     network_interface_id =  "azurerm_network_interface.l_nic"
# #   network_security_group_id ="azurerm_network_security_group.msvan-nsg"

# }


resource "azurerm_network_interface_security_group_association" "nsg-link" {
  
  network_interface_id      = azurerm_network_interface.l_nic.id
  network_security_group_id = azurerm_network_security_group.msvan-nsg.id
}


resource "azurerm_public_ip" "my-publicip" {
    name                 = "msvan-PublicIp1${var.main_config.org_prefix}-${var.main_config.environment}"
  resource_group_name  = azurerm_resource_group.main_rg.name
  location             = azurerm_resource_group.main_rg.location
  allocation_method    = "Static"
  ddos_protection_mode = "Disabled"
  sku                  = "Standard"

}



# resource "azuread_user" "my_user" {
#   for_each = {  for rashmi in local.user-data :rashmi.first_name =>rashmi}
#   user_principal_name =lower(format("%s@%s",each.value.first_name,local.dcname))
#   display_name = lower("${each.value.first_name}.${each.value.last_name}")
#   password = random_password.password.result
#   department = each.value.department
#  job_title = each.value.job_title
# employee_type = "Consultant"
# force_password_change = true
# disable_password_expiration = true
# company_name = "msvan"
# country = "india"
  
# }

# resource "random_password" "password" {
#   length           = 16
#   special          = true
#   override_special = "!#$%&*()-_=+[]{}<>:?"
# }