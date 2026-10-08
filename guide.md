Implement P5 of the Azure Landing Zone Terraform network extension: Public IPs + NAT Gateway.

IMPORTANT:
- Preserve the existing architecture:
  config/network.yaml → modules/yaml-processing → flattened/parsed outputs → modules/network → Azure resources.
- network.yaml remains the single source of truth.
- Do NOT modify or refactor existing P0–P4 implementations.
- Do NOT deploy Azure Firewall, VPN Gateway, Bastion, DNS, Private Endpoint, VM, Flow Logs, Diagnostics, or Route Server in this phase.
- Route Server must remain disabled because features.route_server = false.
- Do not introduce hard-coded subscription IDs, resource group names, VNet names, subnet names, or public IP names in Terraform.
- Resolve subscriptions/resource groups through the existing YAML reference mechanism.
- Follow the existing module/provider/convention used by the VNet, subnet, NSG, NSG-rule, NSG-association, route-table, and peering implementations.
- Use for_each/YAML-driven resources; do not create individually hard-coded resources.
- Do not change unrelated files or existing resources.

P5 scope:

1. Public IPs
Parse/expose network.yaml public_ips through modules/yaml-processing and create the required Public IP resources through modules/network.

Create only the Public IPs that are required for the currently enabled architecture:
- pip-afw-prod
- pip-vpn-gw
- pip-bastion-hub
- pip-nat-hub

Do NOT create:
- pip-rs-hub
because features.route_server = false.

The Public IP resources must use the exact properties defined in network.yaml, including:
- name
- SKU
- allocation method
- zones, where defined
- subscription/resource-group references
- location/tags from the existing YAML/default/reference mechanism.

Do not duplicate these values in Terraform.

2. NAT Gateway
Parse/expose network.yaml NAT configuration and implement the NAT Gateway through modules/network.

Create:
- nat-gw-hub

Use the exact YAML-defined:
- name
- SKU
- subscription/resource-group references
- public IP reference
- location/tags

Associate the NAT Gateway with the YAML-defined subnet:
- vnet-prod-hub / snet-hub-shared

Resolve the subnet and Public IP IDs from the existing YAML-derived/resource maps rather than hard-coding Azure resource IDs.

3. Validation
Add appropriate validation/checks for:
- duplicate Public IP names
- unresolved Public IP references
- unresolved NAT Gateway references
- unresolved subnet references
- duplicate NAT Gateway names
- feature-controlled resources
- Route Server Public IP remaining disabled when features.route_server = false.

4. Outputs
Expose useful Public IP and NAT Gateway IDs/names through the existing network module outputs following the current project convention.

5. Safety / scope
Before implementation, inspect the current code and network.yaml.
Do not overwrite working P0–P4 logic.
Do not change existing VNet, subnet, NSG, NSG rules, NSG associations, route tables, UDRs, or VNet peerings.

After implementation run:
- terraform fmt -recursive
- terraform validate
- terraform plan

Do NOT run terraform apply.

Report:
- files changed
- exact resources Terraform plans to create/change/destroy
- Public IPs created by the plan
- NAT Gateway and subnet association planned
- confirmation that pip-rs-hub is skipped
- confirmation that P0–P4 resources have 0 changes and 0 destroys
- plan summary