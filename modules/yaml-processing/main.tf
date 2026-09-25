locals {
  # ----------------------------------------------------------
  # Load YAML
  # ----------------------------------------------------------

  landing_zone = yamldecode(file(var.yaml_file))


  # ----------------------------------------------------------
  # Management Group Hierarchy
  #
  # YAML has a maximum of 4 levels:
  #
  # Level 1 → Platform
  # Level 2 → Shared Services / Network / Production
  # Level 3 → Production Network / Production Applications
  # Level 4 → Payments
  # ----------------------------------------------------------

  mg_level_1 = local.landing_zone.management_groups

  mg_level_2 = flatten([
    for mg1 in local.mg_level_1 : [
      for mg2 in try(mg1.children, []) : merge(
        mg2,
        {
          parent = mg1.name
        }
      )
    ]
  ])

  mg_level_3 = flatten([
    for mg2 in local.mg_level_2 : [
      for mg3 in try(mg2.children, []) : merge(
        mg3,
        {
          parent = mg2.name
        }
      )
    ]
  ])

  mg_level_4 = flatten([
    for mg3 in local.mg_level_3 : [
      for mg4 in try(mg3.children, []) : merge(
        mg4,
        {
          parent = mg3.name
        }
      )
    ]
  ])


  # ----------------------------------------------------------
  # All Management Groups
  # ----------------------------------------------------------

  management_groups = concat(
    local.mg_level_1,
    local.mg_level_2,
    local.mg_level_3,
    local.mg_level_4
  )


  # ----------------------------------------------------------
  # Subscriptions
  # ----------------------------------------------------------

  subscriptions = flatten([
    for mg in local.management_groups : [
      for sub in try(mg.subscriptions, []) : merge(
        sub,
        {
          management_group = mg.name
        }
      )
    ]
  ])


  # ----------------------------------------------------------
  # Resource Groups
  # ----------------------------------------------------------

  resource_groups = flatten([
    for sub in local.subscriptions : [
      for rg in try(sub.resource_groups, []) : merge(
        rg,
        {
          subscription = sub.name
        }
      )
    ]
  ])


  # ----------------------------------------------------------
  # Resources
  # ----------------------------------------------------------

  resources = flatten([
    for sub in local.subscriptions : [
      for rg in try(sub.resource_groups, []) : [
        for resource in try(rg.resources, []) : merge(
          resource,
          {
            subscription  = sub.name
            resource_group = rg.name
            location      = rg.location
          }
        )
      ]
    ]
  ])


  # ----------------------------------------------------------
  # Convert to maps
  #
  # Maps make it easier for future modules to use for_each.
  # ----------------------------------------------------------

  management_groups_map = {
    for mg in local.management_groups :
    mg.name => mg
  }

  subscriptions_map = {
    for sub in local.subscriptions :
    sub.name => sub
  }

  resource_groups_map = {
    for rg in local.resource_groups :
    "${rg.subscription}/${rg.name}" => rg
  }

  resources_map = {
    for resource in local.resources :
    "${resource.subscription}/${resource.resource_group}/${resource.type}/${resource.name}" => resource
  }
}


# ----------------------------------------------------------
# Required null_resource
#
# This does NOT create an Azure resource.
#
# It tracks the YAML + flattened configuration so Terraform
# knows when the processing layer has changed.
# ----------------------------------------------------------

resource "null_resource" "yaml_flatten" {
  triggers = {
    yaml_file_hash = filesha256(var.yaml_file)

    flattened_configuration_hash = sha256(
      jsonencode({
        management_groups = local.management_groups
        subscriptions     = local.subscriptions
        resource_groups   = local.resource_groups
        resources         = local.resources
      })
    )
  }
}