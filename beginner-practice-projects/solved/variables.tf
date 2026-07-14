# variable "org-prefix" {
#   type    = string
  
# }

variable "environment" {
  type = string

  description = "we need to enter the envname"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "pls select correct env "
  }

}

locals {
  org-prefix = "${var.main_config.org_prefix}-${var.main_config.environment}-secrets"
  location   = "South India"

tags ={
    ProjectNCT = "INFRA-004"
        Owner = "jane-doe"
    ManagedBy = "terraform"
CostCentre =  "CC-DEVOPS-007"
Team = "platform-engineering"
}

}

variable "main_config" {
    type = object({
  org_prefix = string
  environment= string
  azure_location = string
  vm_size = string
  key_vault_name  = string
  resource_group_name = string
owner_name =  string
cost_centre = string
 })
  
}