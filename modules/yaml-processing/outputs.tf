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

output "budgets" {
  description = "Flattened budget instances with subscription scope and notification recipients"
  value       = local.budgets_map
}

output "iam_assignments" {
  description = "Flattened IAM assignments with tenant, management group, subscription, and resource group scopes"
  value       = local.iam_assignments_map
}

output "users" {
  description = "Map of IAM principal sign-in email to Entra ID user object id"
  value       = local.users
}

output "builtin_policies" {
  description = "Flattened built-in policies with scope (tenant root or management group)"
  value       = local.builtin_policies_map
}

output "custom_policies" {
  description = "Flattened custom policies with scope (tenant root or management group)"
  value       = local.custom_policies_map
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

output "vnets" {
  description = "Flattened Virtual Networks (hub + spokes) from network.yaml"
  value       = local.vnets
}

output "peerings" {
  description = "Flattened VNet peerings from network.yaml"
  value       = local.peerings
}

output "public_ips" {
  description = "Enabled Public IP definitions from network.yaml"
  value       = local.public_ips
}

output "nat_gateways" {
  description = "Enabled NAT Gateway definitions from network.yaml"
  value       = local.nat_gateways
}

output "nat_gateway_subnet_associations" {
  description = "NAT Gateway-to-subnet associations from network.yaml"
  value       = local.nat_gateway_subnet_associations
}

output "subnets" {
  description = "Flattened subnets (hub + spokes) from network.yaml, keyed by vnet/subnet"
  value       = local.subnets
}

output "nsgs" {
  description = "Flattened network security groups from network.yaml"
  value       = local.nsgs
}

output "nsg_rules" {
  description = "Flattened NSG security rules from network.yaml, keyed by nsg/rule"
  value       = local.nsg_rules
}

output "nsg_subnet_associations" {
  description = "NSG-to-subnet associations from network.yaml, keyed by vnet/subnet"
  value       = local.nsg_subnet_associations
}

output "route_tables" {
  description = "Flattened route tables and routes from network.yaml"
  value       = local.route_tables
}

output "route_table_routes" {
  description = "Flattened route-table routes from network.yaml, keyed by route table/name"
  value       = local.route_table_routes
}

output "route_table_subnet_associations" {
  description = "Route-table-to-subnet associations from network.yaml, keyed by vnet/subnet"
  value       = local.route_table_subnet_associations
}
