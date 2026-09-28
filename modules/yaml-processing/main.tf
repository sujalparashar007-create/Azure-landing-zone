locals {
  # ----------------------------------------------------------
  # Load YAML
  # ----------------------------------------------------------

  landing_zone = yamldecode(file(var.yaml_file))

  # Custom policy YAML lives next to the main YAML file
  # (config/custom-policy.yaml). It holds the custom policy
  # assignments and the custom policy definitions.
  custom_policy_config = yamldecode(file("${dirname(var.yaml_file)}/custom-policy.yaml"))


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
            subscription   = sub.name
            resource_group = rg.name
            location       = rg.location
          }
        )
      ]
    ]
  ])

  # ----------------------------------------------------------
  # Policies (tenant-level + every management group level)
  #
  # Built-in policies live in the main YAML (azure.yaml).
  # Custom policies live in config/custom-policy.yaml.
  # Each policy lives wherever it applies (tenant root or a
  # specific management group), so we walk all sources and tag
  # each entry with its scope.
  #
  # The "== null ? [] :" checks keep this working even when a
  # policies: key is missing or left empty in the YAML.
  # ----------------------------------------------------------

  tenant_policies = [
    for p in try(local.landing_zone.tenant.policies, []) : merge(
      p,
      {
        scope_type = "management_group"
        scope_name = "tenant-root"
      }
    )
  ]

  mg_policies = flatten([
    for mg in local.management_groups : [
      for p in try(mg.policies, []) : merge(
        p,
        {
          scope_type = "management_group"
          scope_name = mg.name
        }
      )
    ]
  ])

  custom_tenant_policies = [
    for p in try(local.custom_policy_config.tenant.policies, []) : merge(
      p,
      {
        scope_type = "management_group"
        scope_name = "tenant-root"
      }
    )
  ]

  custom_mg_policies = flatten([
    for mg in try(local.custom_policy_config.management_groups, []) : [
      for p in try(mg.policies, []) : merge(
        p,
        {
          scope_type = "management_group"
          scope_name = mg.name
        }
      )
    ]
  ])

  all_policies_raw = concat(
    local.tenant_policies,
    local.mg_policies,
    local.custom_tenant_policies,
    local.custom_mg_policies
  )

  custom_policy_definitions = try(local.custom_policy_config.custom_policy_definitions, {})

  # ----------------------------------------------------------
  # Classify each policy as built-in or custom
  #
  # Classification is driven by the `definition` field, matched
  # case-insensitively against a known list of real Azure
  # built-in policy display names. Anything not in this list is
  # treated as custom.
  # ----------------------------------------------------------

  builtin_definition_names = [
    "allowed locations",
    "require a tag on resources",
  ]

  all_policies = [
    for p in local.all_policies_raw : {
      name                  = p.name
      definition            = p.definition
      scope_type            = p.scope_type
      scope_name            = p.scope_name
      effect                = try(p.effect, "Deny")
      parameters            = try(p.parameters, {})
      display_name          = try(local.custom_policy_definitions[p.definition].display_name, null)
      policy_rule           = try(local.custom_policy_definitions[p.definition].policy_rule, null)
      definition_parameters = try(local.custom_policy_definitions[p.definition].parameters, null)
      policy_type           = contains(local.builtin_definition_names, lower(p.definition)) ? "built-in" : "custom"
    }
  ]


  # ----------------------------------------------------------
  # Split into built-in vs custom, converted to maps
  # ----------------------------------------------------------

  builtin_policies = [
    for p in local.all_policies : p if p.policy_type == "built-in"
  ]

  custom_policies = [
    for p in local.all_policies : p if p.policy_type == "custom"
  ]

  builtin_policies_map = {
    for p in local.builtin_policies :
    "${p.scope_name}-${p.name}" => p
  }

  custom_policies_map = {
    for p in local.custom_policies :
    "${p.scope_name}-${p.name}" => p
  }


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
        policies          = local.all_policies
      })
    )
  }
}