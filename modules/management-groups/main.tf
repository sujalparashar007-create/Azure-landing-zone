locals {
  # --------------------------------------------------------------------
  # Derive hierarchy levels from the flat management_groups map using
  # parent-chain membership. The yaml-processing module hands us a flat
  # map (no explicit "level" tag), so we rebuild the levels here: a
  # group is level N+1 if its parent's name is found among the level N
  # groups. This is required because a resource cannot reference other
  # instances of itself via a dynamic for_each key (Terraform "Cycle"
  # error) - so each level must be its own resource block, referencing
  # only the previous (distinct) resource address.
  # --------------------------------------------------------------------
  level1_groups = { for name, g in var.management_groups : name => g if g.parent == "tenant-root" }
  level2_groups = { for name, g in var.management_groups : name => g if contains(keys(local.level1_groups), g.parent) }
  level3_groups = { for name, g in var.management_groups : name => g if contains(keys(local.level2_groups), g.parent) }
  level4_groups = { for name, g in var.management_groups : name => g if contains(keys(local.level3_groups), g.parent) }

  # Merge every level's resulting IDs into a single name -> id lookup,
  # so subscriptions (or any future consumer) can resolve a parent name
  # to its ID without caring which level it lives at.
  management_group_ids_by_name = merge(
    { for name, mg in azurerm_management_group.level1 : name => mg.id },
    { for name, mg in azurerm_management_group.level2 : name => mg.id },
    { for name, mg in azurerm_management_group.level3 : name => mg.id },
    { for name, mg in azurerm_management_group.level4 : name => mg.id },
  )

  subscriptions = {
    for name, sub in var.subscriptions : name => {
      display_name        = sub.display_name
      billing_scope_id     = sub.billing_scope_id
      management_group_id = local.management_group_ids_by_name[sub.management_group]
    }
  }
}

# ==========================================================================
# MANAGEMENT GROUPS - split by hierarchy level (see comment above)
# ==========================================================================

resource "azurerm_management_group" "level1" {
  for_each = local.level1_groups

  name         = each.value.name
  display_name = each.value.display_name
  # Level 1 groups sit directly under the tenant root.
  parent_management_group_id = null
}

resource "azurerm_management_group" "level2" {
  for_each = local.level2_groups

  name                        = each.value.name
  display_name                = each.value.display_name
  parent_management_group_id  = azurerm_management_group.level1[each.value.parent].id
}

resource "azurerm_management_group" "level3" {
  for_each = local.level3_groups

  name                        = each.value.name
  display_name                = each.value.display_name
  parent_management_group_id  = azurerm_management_group.level2[each.value.parent].id
}

resource "azurerm_management_group" "level4" {
  for_each = local.level4_groups

  name                        = each.value.name
  display_name                = each.value.display_name
  parent_management_group_id  = azurerm_management_group.level3[each.value.parent].id
}

# ==========================================================================
# SUBSCRIPTIONS
# ==========================================================================

resource "azurerm_subscription" "this" {
  for_each = local.subscriptions

  subscription_name = each.value.display_name
  billing_scope_id   = each.value.billing_scope_id
}

# ==========================================================================
# MANAGEMENT GROUP <-> SUBSCRIPTION ASSOCIATIONS
# ==========================================================================

resource "azurerm_management_group_subscription_association" "this" {
  for_each = local.subscriptions

  management_group_id = each.value.management_group_id
  subscription_id      = "/subscriptions/${azurerm_subscription.this[each.key].subscription_id}"
}
