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
    for name, vnet in module.yaml_processing.vnets :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == vnet.subscription_display_name && s.state == "Enabled"
    ])
  }
}

check "subscriptions_resolvable" {
  assert {
    condition = alltrue([
      for name, id in local.subscription_id : id != null
    ])
    error_message = "Unable to resolve the referenced subscription display name to an Azure subscription ID. Verify the subscriptions exist and their display names are unique."
  }
}

# Creates every Virtual Network from the resolved network.yaml data in its
# own subscription/resource group. azapi is used because the VNets live in
# different subscriptions and the subscription is chosen per resource through
# parent_id.
resource "azapi_resource" "this" {
  for_each = module.yaml_processing.vnets

  type      = "Microsoft.Network/virtualNetworks@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = each.value.address_space
      }
    }
  }
}
