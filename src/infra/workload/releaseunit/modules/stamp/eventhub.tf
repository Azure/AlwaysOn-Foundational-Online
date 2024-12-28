resource "azurerm_eventhub_namespace" "stamp" {
  name                 = "${local.prefix}-${local.location_short}-evhns"
  location             = azurerm_resource_group.stamp.location
  resource_group_name  = azurerm_resource_group.stamp.name
  sku                  = "Standard"
  zone_redundant       = true
  capacity             = var.event_hub_thoughput_units
  auto_inflate_enabled = var.event_hub_enable_auto_inflate

  # If auto-inflate is enabled, we need to set the max scale out TUs
  maximum_throughput_units = var.event_hub_enable_auto_inflate ? var.event_hub_auto_inflate_maximum_tu : null

  tags = var.default_tags
}

resource "azurerm_eventhub" "backendqueue" {
  name                = "backendqueue-eh"
  namespace_name      = azurerm_eventhub_namespace.stamp.name
  resource_group_name = azurerm_resource_group.stamp.name

  partition_count   = 32
  message_retention = 7
}

resource "azurerm_eventhub_consumer_group" "backendworker" {
  name                = "backendworker-cs"
  namespace_name      = azurerm_eventhub_namespace.stamp.name
  eventhub_name       = azurerm_eventhub.backendqueue.name
  resource_group_name = azurerm_resource_group.stamp.name
}

####################################### DIAGNOSTIC SETTINGS #######################################

# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "eventhub" {
  resource_id = azurerm_eventhub_namespace.stamp.id
}

resource "azurerm_monitor_diagnostic_setting" "eventhub" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true
  
  name                       = "eventhubladiagnostics"
  target_resource_id         = azurerm_eventhub_namespace.stamp.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.eventhub.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.eventhub.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}