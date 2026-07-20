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
    app_service_name =string

  })

}


locals {

  fname                = "${var.mrb_infra.org_prefix}-${var.mrb_infra.environment}"
  mrb_rgname           = "${var.mrb_infra.org_prefix}-${var.mrb_infra.environment}-003-rg"
  key_vault            = "${local.fname}-003-kv"
  Virtual_Network_name = "${local.fname}-003-vnet"
  Subnet               = "${local.fname}-003-subnet"
  NSG                  = "${local.fname}-003-nsg"
  Public_IP            = "${local.fname}-003-pip"
  NIC                  = "${local.fname}-003-nic"
  Virtual_Machine      = "${local.fname}-003-vm"
App_Service  = "${local.fname}-003-web"
App_Service_Plan =	"${local.fname}-plan"

  mrb_tags = {

    Project            = "MRB-INFRA-003"
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