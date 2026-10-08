# Creates route tables and routes from network.yaml. Subnet associations are
# owned by the subnet PUT in main.subnet.tf so route-table updates remain
# part of the same subnet resource operation.
locals {
  route_table_subscription_id = {
    for name, route_table in module.yaml_processing.route_tables :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == route_table.subscription_display_name && s.state == "Enabled"
    ])
  }
}

resource "azapi_resource" "route_table" {
  for_each = module.yaml_processing.route_tables

  retry = var.azapi_retry

  type      = "Microsoft.Network/routeTables@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.route_table_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    properties = {
      disableBgpRoutePropagation = !each.value.bgp_route_propagation_enabled
    }
  }
}

resource "azapi_resource" "route" {
  for_each = module.yaml_processing.route_table_routes

  retry = var.azapi_retry

  type      = "Microsoft.Network/routeTables/routes@2024-01-01"
  name      = each.value.name
  parent_id = azapi_resource.route_table[each.value.route_table_name].id

  body = {
    properties = merge(
      {
        addressPrefix = each.value.address_prefix
        nextHopType   = each.value.next_hop_type
      },
      each.value.next_hop_ip_address != null ? {
        nextHopIpAddress = each.value.next_hop_ip_address
      } : {}
    )
  }
}
