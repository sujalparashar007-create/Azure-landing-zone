# Creates enabled Public IP resources from network.yaml.
locals {
  public_ip_subscription_id = {
    for name, public_ip in module.yaml_processing.public_ips :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == public_ip.subscription_display_name && s.state == "Enabled"
    ])
  }
}

resource "azapi_resource" "public_ip" {
  for_each = module.yaml_processing.public_ips

  retry = var.azapi_retry

  type      = "Microsoft.Network/publicIPAddresses@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.public_ip_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location
  tags      = each.value.tags

  body = {
    sku = {
      name = each.value.sku
    }
    zones = length(each.value.zones) > 0 ? each.value.zones : null
    properties = merge(
      {
        publicIPAllocationMethod = each.value.allocation
      }
    )
  }
}
