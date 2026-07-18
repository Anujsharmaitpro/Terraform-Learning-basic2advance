variable "org_prefix" { type = string }
variable "environment" { type = string }
variable "azure_location" { type = string }
variable "workload" { type = string } # "web" or "api"
variable "resource_group_name" { type = string }
variable "sql_connection_string" { type = string }
variable "app_secret_key" { type = string }
variable "tags" { type = map(string) }