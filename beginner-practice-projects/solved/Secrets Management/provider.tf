terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }
  }

  required_version = ">= 1.15.6"
}

provider "azurerm" {
  features {

key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = "xxxxxxxxxxxxxxxxxxxx"
  client_id       = "xxxxxxxxxxxxxxxxxxxxxx"
  client_secret   = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
  tenant_id       = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

}
