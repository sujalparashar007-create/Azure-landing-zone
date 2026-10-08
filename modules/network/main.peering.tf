# Creates bidirectional VNet peering resources defined by network.yaml.
# The local and remote VNet IDs are resolved from the VNet resources created
# by this module, preserving the YAML-driven references without hard-coded IDs.
resource "azapi_resource" "peering" {
  for_each = module.yaml_processing.peerings

  retry = var.azapi_retry

  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01"
  name      = each.value.name
  parent_id = azapi_resource.vnet[each.value.vnet].id

  body = {
    properties = {
      allowForwardedTraffic = each.value.allow_forwarded_traffic
      allowGatewayTransit   = each.value.allow_gateway_transit
      remoteVirtualNetwork = {
        id = azapi_resource.vnet[each.value.remote_vnet].id
      }
      # Azure rejects useRemoteGateways=true until the remote VNet has a
      # gateway. Keep the YAML value authoritative while deferring that
      # capability until the VPN gateway phase enables it.
      useRemoteGateways = each.value.use_remote_gateways && var.remote_gateways_ready
    }
  }
}
