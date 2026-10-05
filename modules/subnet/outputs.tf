output "subnet_ids" {
  description = "Map of subnet key (vnet/subnet) -> Azure resource ID."
  value       = { for key, subnet in azapi_resource.this : key => subnet.id }
}