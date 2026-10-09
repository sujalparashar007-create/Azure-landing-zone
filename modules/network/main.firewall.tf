# Creates the feature-gated Azure Firewall, Firewall Policy, and YAML-defined
# rule collection groups.
locals {
  firewall_subscription_id = {
    for name, firewall in module.yaml_processing.firewalls :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == firewall.subscription_display_name && s.state == "Enabled"
    ])
  }

  firewall_policy_subscription_id = {
    for name, policy in module.yaml_processing.firewall_policies :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == policy.subscription_display_name && s.state == "Enabled"
    ])
  }

  firewall_subnet_key = {
    for name, firewall in module.yaml_processing.firewalls :
    name => one([
      for key, subnet in module.yaml_processing.subnets :
      key
      if subnet.name == firewall.subnet &&
      subnet.subscription == firewall.subscription &&
      subnet.resource_group == firewall.resource_group
    ])
  }
}

resource "azapi_resource" "firewall_policy" {
  for_each = module.yaml_processing.firewall_policies

  retry = var.azapi_retry

  type      = "Microsoft.Network/firewallPolicies@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.firewall_policy_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    properties = {
      sku = {
        tier = each.value.sku
      }
    }
  }
}

resource "azapi_resource" "firewall" {
  for_each = module.yaml_processing.firewalls

  depends_on = [azapi_resource.firewall_policy, azapi_resource.public_ip]

  retry = var.azapi_retry

  type      = "Microsoft.Network/azureFirewalls@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.firewall_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    properties = {
      sku = {
        name = each.value.sku_name
        tier = each.value.sku_tier
      }
      threatIntelMode = each.value.threat_intelligence_mode
      firewallPolicy = {
        id = azapi_resource.firewall_policy[each.value.policy].id
      }
      ipConfigurations = [{
        name = "${each.value.name}-ipconfig"
        properties = {
          subnet = {
            id = azapi_resource.subnet[local.firewall_subnet_key[each.key]].id
          }
          publicIPAddress = {
            id = azapi_resource.public_ip[each.value.public_ip].id
          }
          privateIPAddress = each.value.private_ip
        }
      }]
    }
  }
}

resource "azapi_resource" "firewall_policy_group" {
  for_each = module.yaml_processing.firewall_policy_groups

  retry = var.azapi_retry

  type      = "Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-01-01"
  name      = each.value.name
  parent_id = azapi_resource.firewall_policy[each.value.policy_name].id

  body = {
    properties = {
      priority = each.value.priority
      ruleCollections = [
        for collection in each.value.collections : {
          name               = collection.name
          priority           = collection.priority
          ruleCollectionType = collection.type == "nat" ? "FirewallPolicyNatRuleCollection" : "FirewallPolicyFilterRuleCollection"
          action             = collection.type == "nat" ? { type = collection.action } : { type = collection.action }
          rules = [
            for rule in try(collection.rules, []) : merge(
              {
                name                 = rule.name
                ruleType             = collection.type == "nat" ? "NatRule" : "NetworkRule"
                ipProtocols          = tolist(rule.protocols)
                sourceAddresses      = tolist(rule.source_addresses)
                destinationAddresses = collection.type == "nat" ? tolist([azapi_resource.public_ip[rule.destination_public_ip_ref].output.properties.ipAddress]) : tolist(try(rule.destination_addresses, []))
                destinationPorts     = tolist(rule.destination_ports)
              },
              collection.type == "nat" ? {
                translatedAddress = rule.translated_address
                translatedPort    = rule.translated_port
              } : {}
            )
          ]
        } if try(collection.enabled, true)
      ]
    }
  }
}
