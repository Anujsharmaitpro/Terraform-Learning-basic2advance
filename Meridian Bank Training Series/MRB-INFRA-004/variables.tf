variable "mrb_infra" {
  type = object({

    org_prefix          = string
    environment         = string
    azure_location      = string
    resource_group_name = string
    admin_username      = string
    vm_size             = string
    owner_name          = string
    cost_centre         = string
    data_classification = string
    compliance_scope    = string
    allowed_ssh_ip      = string
    app_service_name    = string

  })

}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

variable "code_suffix" {
  type    = string
  default = "004"
}

locals {

  fname                = "${var.mrb_infra.org_prefix}-${var.mrb_infra.environment}"
  mrb_rgname           = "${var.mrb_infra.org_prefix}-${var.mrb_infra.environment}-${var.code_suffix}-rg"
  key_vault            = "${local.fname}-${var.code_suffix}-kv"
  Virtual_Network_name = "${local.fname}-${var.code_suffix}-vnet"
  Subnet               = "${local.fname}-${var.code_suffix}-subnet"
  NSG                  = "${local.fname}-${var.code_suffix}-nsg"
  Public_IP            = "${local.fname}-${var.code_suffix}-pip"
  NIC                  = "${local.fname}-${var.code_suffix}-nic"
  Virtual_Machine      = "${local.fname}-${var.code_suffix}"
  App_Service          = "${local.fname}-${var.code_suffix}"
  App_Service_Plan     = "${local.fname}-${var.code_suffix}-plan"

  Load_Balancer = "${local.fname}-${var.code_suffix}-lb"
  LB_Public_IP  = "${local.fname}-${var.code_suffix}-pip"
  Backend_Pool  = "${local.fname}-${var.code_suffix}-pool"
  Health_Probe  = "${local.fname}-${var.code_suffix}-probe"
  LB_Rule       = "${local.fname}-${var.code_suffix}-rule"





  mrb_tags = {

    Project            = "MRB-INFRA-004"
    Environment        = var.mrb_infra.environment
    Owner              = var.mrb_infra.owner_name
    ManagedBy          = "terraform"
    CostCentre         = var.mrb_infra.cost_centre
    Team               = "cloud-platform"
    DataClassification = var.mrb_infra.data_classification
    ComplianceScope    = var.mrb_infra.compliance_scope

  }

  virtual_network = ["10.0.0.0/16"]
  virtual_subnet  = ["10.0.1.0/24"]


}


variable "vm_names" {
  type    = set(string)
  default = ["vm1", "vm2"]

}