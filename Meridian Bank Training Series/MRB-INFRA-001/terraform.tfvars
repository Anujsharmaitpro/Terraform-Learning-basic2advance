

mrb_infra = {

  # terraform.tfvars

  org_prefix           = "mrb"
  environment          = "dev"
  azure_location       = "south india"
  resource_group_name  = "mrb-dev-auditlogs-rg"
  storage_account_name = "mrbdevauditlogssa"
  container_name       = "audit-logs"
  owner_name           = "alex-morgan"
  cost_centre          = "CC-CLOUD-001"
  data_classification  = "internal"
  compliance_scope     = "internal-audit"
  soft_delete_days     = 14

}