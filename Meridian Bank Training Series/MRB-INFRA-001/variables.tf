variable "mrb_infra" {
  type = object({

    org_prefix           = string
    environment          = string
    azure_location       = string
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    owner_name           = string
    cost_centre          = string
    data_classification  = string
    compliance_scope     = string
    soft_delete_days     = number

  })

}


locals {


  mrb_name = "${var.mrb_infra.org_prefix}-${var.mrb_infra.environment}"

  mrb_tags = {

    Project            = "MRB-INFRA-001"
    Environment        = var.mrb_infra.environment
    Owner              = var.mrb_infra.owner_name
    ManagedBy          = "terraform"
    CostCentre         = var.mrb_infra.cost_centre
    Team               = "cloud-platform"
    DataClassification = var.mrb_infra.data_classification
    ComplianceScope    = var.mrb_infra.compliance_scope

  }



}