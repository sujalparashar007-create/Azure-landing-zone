# Creates Private DNS Resolver resources from network.yaml using existing
# delegated resolver subnets and the existing hub VNet.
locals {
  private_dns_resolver_subscription_id = {
    for name, resolver in module.yaml_processing.private_dns_resolvers :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == resolver.subscription_display_name && s.state == "Enabled"
    ])
  }

  private_dns_resolver_vnet_key = {
    for name, resolver in module.yaml_processing.private_dns_resolvers :
    name => one([
      for key, vnet in module.yaml_processing.vnets :
      key
      if vnet.name == resolver.vnet &&
      vnet.subscription == resolver.subscription &&
      vnet.resource_group == resolver.resource_group
    ])
  }

  private_dns_resolver_inbound_subnet_key = {
    for name, endpoint in module.yaml_processing.private_dns_resolver_inbound_endpoints :
    name => one([
      for key, subnet in module.yaml_processing.subnets :
      key
      if subnet.name == endpoint.subnet &&
      subnet.vnet_name == module.yaml_processing.private_dns_resolvers[endpoint.resolver].vnet &&
      subnet.subscription == module.yaml_processing.private_dns_resolvers[endpoint.resolver].subscription &&
      subnet.resource_group == module.yaml_processing.private_dns_resolvers[endpoint.resolver].resource_group
    ])
  }

  private_dns_resolver_outbound_subnet_key = {
    for name, endpoint in module.yaml_processing.private_dns_resolver_outbound_endpoints :
    name => one([
      for key, subnet in module.yaml_processing.subnets :
      key
      if subnet.name == endpoint.subnet &&
      subnet.vnet_name == module.yaml_processing.private_dns_resolvers[endpoint.resolver].vnet &&
      subnet.subscription == module.yaml_processing.private_dns_resolvers[endpoint.resolver].subscription &&
      subnet.resource_group == module.yaml_processing.private_dns_resolvers[endpoint.resolver].resource_group
    ])
  }
}

resource "azapi_resource" "private_dns_resolver" {
  for_each = module.yaml_processing.private_dns_resolvers

  depends_on = [azapi_resource.vnet]

  retry = var.azapi_retry

  type      = "Microsoft.Network/dnsResolvers@2022-07-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.private_dns_resolver_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location
  tags      = each.value.tags

  body = {
    properties = {
      virtualNetwork = {
        id = azapi_resource.vnet[local.private_dns_resolver_vnet_key[each.key]].id
      }
    }
  }
}

resource "azapi_resource" "private_dns_resolver_inbound_endpoint" {
  for_each = module.yaml_processing.private_dns_resolver_inbound_endpoints

  depends_on = [azapi_resource.private_dns_resolver, azapi_resource.subnet]

  retry = var.azapi_retry

  type      = "Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01"
  name      = each.value.name
  parent_id = azapi_resource.private_dns_resolver[each.value.resolver].id
  location  = module.yaml_processing.private_dns_resolvers[each.value.resolver].location

  body = {
    properties = {
      ipConfigurations = [{
        privateIpAllocationMethod = each.value.private_ip_allocation
        subnet = {
          id = azapi_resource.subnet[local.private_dns_resolver_inbound_subnet_key[each.key]].id
        }
      }]
    }
  }
}

resource "azapi_resource" "private_dns_resolver_outbound_endpoint" {
  for_each = module.yaml_processing.private_dns_resolver_outbound_endpoints

  depends_on = [azapi_resource.private_dns_resolver, azapi_resource.subnet]

  retry = var.azapi_retry

  type      = "Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01"
  name      = each.value.name
  parent_id = azapi_resource.private_dns_resolver[each.value.resolver].id
  location  = module.yaml_processing.private_dns_resolvers[each.value.resolver].location

  body = {
    properties = {
      subnet = {
        id = azapi_resource.subnet[local.private_dns_resolver_outbound_subnet_key[each.key]].id
      }
    }
  }
}
