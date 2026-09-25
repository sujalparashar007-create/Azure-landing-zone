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
