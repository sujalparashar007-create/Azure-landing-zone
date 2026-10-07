output "nsg_ids" {
  description = "Map of NSG name -> Azure resource ID."
  value       = { for name, nsg in azapi_resource.nsg : name => nsg.id }
}

output "rule_ids" {
  description = "Map of rule key (nsg/rule) -> Azure resource ID."
  value       = { for key, rule in azapi_resource.rule : key => rule.id }
}

output "nsg_subnet_association_ids" {
  description = "Map of NSG-to-subnet association key (vnet/subnet) -> subnet resource ID."
  value       = { for key, assoc in azapi_update_resource.nsg_subnet_association : key => assoc.id }
}