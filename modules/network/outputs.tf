# Azure resource IDs exported by the flat network module.
output "vnet_ids" {
  description = "Map of Virtual Network name -> Azure resource ID."
  value       = { for key, vnet in azapi_resource.vnet : key => vnet.id }
}

output "subnet_ids" {
  description = "Map of subnet key (vnet/subnet) -> Azure resource ID."
  value       = { for key, subnet in azapi_resource.subnet : key => subnet.id }
}

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
  value = {
    for key, subnet in module.yaml_processing.subnets :
    key => azapi_resource.subnet[key].id
    if contains(keys(module.yaml_processing.nsg_subnet_associations), key)
  }
}
