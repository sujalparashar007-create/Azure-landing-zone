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

  user_principal_names = toset([
    for assignment in module.yaml_processing.iam_assignments : assignment.principal
  ])

  role_names = toset([
    for assignment in module.yaml_processing.iam_assignments : assignment.role
  ])

  scope_ids = merge(
    { "tenant-root" = "/providers/Microsoft.Management/managementGroups/${module.yaml_processing.tenant_id}" },
    { for name, mg in module.yaml_processing.management_groups : name => "/providers/Microsoft.Management/managementGroups/${mg.name}" },
    {
      for key, rg in module.yaml_processing.resource_groups : key =>
      "/subscriptions/${local.subscription_ids[rg.subscription]}/resourceGroups/${rg.name}"
    }
  )
}

check "subscriptions_resolvable" {
  assert {
    condition = alltrue([
      for name, id in local.subscription_ids : id != null
    ])
    error_message = "Unable to resolve every YAML subscription to an Azure subscription by display name. Verify the subscriptions exist and their display names are unique."
  }
}

data "azuread_user" "this" {
  for_each = local.user_principal_names

  user_principal_name = each.value
}

data "azurerm_role_definition" "this" {
  for_each = local.role_names

  name = each.value
}

resource "azurerm_role_assignment" "this" {
  for_each = module.yaml_processing.iam_assignments

  scope              = local.scope_ids[each.value.scope_name]
  role_definition_id = data.azurerm_role_definition.this[each.value.role].id
  principal_id       = data.azuread_user.this[each.value.principal].object_id
}
