module "yaml_processing" {
  source = "./modules/yaml-processing"

  yaml_file = var.yaml_file
}

# ==========================================================================
# MANAGEMENT GROUPS + SUBSCRIPTIONS + ASSOCIATIONS
# ==========================================================================
# Future modules (resource-groups, policy, iam, budget, etc.) get added
# here the same way - each one consumes the relevant flattened output
# from module.yaml_processing (and, where relevant, outputs from earlier
# modules such as module.management_groups.management_group_ids).
# ==========================================================================

module "management_groups" {
  source = "./modules/management-groups"

  management_groups = module.yaml_processing.management_groups
  subscriptions     = module.yaml_processing.subscriptions
}

# ==========================================================================
# SCOPE RESOLUTION FOR POLICIES
# ==========================================================================
# Policies in the YAML are scoped by name ("tenant-root" or a management
# group's name). This local merges the tenant root MG's own ID (not a
# created resource — it's implicit in Azure, derived from tenant_id) with
# every management group's ID, so both policy modules can resolve any
# scope_name to its actual Azure resource ID.
# ==========================================================================

locals {
  tenant_root_management_group_id = "/providers/Microsoft.Management/managementGroups/${module.yaml_processing.tenant_id}"

  policy_scope_ids = merge(
    { "tenant-root" = local.tenant_root_management_group_id },
    module.management_groups.management_group_ids
  )
}

# ==========================================================================
# POLICIES — BUILT-IN + CUSTOM
# ==========================================================================

module "built_in_policy" {
  source = "./modules/policies/built-in-policy"

  policies  = module.yaml_processing.builtin_policies
  scope_ids = local.policy_scope_ids
}

module "custom_policy" {
  source = "./modules/policies/custom-policy"

  policies                        = module.yaml_processing.custom_policies
  scope_ids                       = local.policy_scope_ids
  definitions_management_group_id = local.tenant_root_management_group_id
}

# ==========================================================================
# RESOURCE GROUPS
# ==========================================================================

module "resource_groups" {
  source = "./modules/resource-groups"

  resource_groups = module.yaml_processing.resource_groups
  subscriptions   = module.management_groups.subscriptions

  depends_on = [module.management_groups]
}