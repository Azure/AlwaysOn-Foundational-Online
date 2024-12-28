# Dynamically calculate subnet addresses from the overall address space. Assumes (at least) a /22 address space
# Uses the Hashicopr module "CIDR subnets" https://registry.terraform.io/modules/hashicorp/subnets/cidr/latest
locals {
  netmask = tonumber(split("/", var.vnet_address_space)[1]) # Take the last part from the address space 10.0.0.0/16 => 16
}

module "subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.vnet_address_space
  networks = [
    {
      name     = "kubernetes"
      new_bits = 22 - local.netmask # For AKS we want a /22 sized subnet. So we calculate based on the provided input address space
    }
    # More subnets can be added here and terraform will dynamically calculate their CIDR ranges
  ]
}

# Azure Virtual Network Deployment
resource "azurerm_virtual_network" "stamp" {
  name                = "${local.prefix}-${local.location_short}-vnet"
  resource_group_name = azurerm_resource_group.stamp.name
  location            = azurerm_resource_group.stamp.location
  address_space       = [module.subnet_addrs.base_cidr_block]

  # For production workloads we recommend to enable DDoS protection Standard plan when exposing your AKS ingress on public IPs
  # You can link this to an existing DDoS protection plan or create a new one
  # To enable this, fetch your shared ddos plan resource id and add it as a variable to the terraform definition
  #
  # ddos_protection_plan {
  #   id     = var.ddos_protection_plan_id
  #   enable = true
  # }

  tags = var.default_tags
}

# Default Network Security Group (nsg) definition
# Allows outbound and intra-vnet/cross-subnet communication
resource "azurerm_network_security_group" "default" {
  name                = "${local.prefix}-${local.location_short}-nsg"
  location            = azurerm_resource_group.stamp.location
  resource_group_name = azurerm_resource_group.stamp.name

  # not specifying any security_rules {} will create Azure's default set of NSG rules
  # it allows intra-vnet communication and outbound public internet access

  tags = var.default_tags
}

# Adding an explicit inbound rule for the AKS ingress controller TCP/80 and TCP/443
# This is done as a separate security rule resource to not override the defaults
resource "azurerm_network_security_rule" "allow_inbound_https" {
  name                        = "Allow_Inbound_HTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_public_ip.aks_ingress.ip_address
  resource_group_name         = azurerm_resource_group.stamp.name
  network_security_group_name = azurerm_network_security_group.default.name
}

# Subnet for Kubernetes nodes and pods
resource "azurerm_subnet" "kubernetes" {
  name                 = "kubernetes-snet"
  resource_group_name  = azurerm_resource_group.stamp.name
  virtual_network_name = azurerm_virtual_network.stamp.name
  address_prefixes     = [module.subnet_addrs.network_cidr_blocks["kubernetes"]]
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.AzureCosmosDB",
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry",
    "Microsoft.EventHub"
  ]
}

# NSG - Assign default nsg to kubernetes-snet subnet
resource "azurerm_subnet_network_security_group_association" "kubernetes_default_nsg" {
  subnet_id                 = azurerm_subnet.kubernetes.id
  network_security_group_id = azurerm_network_security_group.default.id
}

####################################### DIAGNOSTIC SETTINGS #######################################

# Use this data source to fetch all available log and metrics categories. We then enable all of them
data "azurerm_monitor_diagnostic_categories" "vnet" {
  resource_id = azurerm_virtual_network.stamp.id
}

resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count = var.disable_diagnostics ? 0 : 1 # disable diagnostics if var.disable_diagnostics=true
  
  name                       = "vnetladiagnostics"
  target_resource_id         = azurerm_virtual_network.stamp.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.stamp.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.vnet.log_category_types

    content {
      category = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.vnet.metrics

    content {
      category = entry.value
      enabled  = true
    }
  }
}
