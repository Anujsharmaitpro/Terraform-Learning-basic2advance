variable "group_name" {
    type = string
  }

variable "user_display_name" {
    type = string
  }

variable "user_mail_nickname" {
   type = string
  }

variable "app_display_name" {
type = string 
}

# variable "org_prefix" {
#   type = string
# }

# variable "project_code" {
#   type = number
#   default = 001
# }


locals {
  
   csv_data  = file("${path.module}/sample_id.csv") 
  ad_name = csvdecode(local.csv_data) 
# testname = format("%s%s%s", substr("hello world", 1, 4))


}


# output "all_out" {
#   value = {
#         # testname  = local.testname
#        name =  nonsensitive(azuread_user.bulk_users[each.value].password)
#       # adname = local.ad_name
         
#          } 
  
# }


output "all_out" {
  value = {
    for k, v in azuread_user.bulk_users : k => {
      upn      = v.user_principal_name
      password = nonsensitive(v.password)
    }
  }
}