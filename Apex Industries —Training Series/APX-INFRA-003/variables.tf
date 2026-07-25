

variable "org_infra" {
    type = object({
      
      # terraform.tfvars
      project_code = string
org_prefix           = string
environment          = string
azure_location       =  string
resource_group_name  = string
storage_account_name = string
group_name           = string
owner_name           = string
    })
  
}

locals {
  
rgname = "${var.org_infra.org_prefix}-${var.org_infra.project_code}-${var.org_infra.environment}"

storagename = replace( lower(local.rgname),"-","")


tags = {
environment = "dev"
owner_name = "sam-rivera"
Manged_by = "terraform"

}
}