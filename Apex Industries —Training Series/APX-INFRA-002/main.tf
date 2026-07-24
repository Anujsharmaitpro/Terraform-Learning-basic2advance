# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------

# Subscription context for RBAC scoping
data "azurerm_subscription" "current" {}

# Primary domain name for UPN construction
# data "azuread_domains" "current" {
#   only_default = true
# }

# Microsoft Graph Service Principal (Fixed Global Client ID)
data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}

# ------------------------------------------------------------------------------
# Component 1 — Custom RBAC Role Definition (AzureRM)
# ------------------------------------------------------------------------------

resource "azurerm_role_definition" "vm_operator" {
  name        = var.custom_role_name
  scope       = data.azurerm_subscription.current.id
  description = "Can start, stop, and restart VMs. Cannot delete, create, or modify networking."

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

# ------------------------------------------------------------------------------
# Component 2 — Dynamic Group Membership (AzureAD)
# ------------------------------------------------------------------------------

resource "azuread_user" "engineer" {
  user_principal_name   = "${var.user_mail_nickname}@${data.azuread_domains.my_dc.domains[0].domain_name}"
  display_name          = var.user_display_name
  mail_nickname         = var.user_mail_nickname
  password              = "ApxTemp@Password2024!"
  force_password_change = true

  department = var.user_department # Must match the dynamic rule condition
}

resource "azuread_group" "engineering_dept" {
  display_name     = var.dynamic_group_name
  security_enabled = true

  types = ["DynamicMembership"]

  dynamic_membership {
    enabled = true
    rule    = "user.department -eq \"${var.user_department}\""
  }
}

# ------------------------------------------------------------------------------
# Component 3 — API Permissions & Admin Consent (AzureAD)
# ------------------------------------------------------------------------------

resource "azuread_application" "reporting_tool" {
  display_name = var.app_display_name

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Fixed MS Graph App ID

    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All Permission ID
      type = "Role"                                 # Application Permission
    }
  }
}

resource "azuread_service_principal" "reporting_tool_sp" {
  client_id = azuread_application.reporting_tool.client_id
}

# Grant Admin Consent for Application Permission
resource "azuread_app_role_assignment" "grant_consent" {
  app_role_id         = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
  principal_object_id = azuread_service_principal.reporting_tool_sp.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}