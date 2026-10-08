# Creates enabled NAT Gateways and associates them through the subnet PUT.
locals {
  nat_gateway_subscription_id = {
    for name, nat_gateway in module.yaml_processing.nat_gateways :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == nat_gateway.subscription_display_name && s.state == "Enabled"
    ])
  }
}

resource "azapi_resource" "nat_gateway" {
  for_each = module.yaml_processing.nat_gateways

  retry = var.azapi_retry

  type      = "Microsoft.Network/natGateways@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.nat_gateway_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location
  tags      = each.value.tags

  body = {
    sku = {
      name = each.value.sku
    }
    properties = {
      publicIpAddresses = [{
        id = azapi_resource.public_ip[each.value.public_ip].id
      }]
    }
  }
}
