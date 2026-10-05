output "vnet_ids" {
  description = "Map of Virtual Network name -> Azure resource ID."
  value       = { for key, vnet in azapi_resource.this : key => vnet.id }
}
