

locals {
  org-prefix = "${var.main_config.org_prefix}-${var.main_config.environment}-secrets"
  location   = "South India"

  tags = {
    ProjectNCT = "INFRA-004"
    Owner      = "jane-doe"
    ManagedBy  = "terraform"
    CostCentre = "CC-DEVOPS-007"
    Team       = "platform-engineering"
  }

}

variable "main_config" {
  type = object({
    org_prefix          = string
    environment         = string
    azure_location      = string
    vm_size             = string
    key_vault_name      = string
    resource_group_name = string
    owner_name          = string
    cost_centre         = string
    app_service_name    = string
  })

}