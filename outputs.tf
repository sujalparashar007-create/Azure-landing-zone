output "tenant_name" {
  value = local.config.tenant.display_name
}

output "tenant_id" {
  value = local.config.tenant.id
}

output "management_group_hierarchy" {
  value = module.management_groups.management_group_ids
}

output "subscription_placement" {
  value = module.management_groups.subscriptions
}
