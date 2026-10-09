# Azure resource IDs exported by the flat network module.
output "vnet_ids" {
  description = "Map of Virtual Network name -> Azure resource ID."
  value       = { for key, vnet in azapi_resource.vnet : key => vnet.id }
}

output "peering_ids" {
  description = "Map of VNet peering name -> Azure resource ID."
  value       = { for name, peering in azapi_resource.peering : name => peering.id }
}

output "public_ip_ids" {
  description = "Map of enabled Public IP name -> Azure resource ID."
  value       = { for name, public_ip in azapi_resource.public_ip : name => public_ip.id }
}

output "nat_gateway_ids" {
  description = "Map of enabled NAT Gateway name -> Azure resource ID."
  value       = { for name, nat_gateway in azapi_resource.nat_gateway : name => nat_gateway.id }
}

output "bastion_ids" {
  description = "Map of Azure Bastion name -> Azure resource ID."
  value       = { for name, bastion in azapi_resource.bastion : name => bastion.id }
}

output "nat_gateway_subnet_association_ids" {
  description = "Map of NAT Gateway-to-subnet association key -> subnet resource ID."
  value = {
    for key, subnet in module.yaml_processing.subnets :
    key => azapi_resource.subnet[key].id
    if contains(keys(module.yaml_processing.nat_gateway_subnet_associations), key)
  }
}

output "firewall_ids" {
  description = "Map of Azure Firewall name -> Azure resource ID."
  value       = { for name, firewall in azapi_resource.firewall : name => firewall.id }
}

output "firewall_policy_ids" {
  description = "Map of Firewall Policy name -> Azure resource ID."
  value       = { for name, policy in azapi_resource.firewall_policy : name => policy.id }
}

output "firewall_policy_group_ids" {
  description = "Map of Firewall Policy rule collection group key -> Azure resource ID."
  value       = { for key, group in azapi_resource.firewall_policy_group : key => group.id }
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

output "route_table_ids" {
  description = "Map of route table name -> Azure resource ID."
  value       = { for name, route_table in azapi_resource.route_table : name => route_table.id }
}

output "route_ids" {
  description = "Map of route key (route table/route) -> Azure resource ID."
  value       = { for key, route in azapi_resource.route : key => route.id }
}

output "route_table_subnet_association_ids" {
  description = "Map of route-table-to-subnet association key (vnet/subnet) -> subnet resource ID."
  value = {
    for key, subnet in module.yaml_processing.subnets :
    key => azapi_resource.subnet[key].id
    if contains(keys(module.yaml_processing.route_table_subnet_associations), key)
  }
}
