# Network module

This module builds the Azure hub-and-spoke network defined in network.yaml.
It creates VNets, subnets, security, routing, firewall, Bastion, DNS,
private endpoint, storage, and test VM resources through AzAPI.

## Architecture

Flow:

    network.yaml -> modules/yaml-processing (flatten + validate)
                 -> null_resource + for_each
                 -> modules/network (AzAPI)
                 -> Azure

Topology:

    on-prem placeholder 192.168.0.0/16
             | corp DNS 192.168.100.10
    Hub: vnet-prod-hub 10.0.0.0/16, firewall 10.0.1.4
       |-- vnet-spoke-shared 10.1.0.0/16
       |-- vnet-spoke-payments 10.2.0.0/16

Subscriptions and resource groups resolve from network.yaml references:

| Reference | Subscription | Resource group |
|---|---|---|
| network | sub-prod-network | rg-prod-network |
| shared_services | sub-shared-ops | rg-shared-ops |
| payments | sub-prod-payment | rg-prod-payment-app |

subscription_ref and resource_group_ref are flattened by yaml-processing.
Resource parent IDs use the resolved subscription and resource group. VNet,
subnet, NSG, route-table, resolver, and endpoint references are resolved from
the flattened names and parent scope.

### Providers
- AzAPI ~> 2.0 manages every Azure resource in this module.
- AzureRM ~> 4.0 remains declared with provider registration disabled, but no
  azurerm resources or data sources are used.
- Null ~> 3.0 is used by yaml-processing for null_resource.yaml_flatten.
- No Terraform required_version constraint is declared in the inspected files.

## Deployment sequence

This order follows depends_on declarations and resource ID references.

1. data.azapi_resource_list.available discovers enabled subscriptions.
2. module.yaml_processing reads both YAML files, resolves references, validates
   relationships, and creates null_resource.yaml_flatten from YAML hashes.
3. Create vnet-prod-hub, vnet-spoke-shared, and vnet-spoke-payments.
4. Create public IPs, NSGs, route tables, NAT Gateway, firewall policy, private
   DNS zone, and storage account.
5. Create NSG rules, route-table routes, and the firewall policy rule collection.
6. Create subnets. Subnet PUT bodies carry NSG, route-table, NAT, delegation,
   and private-endpoint policy associations.
7. Create the four VNet peerings.
8. Create afw-prod after its policy, public IP, and firewall subnet exist.
9. Create bastion-hub after its public IP and AzureBastionSubnet exist.
10. Create dnspr-hub, then inbound-hub and outbound-hub.
11. Create ruleset-hub-corp, then fwd-corp-example and its three VNet links.
12. Create the private DNS zone's three VNet links.
13. Create pe-stappdata-blob after stappdatahub and snet-shared-data, then its
    default private DNS zone group.
14. Create NICs after VM subnets, then VMs after their NICs.

## Resource reference

### VNets
- What: vnet-prod-hub, 10.0.0.0/16.
- Why: Hub for shared services, firewall, Bastion, resolver, and gateways.
- Where: sub-prod-network / rg-prod-network.
- Connects to: Both spokes; six hub subnets.
- What: vnet-spoke-shared, 10.1.0.0/16.
- Why: Shared services spoke.
- Where: sub-shared-ops / rg-shared-ops.
- Connects to: vnet-prod-hub; snet-shared-app and snet-shared-data.
- What: vnet-spoke-payments, 10.2.0.0/16.
- Why: Payments spoke.
- Where: sub-prod-payment / rg-prod-payment-app.
- Connects to: vnet-prod-hub; snet-payments-app and snet-payments-data.

### Subnets
- What: GatewaySubnet, AzureFirewallSubnet, AzureBastionSubnet, RouteServerSubnet,
  snet-hub-shared, PrivateResolverInbound, PrivateResolverOutbound.
- Why: Hub gateway, firewall, Bastion, resolver, route-server reservation, and VM.
- Where: vnet-prod-hub / sub-prod-network / rg-prod-network.
- Connects to: Gateway route table, firewall, Bastion, resolver, NSG/NAT, and hub VM.
- What: snet-shared-app and snet-shared-data.
- Why: Shared application and private endpoint data networks.
- Where: vnet-spoke-shared / sub-shared-ops / rg-shared-ops.
- Connects to: Shared NSGs and route table; snet-shared-data hosts the PE.
- What: snet-payments-app and snet-payments-data.
- Why: Payments application and data networks.
- Where: vnet-spoke-payments / sub-prod-payment / rg-prod-payment-app.
- Connects to: Payments NSGs and route table; the payments VM uses app.

### NSGs and rules
- What: nsg-prod with allow-bastion-inbound, allow-onprem-mgmt-inbound,
  deny-internet-inbound.
- Why: Protects the hub shared subnet.
- Where: sub-prod-network / rg-prod-network.
- Connects to: Inline association on snet-hub-shared; rules are child resources.
- What: nsg-spoke-shared-app with allow-hub-inbound and deny-internet-inbound.
- Why: Controls shared application ingress.
- Where: sub-shared-ops / rg-shared-ops.
- Connects to: snet-shared-app.
- What: nsg-spoke-shared-data with allow-app-subnet-inbound,
  allow-private-endpoint-inbound, deny-all-other-inbound.
- Why: Controls shared data and private endpoint traffic.
- Where: sub-shared-ops / rg-shared-ops.
- Connects to: snet-shared-data.
- What: nsg-spoke-payments-app with allow-hub-inbound, allow-bastion-ssh,
  deny-internet-inbound.
- Why: Controls payments application ingress and Bastion SSH.
- Where: sub-prod-payment / rg-prod-payment-app.
- Connects to: snet-payments-app.
- What: nsg-spoke-payments-data with allow-app-subnet-inbound and
  deny-all-other-inbound.
- Why: Controls payments data ingress.
- Where: sub-prod-payment / rg-prod-payment-app.
- Connects to: snet-payments-data.

### Routing and peerings
- What: rt-gateway with payments-via-firewall and shared-via-firewall.
- Why: Routes spoke prefixes through firewall IP 10.0.1.4.
- Where: sub-prod-network / rg-prod-network.
- Connects to: GatewaySubnet.
- What: rt-spoke-shared with default-via-firewall and onprem-via-firewall.
- Why: Sends shared spoke internet and on-prem traffic through the firewall.
- Where: sub-shared-ops / rg-shared-ops.
- Connects to: Both shared subnets; next hop 10.0.1.4.
- What: rt-spoke-payments with default-via-firewall and onprem-via-firewall.
- Why: Sends payments spoke internet and on-prem traffic through the firewall.
- Where: sub-prod-payment / rg-prod-payment-app.
- Connects to: Both payments subnets; next hop 10.0.1.4.
- What: peer-hub-to-spoke-shared, peer-spoke-shared-to-hub,
  peer-hub-to-spoke-payments, peer-spoke-payments-to-hub.
- Why: Provides hub-and-spoke VNet connectivity.
- Where: Child resources of their source VNets.
- Connects to: The corresponding remote VNet; forwarded traffic is enabled.

### Public IPs, NAT, firewall, and Bastion
- What: pip-afw-prod, pip-bastion-hub, pip-nat-hub.
- Why: Public front ends for firewall, Bastion, and NAT.
- Where: sub-prod-network / rg-prod-network.
- Connects to: afw-prod, bastion-hub, and nat-gw-hub.
- What: nat-gw-hub.
- Why: SNAT for hub shared VM traffic.
- Where: sub-prod-network / rg-prod-network.
- Connects to: pip-nat-hub and snet-hub-shared.
- What: fwp-prod and rcg-network.
- Why: Firewall network and disabled DNAT collections.
- Where: sub-prod-network / rg-prod-network.
- Connects to: rcg-network is a child of fwp-prod; afw-prod uses the policy.
- What: afw-prod with private IP 10.0.1.4.
- Why: Central firewall and UDR next hop.
- Where: sub-prod-network / rg-prod-network / AzureFirewallSubnet.
- Connects to: pip-afw-prod, fwp-prod, and all firewall next-hop routes.
- What: bastion-hub.
- Why: Browser-based access to private VMs.
- Where: sub-prod-network / rg-prod-network / AzureBastionSubnet.
- Connects to: pip-bastion-hub and Bastion NSG rules.

### DNS and private endpoint
- What: dnspr-hub, inbound-hub, outbound-hub.
- Why: Private DNS Resolver endpoints.
- Where: sub-prod-network / rg-prod-network and resolver subnets.
- Connects to: Hub VNet and delegated resolver subnets.
- What: ruleset-hub-corp, fwd-corp-example, and three VNet links.
- Why: Forwards corp.example.com. to 192.168.100.10:53.
- Where: sub-prod-network / rg-prod-network.
- Connects to: outbound-hub and all three VNets.
- What: privatelink.blob.core.windows.net and three VNet links.
- Why: Private Blob name resolution.
- Where: sub-prod-network / rg-prod-network.
- Connects to: All VNets and the PE zone group.
- What: stappdatahub.
- Why: Private StorageV2 Blob target.
- Where: sub-shared-ops / rg-shared-ops.
- Connects to: pe-stappdata-blob targets its Blob subresource.
- What: pe-stappdata-blob and default DNS zone group.
- Why: Private Blob access and zone registration.
- Where: sub-shared-ops / rg-shared-ops / snet-shared-data.
- Connects to: stappdatahub, subnet, and private DNS zone.

### NICs and VMs
- What: nic-vm-test-hub, nic-vm-test-shared, nic-vm-test-payments.
- Why: Private network interfaces for the test VMs.
- Where: Each VM subscription and resource group.
- Connects to: The YAML subnet; each VM depends on its NIC.
- What: vm-test-hub, vm-test-shared, vm-test-payments.
- Why: Linux validation VMs for hub, shared, and payments.
- Where: network/rg-prod-network, shared_services/rg-shared-ops,
  payments/rg-prod-payment-app.
- Connects to: Private NIC only; no public IP; private or Bastion access.

## Traffic and name-resolution flows
- Hub VM traffic from snet-hub-shared uses nat-gw-hub and pip-nat-hub.
- Spoke default and on-prem routes use firewall next hop 10.0.1.4.
- Bastion uses bastion-hub, pip-bastion-hub, and AzureBastionSubnet.
- The forwarding rule sends corp.example.com. through outbound-hub to 192.168.100.10.
- Blob names use the linked privatelink.blob.core.windows.net zone and PE zone group.

## Verified so far

The following owner-confirmed facts are retained:
- afw-prod provisioning is Succeeded, with private IP 10.0.1.4 and policy fwp-prod.
- All four peerings are Connected and FullyInSync.
- Hub VM egress IP equals pip-nat-hub.
- Spoke VM egress IP equals pip-afw-prod, so spoke internet traffic leaves through the firewall.
- stappdatahub.blob.core.windows.net resolves through privatelink to private IP 10.1.1.4.
- Storage returned HTTP 400, so the path is open; Blob data access was not tested.
- Spoke VMs reach vm-test-hub by ping and TCP 22.
- corp.example.com lookup times out because no DNS server exists at 192.168.100.10; this is expected.

## Inputs and how to run

Required variable names:
- TF_VAR_admin_password — sensitive Linux VM password from the environment.
- yaml_file — optional landing-zone YAML path.
- network_yaml_file — optional network.yaml path.
- azapi_retry — optional AzAPI retry object.
- remote_gateways_ready — optional gateway-transit capability gate.

Never put a password value in YAML, source, outputs, or committed variable files.

Run from modules/network:

    terraform init
    terraform fmt -check -recursive
    terraform validate
    terraform plan

Provider versions are declared in providers.tf and constrained by
.terraform.lock.hcl. Do not run apply, destroy, import, or state-changing commands
as validation.

## Not implemented / intentionally out of scope
- VPN Gateway and Local Network Gateway resources are absent; GatewaySubnet is reserved only.
- Route Server is disabled by features.route_server: false; no Route Server resource exists.
- Network Watcher, flow logs, and firewall diagnostics are deferred and absent.
- DNAT rule dnat-web-to-shared-app is present but disabled.
- 192.168.0.0/16 and 192.168.100.10 are on-prem placeholders; no on-prem resources exist.



