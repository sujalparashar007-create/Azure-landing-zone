# Creates enabled Azure Bastion hosts from network.yaml using existing subnet
# and Public IP resources.
locals {
  bastion_subscription_id = {
    for name, bastion in module.yaml_processing.bastions :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.subscription_id
      if s.display_name == bastion.subscription_display_name && s.state == "Enabled"
    ])
  }

  bastion_subnet_key = {
    for name, bastion in module.yaml_processing.bastions :
    name => one([
      for key, subnet in module.yaml_processing.subnets :
      key
      if subnet.name == bastion.subnet &&
      subnet.subscription == bastion.subscription &&
      subnet.resource_group == bastion.resource_group
    ])
  }
}

resource "azapi_resource" "bastion" {
  for_each = module.yaml_processing.bastions

  depends_on = [azapi_resource.subnet, azapi_resource.public_ip]

  retry = var.azapi_retry

  type      = "Microsoft.Network/bastionHosts@2024-01-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.bastion_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    sku = {
      name = each.value.sku
    }
    properties = {
      disableCopyPaste = !each.value.copy_paste_enabled
      enableFileCopy   = each.value.file_copy_enabled
      enableTunneling  = each.value.tunneling_enabled
      enableIpConnect  = each.value.ip_connect_enabled
      ipConfigurations = [{
        name = "${each.value.name}-ipconfig"
        properties = {
          subnet = {
            id = azapi_resource.subnet[local.bastion_subnet_key[each.key]].id
          }
          publicIPAddress = {
            id = azapi_resource.public_ip[each.value.public_ip].id
          }
        }
      }]
    }
  }
}
