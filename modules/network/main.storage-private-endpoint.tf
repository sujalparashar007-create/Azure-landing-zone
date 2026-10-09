# Creates the storage account and Blob private endpoint defined by the
# network.yaml private endpoint configuration.
locals {
  storage_account_subscription_id = {
    for name, storage in module.yaml_processing.private_endpoint_storage_accounts :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == storage.subscription_display_name && s.state == "Enabled"
    ])
  }

  private_endpoint_subscription_id = {
    for name, endpoint in module.yaml_processing.private_endpoints :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == endpoint.subscription_display_name && s.state == "Enabled"
    ])
  }

  private_endpoint_subnet_key = {
    for name, endpoint in module.yaml_processing.private_endpoints :
    name => one([
      for key, subnet in module.yaml_processing.subnets :
      key
      if subnet.name == endpoint.subnet &&
      subnet.subscription == endpoint.subscription &&
      subnet.resource_group == endpoint.resource_group
    ])
  }
}

resource "azapi_resource" "storage_account" {
  for_each = module.yaml_processing.private_endpoint_storage_accounts

  retry = var.azapi_retry

  type      = "Microsoft.Storage/storageAccounts@2023-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.storage_account_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location
  tags      = each.value.tags

  body = {
    sku = {
      name = each.value.sku
    }
    kind = each.value.kind
    properties = merge(
      {
        minimumTlsVersion        = each.value.minimum_tls_version
        publicNetworkAccess      = each.value.public_network_access ? "Enabled" : "Disabled"
        supportsHttpsTrafficOnly = each.value.https_only
        allowBlobPublicAccess    = each.value.allow_nested_items_to_be_public
      },
      each.value.access_tier != null ? {
        accessTier = each.value.access_tier
      } : {}
    )
  }
}

resource "azapi_resource" "private_endpoint" {
  for_each = module.yaml_processing.private_endpoints

  depends_on = [azapi_resource.storage_account, azapi_resource.subnet]

  retry = var.azapi_retry

  type      = "Microsoft.Network/privateEndpoints@2023-05-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.private_endpoint_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    properties = {
      subnet = {
        id = azapi_resource.subnet[local.private_endpoint_subnet_key[each.key]].id
      }
      privateLinkServiceConnections = [{
        name = "${each.value.name}-connection"
        properties = {
          privateLinkServiceId = azapi_resource.storage_account[each.value.target].id
          groupIds             = [each.value.target_subresource]
          requestMessage       = null
          privateLinkServiceConnectionState = {
            status          = each.value.is_manual_connection ? "Pending" : "Approved"
            description     = "Managed by Terraform"
            actionsRequired = "None"
          }
        }
      }]
    }
  }
}

resource "azapi_resource" "private_endpoint_dns_zone_group" {
  for_each = module.yaml_processing.private_endpoints

  depends_on = [azapi_resource.private_endpoint, azapi_resource.private_dns_zone]

  retry = var.azapi_retry

  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01"
  name      = "default"
  parent_id = azapi_resource.private_endpoint[each.key].id

  body = {
    properties = {
      privateDnsZoneConfigs = [{
        name = each.value.private_dns_zone
        properties = {
          privateDnsZoneId = azapi_resource.private_dns_zone[each.value.private_dns_zone].id
        }
      }]
    }
  }
}
