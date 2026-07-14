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
  subscription_id = "64b8e362-61aa-45fb-aef1-420be79135ef"
  client_id       = "2b6814b3-a9f6-4dc6-81e3-ffc464065a38"
  client_secret   = "p_r8Q~YlLyUfKqIux~1aX_toL7ord-eXm~w8Rb59"
  tenant_id       = "18a6ef3e-4273-4c2b-9a4d-7df397096bdd"

}