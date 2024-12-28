# https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html
resource "azurerm_kubernetes_cluster" "stamp" {
  name                = "${local.prefix}-${local.location_short}-aks"
  location            = azurerm_resource_group.stamp.location
  resource_group_name = azurerm_resource_group.stamp.name
  dns_prefix          = "${local.prefix}${var.location}aks"
  kubernetes_version  = var.aks_kubernetes_version
  node_resource_group = "MC_${local.prefix}-stamp-${var.location}-aks-rg" # we manually specify the naming of the managed resource group to have it controlled and consistent
  sku_tier            = "Standard"                                        # Opt-in for AKS Uptime SLA

  automatic_channel_upgrade = "node-image"

  monitor_metrics {}

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 1, 2]
    }
  }

  role_based_access_control_enabled = true

  default_node_pool {
    name                 = "systempool"
    vm_size              = var.aks_system_node_pool_sku_size
    enable_auto_scaling  = true
    min_count            = var.aks_system_node_pool_autoscale_minimum
    max_count            = var.aks_system_node_pool_autoscale_maximum
    vnet_subnet_id       = azurerm_subnet.kubernetes.id
    os_disk_type         = "Ephemeral"
    os_disk_size_gb      = 30
    orchestrator_version = var.aks_kubernetes_version

    zones = [1, 2, 3]

    upgrade_settings {
      max_surge = "33%"
    }

    tags = var.default_tags
  }

  network_profile {
    network_plugin = "azure"
    network_mode   = "transparent"
    network_policy = "calico"
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable the Azure Policy Addon for AKS
  azure_policy_enabled = true

  # Enable and configure the Azure Monitor (container insights) addon for AKS
  oms_agent {
    log_analytics_workspace_id      = data.azurerm_log_analytics_workspace.stamp.id
    msi_auth_for_monitoring_enabled = true
  }

  # Enable and configure the Azure KeyVault Secrets Provider addon for AKS
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "5m"
  }

  depends_on = [
    azurerm_public_ip.aks_ingress
  ]

  tags = var.default_tags
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workloadpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.stamp.id
  vm_size               = var.aks_user_node_pool_sku_size
  enable_auto_scaling   = true
  min_count             = var.aks_user_node_pool_autoscale_minimum
  max_count             = var.aks_user_node_pool_autoscale_maximum
  vnet_subnet_id        = azurerm_subnet.kubernetes.id
  os_disk_type          = "Ephemeral"
  orchestrator_version  = var.aks_kubernetes_version

  enable_host_encryption = var.aks_enable_host_encryption # host encryption needs to be enabled per-subscription

  mode  = "User" # Define this node pool as a "user" aka workload node pool
  zones = [1, 2, 3]

  upgrade_settings {
    max_surge = "33%"
  }

  node_labels = {
    "role" = "workload"
  }

  node_taints = [              # this prevents pods from accidentially being scheduled on the workload node pool
    "workload=true:NoSchedule" # each pod / deployments needs a toleration for this taint
  ]

  tags = var.default_tags
}

####################################### DIAGNOSTIC SETTINGS #######################################

# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "aks" {
  resource_id = azurerm_kubernetes_cluster.stamp.id
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true

  name                       = "aksladiagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.stamp.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.aks.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.aks.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}
