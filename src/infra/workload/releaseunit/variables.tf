########### Common variables (same for global resources and for release units) ###########

variable "prefix" {
  description = "A prefix used for all resources in this example. Must not contain any special characters. Must not be longer than 10 characters."
  type        = string
  validation {
    condition     = length(var.prefix) >= 5 && length(var.prefix) <= 10
    error_message = "Prefix must be between 5 and 10 characters long."
  }
}

variable "stamps" {
  description = "List of Azure regions into which stamps are deployed. Important: The main location (var.location) MUST be included as the first item in this list."
  type        = list(string)
}

variable "branch" {
  description = "Name of the repository branch used for the deployment. Used as an Azure Resource Tag."
  type        = string
  default     = "not set"
}

variable "queued_by" {
  description = "Name of the user who has queued the pipeline run that has deployed this environment. Used as an Azure Resource Tag."
  type        = string
  default     = "n/a"
}

variable "environment" {
  description = "Environment - int, prod or e2e"
  type        = string
  default     = "int"
}

variable "contact_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = "OVERWRITE@noreply.com"
}

variable "disable_diagnostics" {
  description = "Disable all diagnostic settings (cost saving)"
  type        = bool
  default     = false
}

variable "alerts_enabled" {
  description = "Enable alerts?"
  type        = bool
  default     = false
}

########### Release Unit specific variables ###########

variable "vnet_address_space" {
  description = "Address space used for the VNets. Must be large enough to provide at least of size /20 per stamp!"
  type        = string
}

variable "global_resource_group_name" {
  description = "Name of the resource group which holds the globally shared resources"
  type        = string
}

variable "monitoring_resource_group_name" {
  description = "Name of the resource group which holds the shared monitoring resources"
  type        = string
}

variable "cosmosdb_account_name" {
  description = "Account name of the Cosmos DB"
  type        = string
}

variable "cosmosdb_database_name" {
  description = "Name of the globally shared cosmos db database"
  type        = string
}

variable "azure_monitor_action_group_resource_id" {
  description = "Resource ID of a Azure Monitor action group to send alerts to"
  type        = string
}

variable "frontdoor_resource_id" {
  description = "Front Door Resource ID"
  type        = string
}

variable "frontdoor_name" {
  description = "Front Door Name"
  type        = string
}

variable "frontdoor_id_header" {
  description = "Front Door ID to be used in the header check"
  type        = string
}

variable "acr_name" {
  description = "Azure Container Registry Name (without .azurecr.io)"
  type        = string
}

variable "aks_kubernetes_version" {
  description = "Kubernetes Version"
  type        = string
}

variable "aks_enable_host_encryption" {
  default     = true
  type        = bool
  description = "Enable host encryption for AKS nodes"
}

variable "aks_system_node_pool_sku_size" {
  description = "VM SKU of the AKS system nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_system_node_pool_autoscale_minimum" {
  description = "Minimum number of AKS system nodes for auto-scale settings"
  type        = number
  default     = 3
}

variable "aks_system_node_pool_autoscale_maximum" {
  description = "Maximum number of AKS system nodes for auto-scale settings"
  type        = number
  default     = 9
}

variable "aks_user_node_pool_sku_size" {
  description = "VM SKU of the AKS worker nodes"
  type        = string
  default     = "Standard_F8s_v2"
}

variable "aks_user_node_pool_autoscale_minimum" {
  description = "Minimum number of AKS worker nodes for auto-scale settings"
  type        = number
  default     = 3
}

variable "aks_user_node_pool_autoscale_maximum" {
  description = "Maximum number of AKS worker nodes for auto-scale settings"
  type        = number
  default     = 9
}

variable "event_hub_thoughput_units" {
  description = "Number of Throughput Units for Event Hub Namespace"
  type        = number
  default     = 1
}

variable "event_hub_enable_auto_inflate" {
  description = "Enable auto-inflate of TUs for Event Hub Namespace?"
  type        = bool
  default     = false
}

variable "event_hub_auto_inflate_maximum_tu" {
  description = "Auto-inflate maximum TUs for Event Hub Namespace. Only applies if event_hub_enable_auto_inflate=true"
  type        = number
  default     = 1
}

variable "global_storage_account_name" {
  description = "Name of the globally shared storage account, which is used for image storage"
  type        = string
}

variable "ai_adaptive_sampling" {
  description = "Enable adaptive sampling in Application Insights. Setting this to false means that 100% of the telemetry will be collected."
  type        = bool
  default     = true
}
