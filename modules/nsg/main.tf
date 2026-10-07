module "yaml_processing" {
  source = "../yaml-processing"

  yaml_file         = coalesce(var.yaml_file, "${path.module}/../yaml-processing/config/azure.yaml")
  network_yaml_file = coalesce(var.network_yaml_file, "${path.module}/../yaml-processing/config/network.yaml")
}

# Minimal provider-side lookup: translate the already-resolved subscription
# display_name into its Azure subscription ID. The reference resolution
# (subscription_ref -> subscription -> display_name) is performed by the
# yaml-processing module; this data source only maps the resolved value to
# its Azure ID.
data "azurerm_subscriptions" "available" {}

locals {
  nsg_subscription_id = {
    for name, nsg in module.yaml_processing.nsgs :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == nsg.subscription_display_name && s.state == "Enabled"
    ])
  }
}

check "subscriptions_resolvable" {
  assert {
    condition = alltrue([
      for name, id in local.nsg_subscription_id : id != null
    ])
    error_message = "Unable to resolve the referenced subscription display name to an Azure subscription ID. Verify the subscriptions exist and their display names are unique."
  }
}

# Creates every Network Security Group from the flattened network.yaml data in
# its own subscription/resource group. Security rules are created separately
# below as child resources (subnet association is a later phase).
resource "azapi_resource" "nsg" {
  for_each = module.yaml_processing.nsgs

  type      = "Microsoft.Network/networkSecurityGroups@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.nsg_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {}
}

# Creates every security rule as a child of its parent NSG. The parent_id is
# the direct azapi_resource.nsg reference (rather than a reconstructed string),
# so each rule carries an implicit dependency on its parent NSG — preventing
# 404 errors from rules being created before the NSG is ready.
resource "azapi_resource" "rule" {
  for_each = module.yaml_processing.nsg_rules

  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  name      = each.value.name
  parent_id = azapi_resource.nsg[each.value.nsg_name].id

  body = {
    properties = merge(
      {
        priority        = each.value.priority
        direction       = each.value.direction
        access          = each.value.access
        protocol        = each.value.protocol
        sourcePortRange = each.value.source_port_range
      },
      # "*" and service tags such as "Internet" must use the singular
      # sourceAddressPrefix field. The plural sourceAddressPrefixes field only
      # accepts IP addresses/CIDRs and rejects service tags and "*".
      each.value.source_address_prefixes == ["*"] ? {
        sourceAddressPrefix = "*"
      } : {},
      each.value.source_address_prefixes == ["Internet"] ? {
        sourceAddressPrefix = "Internet"
      } : {},
      each.value.source_address_prefixes != ["*"] && each.value.source_address_prefixes != ["Internet"] ? {
        sourceAddressPrefixes = each.value.source_address_prefixes
      } : {},
      each.value.destination_address_prefixes == ["*"] ? {
        destinationAddressPrefix = "*"
      } : {},
      each.value.destination_address_prefixes != ["*"] ? {
        destinationAddressPrefixes = each.value.destination_address_prefixes
      } : {},
      each.value.destination_port_ranges == ["*"] ? {
        destinationPortRange = "*"
      } : {},
      each.value.destination_port_ranges != ["*"] ? {
        destinationPortRanges = each.value.destination_port_ranges
      } : {}
    )
  }
}