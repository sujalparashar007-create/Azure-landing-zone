output "tenant_name" {
  value = module.yaml_processing.tenant_name
}

output "tenant_id" {
  value = module.yaml_processing.tenant_id
}

output "management_group_hierarchy" {
  value = module.management_groups.management_group_ids
}

output "subscription_placement" {
  value = module.management_groups.subscriptions
}
