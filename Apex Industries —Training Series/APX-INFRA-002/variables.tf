variable "custom_role_name" {
  type        = string
  description = "Name of the custom Azure RBAC role"
}

variable "dynamic_group_name" {
  type        = string
  description = "Name of the dynamic Entra ID group"
}

variable "app_display_name" {
  type        = string
  description = "Name of the App Registration"
}

variable "user_department" {
  type        = string
  description = "Department attribute for user filtering"

  validation {
    condition     = contains(["Engineering", "Sales", "Finance", "Operations"], var.user_department)
    error_message = "user_department must be one of: Engineering, Sales, Finance, Operations."
  }
}

variable "user_mail_nickname" {
  type        = string
  description = "Mail nickname for the engineer account"
}

variable "user_display_name" {
  type        = string
  description = "Display name for the engineer account"
}