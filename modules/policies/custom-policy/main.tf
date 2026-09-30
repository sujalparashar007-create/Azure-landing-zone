module "yaml_processing" {
  source = "../../yaml-processing"

  yaml_file = coalesce(var.yaml_file, "${path.module}/../../yaml-processing/config/azure.yaml")
}

data "azurerm_client_config" "current" {}

# Grants the deploying identity permission to create custom policy definitions
# at the definition scope (tenant root MG), so this module works for anyone who runs it.
resource "azurerm_role_assignment" "policy_definition_writer" {
  scope                = local.tenant_root_management_group_id
  role_definition_name = "Resource Policy Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role assignments take time to propagate in Azure
resource "time_sleep" "role_propagation" {
  depends_on      = [azurerm_role_assignment.policy_definition_writer]
  create_duration = "60s"
}

locals {
  tenant_root_management_group_id = "/providers/Microsoft.Management/managementGroups/${module.yaml_processing.tenant_id}"
  scope_ids = merge(
    { "tenant-root" = local.tenant_root_management_group_id },
    { for name, mg in module.yaml_processing.management_groups : name => "/providers/Microsoft.Management/managementGroups/${mg.name}" }
  )

  custom_policy_definitions = {
    for definition in distinct([for p in module.yaml_processing.custom_policies : p.definition]) :
    definition => [for p in module.yaml_processing.custom_policies : p if p.definition == definition]
  }

  assignment_names = {
    for k, p in module.yaml_processing.custom_policies :
    k => format("%s-%s", substr(replace(lower(k), " ", "-"), 0, 17), substr(sha1(k), 0, 6))
  }
}

resource "azurerm_policy_definition" "this" {
  for_each            = local.custom_policy_definitions
  name                = replace(lower(each.key), " ", "-")
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = each.value[0].display_name
  management_group_id = local.tenant_root_management_group_id
  policy_rule         = jsonencode(each.value[0].policy_rule)
  parameters          = jsonencode(each.value[0].definition_parameters)

  depends_on = [time_sleep.role_propagation]
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = module.yaml_processing.custom_policies

  name                 = local.assignment_names[each.key]
  management_group_id  = local.scope_ids[each.value.scope_name]
  policy_definition_id = azurerm_policy_definition.this[each.value.definition].id

  parameters = jsonencode({
    effect = { value = each.value.effect }
  })
}
