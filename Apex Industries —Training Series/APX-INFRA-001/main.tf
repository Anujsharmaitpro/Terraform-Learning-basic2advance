resource "azuread_user" "user_1" {
user_principal_name = "${var.user_mail_nickname}@${data.azuread_domains.my_dc.domains[0].domain_name}"
display_name = var.user_display_name
force_password_change = true
password = "P@ssw0rod@1"
employee_id = "xxxxxxxx"
employee_type = "FULL TIME"
job_title = "Hybird-infra-system-admin"
mobile_phone = "xxxxxxxxxx"
department = "IT INFRA"

}


resource "azuread_group" "engineers" {
  display_name     = var.group_name
  security_enabled = true

  members = [
    azuread_user.user_1.object_id
  ]
}


resource "azuread_application" "internal_tool" {
  display_name = var.app_display_name
  
}

resource "azuread_service_principal" "internal_tool_sp" {
  client_id = azuread_application.internal_tool.client_id
}



resource "azuread_user" "bulk_users" {

  for_each = {for adusers in local.ad_name : adusers.first_name => adusers}


  user_principal_name ="${each.value.upn_prefix}@${data.azuread_domains.my_dc.domains[0].domain_name}"
  display_name = "${each.value.first_name}.${each.value.last_name}"
  mail_nickname = each.value.mail_nickname
  job_title = each.value.job_title
password = format("%s%s2026!#",upper(substr(each.value.first_name, 0, 3)),lower(substr(each.value.last_name, 0, 3)))
  force_password_change = true
}


output "all_out2" {
  value     = azuread_user.bulk_users
  sensitive = true
}
