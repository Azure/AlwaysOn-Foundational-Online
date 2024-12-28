# This "public" storage account is being used for the static website hosting
resource "azurerm_storage_account" "public" {
  name                     = "${local.prefix}${local.location_short}pubst"
  resource_group_name      = azurerm_resource_group.stamp.name
  location                 = azurerm_resource_group.stamp.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  min_tls_version          = "TLS1_2"

  # Enable static website hosting. We will use that to host our UI app
  static_website {
    index_document = "index.html"
  }

  tags = var.default_tags
}

# This "private" storage account is being used for stamp-internal matters such as the health service blob storage
resource "azurerm_storage_account" "private" {
  name                     = "${local.prefix}${local.location_short}prist"
  resource_group_name      = azurerm_resource_group.stamp.name
  location                 = azurerm_resource_group.stamp.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  min_tls_version          = "TLS1_2"

  network_rules {
    default_action = "Allow"
    bypass         = ["Metrics", "Logging"]
    ip_rules       = []
  }

  tags = var.default_tags
}

# Storage container for the checkpoints of the Event Hub processors
resource "azurerm_storage_container" "deployment_eventhub_checkpoints" {
  name                  = "ehcheckpoints"
  storage_account_name  = azurerm_storage_account.private.name
  container_access_type = "private"
}

# Storage container for the healthservice
resource "azurerm_storage_container" "deployment_healthservice" {
  name                  = "healthservice"
  storage_account_name  = azurerm_storage_account.private.name
  container_access_type = "private"
}

# Create empty file which serves as the healthservice state file
resource "azurerm_storage_blob" "healthservice_state_blob" {
  name                   = local.health_blob_name
  storage_account_name   = azurerm_storage_account.private.name
  storage_container_name = azurerm_storage_container.deployment_healthservice.name
  type                   = "Block"
  source_content         = ""
}

# Poison Messages Table for the BackgroundProcessor to store errored messages
resource "azurerm_storage_table" "poison_messages" {
  name                 = "backgroundProcessorPoisonMessages"
  storage_account_name = azurerm_storage_account.private.name
}

####################################### PUBLIC STORAGE DIAGNOSTIC SETTINGS #######################################

# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "storage_public" {
  resource_id = azurerm_storage_account.public.id
}

resource "azurerm_monitor_diagnostic_setting" "storage_public" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true
  
  name                       = "storageladiagnostics"
  target_resource_id         = azurerm_storage_account.public.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_public.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_public.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "storage_public_blob" {
  resource_id = "${azurerm_storage_account.public.id}/blobServices/default/"
}

resource "azurerm_monitor_diagnostic_setting" "storage_public_blob" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true

  name                       = "storageblobladiagnostics"
  target_resource_id         = "${azurerm_storage_account.public.id}/blobServices/default/"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_public_blob.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_public_blob.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}

####################################### PRIVATE STORAGE DIAGNOSTIC SETTINGS #######################################

# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "storage_private" {
  resource_id = azurerm_storage_account.private.id
}

resource "azurerm_monitor_diagnostic_setting" "storage_private" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true

  name                       = "storageladiagnostics"
  target_resource_id         = azurerm_storage_account.private.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_private.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_private.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "storage_private_blob" {
  resource_id = "${azurerm_storage_account.private.id}/blobServices/default/"
}

resource "azurerm_monitor_diagnostic_setting" "storage_private_blob" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true

  name                       = "storageblobladiagnostics"
  target_resource_id         = "${azurerm_storage_account.private.id}/blobServices/default/"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_private_blob.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.storage_private_blob.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}