data "azurerm_client_config" "current" {


    
 }

 data "azurerm_key_vault_secret" "vm_admin_username" { 
    key_vault_id = azurerm_key_vault.nct_kv.id
    name = "vm-admin-username"
    depends_on   = [azurerm_key_vault_secret.key_secret1]
 }

 

data "azurerm_key_vault_secret" "vm_admin_password" { 
key_vault_id = azurerm_key_vault.nct_kv.id
    name = "vm-admin-password"
    depends_on   = [azurerm_key_vault_secret.key_secret2]

}


data "azurerm_key_vault_secret" "allowed_ssh_ip"    { 
    key_vault_id = azurerm_key_vault.nct_kv.id
    name = "allowed-ssh-ip"
    depends_on   = [azurerm_key_vault_secret.key_secret3]
}