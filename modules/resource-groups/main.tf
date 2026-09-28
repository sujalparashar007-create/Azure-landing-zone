terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
}

# Creates every resource group from the YAML in its own subscription.
# azapi is used because the resource groups live in different subscriptions
# and the subscription is chosen per resource through parent_id.
resource "azapi_resource" "this" {
  for_each = var.resource_groups

  type      = "Microsoft.Resources/resourceGroups@2022-09-01"
  name      = each.value.name
  parent_id = "/subscriptions/${var.subscriptions[each.value.subscription].subscription_id}"
  location  = each.value.location
}