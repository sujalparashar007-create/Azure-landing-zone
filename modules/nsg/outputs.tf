output "nsg_ids" {
  description = "Map of NSG name -> Azure resource ID."
  value       = { for name, nsg in azapi_resource.nsg : name => nsg.id }
}

output "rule_ids" {
  description = "Map of rule key (nsg/rule) -> Azure resource ID."
  value       = { for key, rule in azapi_resource.rule : key => rule.id }
}