# Creates the YAML-defined private Linux test VM and its NIC.
locals {
  virtual_machine_subscription_id = {
    for name, vm in module.yaml_processing.virtual_machines :
    name => one([
      for s in data.azapi_resource_list.available.output.subscriptions :
      s.subscription_id
      if s.display_name == vm.subscription_display_name && s.state == "Enabled"
    ])
  }

  virtual_machine_subnet_key = {
    for name, vm in module.yaml_processing.virtual_machines :
    name => one([
      for key, subnet in module.yaml_processing.subnets :
      key
      if subnet.name == vm.subnet &&
      subnet.subscription == vm.subscription &&
      subnet.resource_group == vm.resource_group
    ])
  }
}

resource "azapi_resource" "network_interface" {
  for_each = module.yaml_processing.virtual_machines

  depends_on = [azapi_resource.subnet]

  retry = var.azapi_retry

  type      = "Microsoft.Network/networkInterfaces@2024-01-01"
  name      = "nic-${each.value.name}"
  parent_id = "/subscriptions/${local.virtual_machine_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    properties = {
      ipConfigurations = [{
        name = "ipconfig-${each.value.name}"
        properties = {
          privateIPAllocationMethod = "Dynamic"
          subnet = {
            id = azapi_resource.subnet[local.virtual_machine_subnet_key[each.key]].id
          }
        }
      }]
    }
  }
}

resource "azapi_resource" "virtual_machine" {
  for_each = module.yaml_processing.virtual_machines

  depends_on = [azapi_resource.network_interface]

  retry = var.azapi_retry

  type      = "Microsoft.Compute/virtualMachines@2024-07-01"
  name      = each.value.name
  parent_id = "/subscriptions/${local.virtual_machine_subscription_id[each.key]}/resourceGroups/${each.value.resource_group}"
  location  = each.value.location

  body = {
    properties = {
      hardwareProfile = {
        vmSize = each.value.size
      }
      storageProfile = {
        imageReference = {
          publisher = each.value.image.publisher
          offer     = each.value.image.offer
          sku       = each.value.image.sku
          version   = each.value.image.version
        }
        osDisk = {
          createOption = "FromImage"
          caching      = each.value.os_disk.caching
          managedDisk = {
            storageAccountType = each.value.os_disk.storage_account_type
          }
          diskSizeGB = each.value.os_disk.disk_size_gb
        }
      }
      osProfile = {
        computerName  = each.value.name
        adminUsername = each.value.admin_username
        adminPassword = var.admin_password
        linuxConfiguration = {
          disablePasswordAuthentication = false
        }
      }
      networkProfile = {
        networkInterfaces = [{
          id = azapi_resource.network_interface[each.key].id
          properties = {
            primary = true
          }
        }]
      }
    }
  }
}
