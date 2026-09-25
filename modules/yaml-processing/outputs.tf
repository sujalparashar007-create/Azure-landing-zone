output "management_groups" {
  description = "Flattened management groups"
  value       = local.management_groups_map
}

output "subscriptions" {
  description = "Flattened subscriptions with management group relationship"
  value       = local.subscriptions_map
}

output "resource_groups" {
  description = "Flattened resource groups with subscription relationship"
  value       = local.resource_groups_map
}

output "resources" {
  description = "Flattened resources with subscription and resource group relationships"
  value       = local.resources_map
}

output "yaml_processing_id" {
  description = "ID of the YAML processing null_resource"
  value       = null_resource.yaml_flatten.id
}

output "tenant_name" {
  description = "Tenant display name, read once here so the YAML is not decoded in more than one place"
  value       = local.landing_zone.tenant.display_name
}

output "tenant_id" {
  description = "Tenant ID, read once here so the YAML is not decoded in more than one place"
  value       = local.landing_zone.tenant.id
}
