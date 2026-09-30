module "yaml_processing" {
  source = "../yaml-processing"

  yaml_file = coalesce(var.yaml_file, "${path.module}/../yaml-processing/config/azure.yaml")
}

# Resolve each YAML subscription (keyed by name) to its live Azure
# subscription ID. The subscriptions are created by the management-groups
# module (separate state), so we look them up here by display name.
# `one()` makes the lookup deterministic: it errors on duplicate display
# names and returns null when there is no match (validated below).
data "azurerm_subscriptions" "available" {}

locals {
  subscription_ids = {
    for name, sub in module.yaml_processing.subscriptions :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == sub.display_name
    ])
  }
}

check "subscriptions_resolvable" {
  assert {
    condition = alltrue([
      for name, id in local.subscription_ids : id != null
    ])
    error_message = "Unable to resolve every YAML subscription to an Azure subscription by display name. Verify the subscriptions exist and their display names are unique."
  }
}

# Creates every resource group from the YAML in its own subscription.
# azapi is used because the resource groups live in different subscriptions
# and the subscription is chosen per resource through parent_id.
resource "azapi_resource" "this" {
  for_each = module.yaml_processing.resource_groups

  type      = "Microsoft.Resources/resourceGroups@2022-09-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.subscription_ids[each.value.subscription]}"
  location  = each.value.location
}
