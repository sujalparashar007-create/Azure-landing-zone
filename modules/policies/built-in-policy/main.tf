data "azurerm_policy_definition_built_in" "this" {
  for_each     = { for k, p in var.policies : k => p.definition }
  display_name = each.value
}

locals {
  assignment_names = {
    for k, p in var.policies :
    k => format("%s-%s", substr(replace(lower(k), " ", "-"), 0, 17), substr(sha1(k), 0, 6))
  }
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = var.policies

  name                 = local.assignment_names[each.key]
  management_group_id  = var.scope_ids[each.value.scope_name]
  policy_definition_id = data.azurerm_policy_definition_built_in.this[each.key].id

  parameters = length(each.value.parameters) > 0 ? jsonencode({
    for pk, pv in each.value.parameters : pk => { value = pv }
  }) : null
}