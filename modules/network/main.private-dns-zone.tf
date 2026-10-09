# Creates Private DNS zones and their VNet links from network.yaml.
locals {
  private_dns_zone_subscription_id = {
    for name, zone in module.yaml_processing.private_dns_zones :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == zone.subscription_display_name && s.state == "Enabled"
    ])
  }

  private_dns_zone_vnet_key = {
    for key, link in module.yaml_processing.private_dns_zone_vnet_links :
    key => one([
      for vnet_key, vnet in module.yaml_processing.vnets :
      vnet_key
      if vnet.name == link.vnet
    ])
  }
}

resource "azapi_resource" "private_dns_zone" {
  for_each = module.yaml_processing.private_dns_zones

  retry = var.azapi_retry

  type      = "Microsoft.Network/privateDnsZones@2020-06-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.private_dns_zone_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = "global"
  tags      = each.value.tags

  body = {
    properties = {}
  }
}

resource "azapi_resource" "private_dns_zone_vnet_link" {
  for_each = module.yaml_processing.private_dns_zone_vnet_links

  depends_on = [azapi_resource.private_dns_zone, azapi_resource.vnet]

  retry = var.azapi_retry

  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  name      = each.value.name
  parent_id = azapi_resource.private_dns_zone[each.value.zone].id
  location  = "global"

  body = {
    properties = {
      registrationEnabled = false
      virtualNetwork = {
        id = azapi_resource.vnet[local.private_dns_zone_vnet_key[each.key]].id
      }
    }
  }
}
