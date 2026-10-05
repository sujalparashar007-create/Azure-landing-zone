module "yaml_processing" {
  source = "../yaml-processing"

  yaml_file         = coalesce(var.yaml_file, "${path.module}/../yaml-processing/config/azure.yaml")
  network_yaml_file = coalesce(var.network_yaml_file, "${path.module}/../yaml-processing/config/network.yaml")
}

# Minimal provider-side lookup: translate the already-resolved subscription
# display_name into its Azure subscription ID. The reference resolution
# (subscription_ref -> subscription -> display_name) is performed by the
# yaml-processing module; this data source only maps the resolved value to
# its Azure ID.
data "azurerm_subscriptions" "available" {}

locals {
  subscription_id = {
    for key, subnet in module.yaml_processing.subnets :
    key => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == subnet.subscription_display_name && s.state == "Enabled"
    ])
  }
}

check "subscriptions_resolvable" {
  assert {
    condition = alltrue([
      for key, id in local.subscription_id : id != null
    ])
    error_message = "Unable to resolve the referenced subscription display name to an Azure subscription ID. Verify the subscriptions exist and their display names are unique."
  }
}

# Creates every subnet from the flattened network.yaml data inside its parent
# VNet. azapi is used because the subnets live in different subscriptions and
# the parent VNet is chosen per resource through parent_id.
resource "azapi_resource" "this" {
  for_each = module.yaml_processing.subnets

  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.subscription_id[each.key]}/resourceGroups/${each.value.resource_group}/providers/Microsoft.Network/virtualNetworks/${each.value.vnet_name}"

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
      } : {}
    )
  }
}