locals {
  netmask = tonumber(split("/", var.vnet_address_space)[1]) # Take the last part from the address space 10.0.0.0/16 => 16
}

# Dynamically calculate addresse ranges from the overall address space. Each stamp gets a /20 sized range
# So the input range must be large enough to provide enough /20 subnets per desired stamp
# Uses the Hashicopr module "CIDR subnets" https://registry.terraform.io/modules/hashicorp/subnets/cidr/latest
module "stamp_addresses" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.vnet_address_space
  networks = [for stamp in var.stamps : {
    name     = stamp
    new_bits = 20 - local.netmask # Each stamp needs at least a /20 sized subnet. So we calculate based on the provided input address space
  }]
}

module "stamp" {
  for_each = toset(var.stamps) # for each needs a set, cannot work with a list
  source   = "./modules/stamp"

  location = each.value

  vnet_address_space = module.stamp_addresses.network_cidr_blocks[each.value]

  prefix       = local.prefix       # handing over the resource prefix
  default_tags = local.default_tags # handing over the resource tags
  queued_by    = var.queued_by

  global_resource_group_name     = var.global_resource_group_name
  monitoring_resource_group_name = var.monitoring_resource_group_name
  cosmosdb_account_name          = var.cosmosdb_account_name
  cosmosdb_database_name         = var.cosmosdb_database_name
  global_storage_account_name    = var.global_storage_account_name

  azure_monitor_action_group_resource_id = var.azure_monitor_action_group_resource_id
  frontdoor_id_header                    = var.frontdoor_id_header
  acr_name                               = var.acr_name

  aks_kubernetes_version = var.aks_kubernetes_version # Defined kubernetes version

  aks_enable_host_encryption  = var.aks_enable_host_encryption # Enable host encryption

  aks_system_node_pool_sku_size          = var.aks_system_node_pool_sku_size
  aks_system_node_pool_autoscale_minimum = var.aks_system_node_pool_autoscale_minimum
  aks_system_node_pool_autoscale_maximum = var.aks_system_node_pool_autoscale_maximum

  aks_user_node_pool_sku_size          = var.aks_user_node_pool_sku_size
  aks_user_node_pool_autoscale_minimum = var.aks_user_node_pool_autoscale_minimum
  aks_user_node_pool_autoscale_maximum = var.aks_user_node_pool_autoscale_maximum


  event_hub_thoughput_units         = var.event_hub_thoughput_units
  event_hub_enable_auto_inflate     = var.event_hub_enable_auto_inflate
  event_hub_auto_inflate_maximum_tu = var.event_hub_auto_inflate_maximum_tu

  alerts_enabled       = var.alerts_enabled
  api_key              = random_password.api_key.result
  ai_adaptive_sampling = var.ai_adaptive_sampling

  disable_diagnostics = var.disable_diagnostics
}
