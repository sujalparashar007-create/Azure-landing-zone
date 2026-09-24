locals {
  config = yamldecode(file(var.yaml_file))
}

# ==========================================================================
# MANAGEMENT GROUPS + SUBSCRIPTIONS + ASSOCIATIONS
# ==========================================================================
# Future modules (resource-groups, rbac, iam, policy, etc.) get added here
# the same way - each one receives local.config (and, where relevant,
# module.management_groups.management_group_ids / .subscriptions to know
# which management group / subscription to attach to).
# ==========================================================================

module "management_groups" {
  source = "./modules/management-groups"

  config = local.config
}
