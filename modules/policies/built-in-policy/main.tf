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

  # Determine, per assignment, whether the referenced built-in definition
  # actually declares an `effect` parameter. Some built-in definitions only
  # declare their own parameters (e.g. "Require a tag on resources" declares
  # only `tagName`), so we must not send `effect` to those.
  definition_has_effect = {
    for k, p in module.yaml_processing.builtin_policies :
    k => contains(keys(try(jsondecode(data.azurerm_policy_definition_built_in.this[k].parameters), {})), "effect")
  }
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = module.yaml_processing.builtin_policies

  name                 = local.assignment_names[each.key]
  management_group_id  = local.scope_ids[each.value.scope_name]
  policy_definition_id = data.azurerm_policy_definition_built_in.this[each.key].id

  parameters = jsonencode(merge(
    { for pk, pv in each.value.parameters : pk => { value = pv } },
    local.definition_has_effect[each.key] ? { effect = { value = each.value.effect } } : {}
  ))
}
