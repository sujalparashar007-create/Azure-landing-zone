# Creates DNS forwarding rulesets, forwarding rules, and ruleset VNet links
# from network.yaml.
locals {
  private_dns_forwarding_ruleset_subscription_id = {
    for name, ruleset in module.yaml_processing.private_dns_forwarding_rulesets :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == ruleset.subscription_display_name && s.state == "Enabled"
    ])
  }

  private_dns_forwarding_ruleset_vnet_key = {
    for key, link in module.yaml_processing.private_dns_forwarding_ruleset_vnet_links :
    key => one([
      for vnet_key, vnet in module.yaml_processing.vnets :
      vnet_key
      if vnet.name == link.vnet
    ])
  }
}

resource "azapi_resource" "private_dns_forwarding_ruleset" {
  for_each = module.yaml_processing.private_dns_forwarding_rulesets

  depends_on = [azapi_resource.private_dns_resolver_outbound_endpoint]

  retry = var.azapi_retry

  type      = "Microsoft.Network/dnsForwardingRulesets@2022-07-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.private_dns_forwarding_ruleset_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location
  tags      = each.value.tags

  body = {
    properties = {
      dnsResolverOutboundEndpoints = [{
        id = azapi_resource.private_dns_resolver_outbound_endpoint[each.value.outbound_endpoint].id
      }]
    }
  }
}

resource "azapi_resource" "private_dns_forwarding_rule" {
  for_each = module.yaml_processing.private_dns_forwarding_rules

  depends_on = [azapi_resource.private_dns_forwarding_ruleset]

  retry = var.azapi_retry

  type      = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01"
  name      = each.value.name
  parent_id = azapi_resource.private_dns_forwarding_ruleset[each.value.ruleset].id

  body = {
    properties = {
      domainName          = each.value.domain_name
      forwardingRuleState = each.value.enabled ? "Enabled" : "Disabled"
      targetDnsServers = [
        for server in each.value.target_dns_servers : {
          ipAddress = server.ip_address
          port      = server.port
        }
      ]
    }
  }
}

resource "azapi_resource" "private_dns_forwarding_ruleset_vnet_link" {
  for_each = module.yaml_processing.private_dns_forwarding_ruleset_vnet_links

  depends_on = [azapi_resource.private_dns_forwarding_ruleset, azapi_resource.vnet]

  retry = var.azapi_retry

  type      = "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01"
  name      = each.value.name
  parent_id = azapi_resource.private_dns_forwarding_ruleset[each.value.ruleset].id

  body = {
    properties = {
      virtualNetwork = {
        id = azapi_resource.vnet[local.private_dns_forwarding_ruleset_vnet_key[each.key]].id
      }
    }
  }
}
