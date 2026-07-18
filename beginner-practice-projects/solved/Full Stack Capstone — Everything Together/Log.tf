

resource "azurerm_log_analytics_workspace" "nct_logs_space" {
  resource_group_name = azurerm_resource_group.nct_main_rg.name
  location            = azurerm_resource_group.nct_main_rg.location
  name                = "${local.org_fname}-010-law"
  tags                = local.nct_tags
}

resource "azurerm_monitor_action_group" "nci_action_gp" {
  resource_group_name = azurerm_resource_group.nct_main_rg.name
  location            = azurerm_resource_group.nct_main_rg.location
  name                = "${local.org_fname}-010-ag"
  short_name          = "p0action"
 tags     = local.nct_tags
  dynamic "email_receiver" {
    for_each = local.alert_email_receivers
    content {

      name          = email_receiver.key
      email_address = email_receiver.value
    }
  }
}


resource "azurerm_monitor_diagnostic_setting" "nct_dia_web" {
  target_resource_id = module.web_app.app_service_id
  name = "${module.web_app.app_service_name}-diag"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.nct_logs_space.id

  # enabled_log {
  #   category = "AuditEvent"
  # }

metric {
  category = "AllMetrics"
}
}


resource "azurerm_monitor_diagnostic_setting" "nct_dia_api" {
  target_resource_id = module.api_app.app_service_id
  name = "${module.api_app.app_service_name}-diag"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.nct_logs_space.id

  # enabled_log {
  #   category = "AuditEvent"
  # }

metric {
  category = "AllMetrics"
}

}


resource "azurerm_monitor_metric_alert" "nct_alerts" {
  # FIX: Ensure this exact line is present at the top of the resource
  for_each            = local.metric_alerts
  
  resource_group_name = azurerm_resource_group.nct_main_rg.name
  name                = "${local.org_fname}-${each.key}"
  scopes              = [each.value.scope] 
  tags                = local.nct_tags
  severity            = each.value.severity
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = each.value.metric_name
    aggregation      = each.value.aggregation
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.nci_action_gp.id
  }
}