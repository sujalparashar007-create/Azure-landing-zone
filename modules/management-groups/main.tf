locals {
  # --------------------------------------------------------------------
  # Flatten the management group tree, tagging each record with its
  # hierarchy depth (level) and its parent's name. Keying everything by
  # name (never array index) means the YAML can be freely edited -
  # groups added, removed, renamed, or reordered - without touching
  # this module.
  # --------------------------------------------------------------------
  management_group_records = flatten([
    for l1 in try(var.config.management_groups, []) : concat(
      [{
        name   = l1.name
        record = l1
        parent = try(l1.parent, "tenant-root")
        level  = 1
      }],
      flatten([
        for l2 in try(l1.children, []) : concat(
          [{
            name   = l2.name
            record = l2
            parent = l1.name
            level  = 2
          }],
          flatten([
            for l3 in try(l2.children, []) : concat(
              [{
                name   = l3.name
                record = l3
                parent = l2.name
                level  = 3
              }],
              [
                for l4 in try(l3.children, []) : {
                  name   = l4.name
                  record = l4
                  parent = l3.name
                  level  = 4
                }
              ]
            )
          ])
        )
      ])
    )
  ])

  management_groups = {
    for group in local.management_group_records : group.name => group
  }

  # Split by level - required because a resource cannot reference other
  # instances of itself via a dynamic for_each key (causes a Terraform
  # "Cycle" error). Each level instead references the previous level's
  # resource, which is a distinct resource address.
  level1_groups = { for g in local.management_group_records : g.name => g if g.level == 1 }
  level2_groups = { for g in local.management_group_records : g.name => g if g.level == 2 }
  level3_groups = { for g in local.management_group_records : g.name => g if g.level == 3 }
  level4_groups = { for g in local.management_group_records : g.name => g if g.level == 4 }

  # Merge every level's resulting IDs into a single name -> id lookup,
  # so subscriptions (or any future consumer) can resolve a parent name
  # to its ID without caring which level it lives at.
  management_group_ids_by_name = merge(
    { for name, mg in azurerm_management_group.level1 : name => mg.id },
    { for name, mg in azurerm_management_group.level2 : name => mg.id },
    { for name, mg in azurerm_management_group.level3 : name => mg.id },
    { for name, mg in azurerm_management_group.level4 : name => mg.id },
  )

  # --------------------------------------------------------------------
  # Flatten subscription declarations from every level of the tree,
  # retaining which management group (by name) each one belongs to.
  # --------------------------------------------------------------------
  subscription_records = flatten([
    for l1 in try(var.config.management_groups, []) :
    concat(
      [
        for subscription in try(l1.subscriptions, []) : {
          name             = subscription.name
          display_name     = subscription.display_name
          billing_scope_id = subscription.billing_scope_id
          parent           = l1.name
        }
      ],
      flatten([
        for l2 in try(l1.children, []) :
        concat(
          [
            for subscription in try(l2.subscriptions, []) : {
              name             = subscription.name
              display_name     = subscription.display_name
              billing_scope_id = subscription.billing_scope_id
              parent           = l2.name
            }
          ],
          flatten([
            for l3 in try(l2.children, []) :
            concat(
              [
                for subscription in try(l3.subscriptions, []) : {
                  name             = subscription.name
                  display_name     = subscription.display_name
                  billing_scope_id = subscription.billing_scope_id
                  parent           = l3.name
                }
              ],
              flatten([
                for l4 in try(l3.children, []) : [
                  for subscription in try(l4.subscriptions, []) : {
                    name             = subscription.name
                    display_name     = subscription.display_name
                    billing_scope_id = subscription.billing_scope_id
                    parent           = l4.name
                  }
                ]
              ])
            )
          ])
        )
      ])
    )
  ])

  subscriptions = {
    for subscription in local.subscription_records : subscription.name => {
      display_name        = subscription.display_name
      billing_scope_id     = subscription.billing_scope_id
      management_group_id = local.management_group_ids_by_name[subscription.parent]
    }
  }
}

# ==========================================================================
# MANAGEMENT GROUPS - split by hierarchy level (see comment above)
# ==========================================================================

resource "azurerm_management_group" "level1" {
  for_each = local.level1_groups

  name         = each.value.record.name
  display_name = each.value.record.display_name
  # Level 1 groups sit directly under the tenant root.
  parent_management_group_id = null
}

resource "azurerm_management_group" "level2" {
  for_each = local.level2_groups

  name                        = each.value.record.name
  display_name                = each.value.record.display_name
  parent_management_group_id  = azurerm_management_group.level1[each.value.parent].id
}

resource "azurerm_management_group" "level3" {
  for_each = local.level3_groups

  name                        = each.value.record.name
  display_name                = each.value.record.display_name
  parent_management_group_id  = azurerm_management_group.level2[each.value.parent].id
}

resource "azurerm_management_group" "level4" {
  for_each = local.level4_groups

  name                        = each.value.record.name
  display_name                = each.value.record.display_name
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
