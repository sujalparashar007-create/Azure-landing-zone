# Creates subnets and inline NSG associations from network.yaml data flattened
# by yaml-processing. Inputs are shared YAML and retry variables; outputs are
# subnet IDs. Inline NSG ownership prevents later subnet PUTs from detaching
# an NSG that was previously attached by a separate PATCH.
locals {
  subnet_module_subscription_id = {
    for key, subnet in module.yaml_processing.subnets :
    key => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == subnet.subscription_display_name && s.state == "Enabled"
    ])
  }
}

# Creates every subnet from the flattened network.yaml data inside its parent
# VNet. azapi is used because the subnets live in different subscriptions and
# the parent VNet is chosen per resource through parent_id.
resource "azapi_resource" "subnet" {
  for_each = module.yaml_processing.subnets

  depends_on = [azapi_resource.vnet, azapi_resource.nsg]

  retry = var.azapi_retry

  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.subnet_module_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}/providers/Microsoft.Network/virtualNetworks/${each.value.vnet_name}"

  body = {
    properties = merge(
      {
        addressPrefix = each.value.address_prefix
      },
      each.value.delegation != null ? {
        delegations = [{
          name = each.value.delegation
          properties = {
            serviceName = each.value.delegation
          }
        }]
      } : {},
      each.value.private_endpoint_network_policies != null ? {
        privateEndpointNetworkPolicies = each.value.private_endpoint_network_policies
      } : {},
      each.value.nsg != null ? {
        networkSecurityGroup = {
          id = azapi_resource.nsg[each.value.nsg].id
        }
      } : {}
    )
  }
}