module "yaml_processing" {
  source = "../../yaml-processing"

  yaml_file = coalesce(var.yaml_file, "${path.module}/../../yaml-processing/config/azure.yaml")
}

data "azurerm_policy_definition_built_in" "this" {
  for_each     = { for k, p in module.yaml_processing.builtin_policies : k => p.definition }
  display_name = each.value
}

locals {
  scope_ids = merge(
    { "tenant-root" = "/providers/Microsoft.Management/managementGroups/${module.yaml_processing.tenant_id}" },
    { for name, mg in module.yaml_processing.management_groups : name => "/providers/Microsoft.Management/managementGroups/${mg.name}" }
  )

  assignment_names = {
    for k, p in module.yaml_processing.builtin_policies :
    k => format("%s-%s", substr(replace(lower(k), " ", "-"), 0, 17), substr(sha1(k), 0, 6))
  }
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = module.yaml_processing.builtin_policies

  name                 = local.assignment_names[each.key]
  management_group_id  = local.scope_ids[each.value.scope_name]
  policy_definition_id = data.azurerm_policy_definition_built_in.this[each.key].id

  parameters = jsonencode(merge(
    { for pk, pv in each.value.parameters : pk => { value = pv } },
    { effect = { value = each.value.effect } }
  ))
}
