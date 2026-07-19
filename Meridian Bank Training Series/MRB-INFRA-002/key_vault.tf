resource "azurerm_key_vault" "mrb_vault" {
  sku_name = "standard"
  location = azurerm_resource_group.mrb_main_rg.location
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  name = local.key_vault
   tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 14
  purge_protection_enabled    = false
enable_rbac_authorization = true
tags = local.mrb_tags

network_acls {
  default_action = "Allow"
  bypass = "AzureServices"
}
   
}

resource "azurerm_role_assignment" "kv_role" {
  
principal_id = data.azurerm_client_config.current.object_id
scope = azurerm_key_vault.mrb_vault.id
role_definition_name = "Key Vault Secrets Officer"

}

resource "azurerm_key_vault_secret" "vm_password" {
  name         = "vm-admin-password"
  value        = "Gr3@t$un!ght99"
  key_vault_id = azurerm_key_vault.mrb_vault.id

  depends_on = [azurerm_role_assignment.kv_role]
}


resource "azurerm_linux_virtual_machine" "mrb_vm" {
  name = local.Virtual_Machine
  location =azurerm_resource_group.mrb_main_rg.location
  resource_group_name = azurerm_resource_group.mrb_main_rg.name
  tags = local.mrb_tags
  size = var.mrb_infra.vm_size 
network_interface_ids = [azurerm_network_interface.mrb_nic.id]
admin_username = var.mrb_infra.admin_username



disable_password_authentication = true
os_disk {
  storage_account_type = "Standard_LRS"
  caching = "ReadWrite"
}

identity {
  type = "SystemAssigned"
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
custom_data = base64encode(<<-EOF
    #!/bin/bash
    # 1. Update packages and install Nginx
    apt-get update
    apt-get install -y nginx

    # 2. Capture the VM hostname and the local private IP address
    VM_NAME=$(hostname)
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    # 3. Create the webpage incorporating the name and local IP variables
    cat <<HTML > /var/www/html/index.html
    <html>
      <head>
        <title>NCT Web Server</title>
      </head>
      <body style="font-family: Arial, sans-serif; margin: 40px;">
        <h1>Hello World! Your Ubuntu 22.04 web server is live via Terraform.</h1>
        <hr>
        <p><strong>Server Name (Hostname):</strong> $VM_NAME</p>
        <p><strong>Local (Private) IP:</strong> $LOCAL_IP</p>
      </body>
    </html>
    HTML

    # 4. Ensure Nginx starts and is running
    systemctl enable nginx
    systemctl restart nginx
  EOF
  )

}

resource "azurerm_role_assignment" "vm_kv_access" {
  scope                = azurerm_key_vault.mrb_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id          = azurerm_linux_virtual_machine.mrb_vm.identity[0].principal_id
}
