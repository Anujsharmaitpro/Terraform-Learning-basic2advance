

data "azurerm_client_config" "current" {
}



variable "core_config" {
  type = object({
    org_prefix          = string
    environment         = string
    azure_location      = string
    resource_group_name = string
    key_vault_name      = string
    sql_server_name     = string
    sql_database_name   = string
    owner_name          = string
    cost_centre         = string
    law_retention_days  = number
  })


  validation {
    condition     = contains(["dev", "stg", "prod"], var.core_config.environment)
    error_message = "environment must be exactly one of: dev, stg, prod."
  }
}


locals {

  sql_connection_string = "Server=tcp:${var.core_config.sql_server_name}.database.windows.net,1433;Database=${var.core_config.sql_database_name};User ID=${azurerm_key_vault_secret.nct_username.value};Password=${azurerm_key_vault_secret.nct_password.value};Encrypt=True;"
  org_fname             = "${var.core_config.org_prefix}-${var.core_config.environment}"

  nct_tags = {
    Project     = "NCT-INFRA-010"
    Environment = var.core_config.environment
    Owner       = var.core_config.owner_name
    ManagedBy   = "terraform"
    CostCentre  = var.core_config.cost_centre
    Team        = "platform-engineering"

  }


  sql_firewall_rules = [
    { "devlaptop" = "205.254.171.88" },
    { "cicdagent" = "20.30.40.50" },

  ]


  alert_email_receivers = {
    "tech-lead"     = "priya.menon@nexacore.com"
    "junior-devops" = "jane.doe@nexacore.com"
  }


metric_alerts = {
  "web-cpu-high" = {
    description = "Web App CPU exceeded 80 percent"
    severity    = 2
    metric_name = "CpuTime"
    operator    = "GreaterThan"
    threshold   = 80
    aggregation = "Total"
   scope       = module.web_app.app_service_id
  }
  "api-cpu-high" = {
    description = "API App CPU exceeded 80 percent"
    severity    = 2
    metric_name = "CpuTime"
    operator    = "GreaterThan"
    threshold   = 80
    aggregation = "Total"
    scope       = module.api_app.app_service_id
  }
}


scopes = [
  module.web_app.app_service_id,
  module.api_app.app_service_id
]

}


# variable "environment" {
#   description = "Deployment environment"
#   type        = string

#   validation {
#     condition     = contains(["dev", "stg", "prod"], var.environment)
#     error_message = "environment must be exactly one of: dev, stg, prod."
#   }
# }



