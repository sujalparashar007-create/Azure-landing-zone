output "resource_group_ids" {
  description = "Map of resource group key (subscription/name) -> Azure resource ID."
  value       = { for key, rg in azapi_resource.this : key => rg.id }
}