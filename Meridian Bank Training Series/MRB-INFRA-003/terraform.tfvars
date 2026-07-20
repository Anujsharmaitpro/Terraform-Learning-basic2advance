

mrb_infra = {

  # terraform.tfvars

  org_prefix          = "mrb"
  environment         = "dev"
  azure_location      = "south india"
  resource_group_name = "mrb-dev-auditlogs-rg"
  owner_name          = "alex-morgan"
  cost_centre         = "CC-CLOUD-001"
  data_classification = "internal"
  compliance_scope    = "internal-audit"
  vm_size             = "Standard_B2als_v2"
  admin_username      = "mrbadmin"
  allowed_ssh_ip      = "205.254.171.14"
app_service_name     = "mrb-dev-003-web-jd"
}