resource "azurerm_key_vault" "stamp" {
  name                = "${local.prefix}-${local.location_short}-kv"
  location            = azurerm_resource_group.stamp.location
  resource_group_name = azurerm_resource_group.stamp.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  tags = var.default_tags
}

# Give KV secret permissions to the service principal that runs the Terraform apply itself
resource "azurerm_key_vault_access_policy" "devops_pipeline_all" {
  key_vault_id = azurerm_key_vault.stamp.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Delete", "Purge", "Set", "Backup", "Restore", "Recover"
  ]
}

# Give KV secret read permissions to the healthservice for CSI driver access
resource "azurerm_key_vault_access_policy" "healthservice" {
  key_vault_id = azurerm_key_vault.stamp.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.healthservice.principal_id

  secret_permissions = [
    "Get", "List"
  ]
}

# Give KV secret read permissions to the catalogservice for CSI driver access
resource "azurerm_key_vault_access_policy" "catalogservice" {
  key_vault_id = azurerm_key_vault.stamp.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.catalogservice.principal_id

  secret_permissions = [
    "Get", "List"
  ]
}

# Give KV secret read permissions to the backgroundprocessor for CSI driver access
resource "azurerm_key_vault_access_policy" "backgroundprocessor" {
  key_vault_id = azurerm_key_vault.stamp.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.backgroundprocessor.principal_id

  secret_permissions = [
    "Get", "List"
  ]
}

####################################### DIAGNOSTIC SETTINGS #######################################

# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "kv" {
  resource_id = azurerm_key_vault.stamp.id
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true
  
  name                       = "kvladiagnostics"
  target_resource_id         = azurerm_key_vault.stamp.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.kv.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.kv.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}
