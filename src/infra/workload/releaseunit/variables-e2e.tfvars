# Variable file for E2E env
vnet_address_space = "10.1.0.0/18" # /18 allows for up to 4 stamps

aks_system_node_pool_sku_size          = "Standard_D2s_v3" # Adjust as needed for your workload
aks_system_node_pool_autoscale_minimum = 2
aks_system_node_pool_autoscale_maximum = 3

aks_user_node_pool_sku_size          = "Standard_F8s_v2" # Adjust as needed for your workload
aks_user_node_pool_autoscale_minimum = 2
aks_user_node_pool_autoscale_maximum = 3

event_hub_thoughput_units     = 1
event_hub_enable_auto_inflate = false

ai_adaptive_sampling = true # enables/disables adaptive sampling for Application Insights; disabled means that 100 % of telemetry will be collected

disable_diagnostics = true