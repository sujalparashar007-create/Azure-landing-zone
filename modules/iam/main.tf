locals {
  group_emails = toset([
    for assignment in var.assignments : trimprefix(assignment.principal, "group:")
    if startswith(assignment.principal, "group:")
  ])

  role_names = toset([
    for assignment in var.assignments : assignment.role
  ])
}

data "azuread_group" "this" {
  for_each = local.group_emails

  mail_nickname = split("@", each.value)[0]
}

data "azurerm_role_definition" "this" {
  for_each = local.role_names

  name = each.value
}

resource "azurerm_role_assignment" "this" {
  for_each = var.assignments

  scope              = var.scope_ids[each.value.scope_name]
  role_definition_id = data.azurerm_role_definition.this[each.value.role].id
  principal_id       = data.azuread_group.this[trimprefix(each.value.principal, "group:")].object_id
}