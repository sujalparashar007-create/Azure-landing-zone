Work only on modules/yaml-processing/config/network.yaml. No .tf edits, no commits, no apply/destroy. Do NOT delete network.yaml.bak. Re-run git status first and show it.

PART 1 - FIXES (do these before validating)

F1. NSG address fields: make every NSG rule use list form. Convert source_address_prefix -> source_address_prefixes: [..] and destination_address_prefix -> destination_address_prefixes: [..] on ALL rules in security.network_security_groups (values like "*", "Internet", "10.0.2.0/26" stay as list items). Keep destination_port_ranges and source_port_range as they are. Add a comment at the top of the security section stating the list-form convention.

F2. Single source of truth for subnet links: subnets already declare nsg / nat_gateway / route_table. Remove the back-reference `subnet:` field from every entry in security.network_security_groups and from every entry in nat. First verify that each NSG and the NAT gateway is referenced by exactly one subnet (nsg-prod -> snet-hub-shared, nsg-spoke-shared-app, nsg-spoke-shared-data, nsg-spoke-payments-app, nsg-spoke-payments-data; nat-gw-hub -> snet-hub-shared). Report any NSG/NAT that no subnet references or that two subnets reference, and ask me before changing those. Also remove the `nsg: "nsg-prod"` field from the VM (the NSG is attached at subnet level) and keep a comment.

F3. Network Watcher: add `existing: true` to every network_watcher entry with the comment "Azure auto-creates NetworkWatcher_<region> in NetworkWatcherRG per subscription; reference it, do not create it".

F4. Flow logs storage: check current Microsoft docs on whether a Network Watcher VNet flow log can write to a storage account in a DIFFERENT subscription than the VNet (same tenant, same region). Report what you find with the doc source. If cross-subscription is supported, add a comment saying so. If it is NOT supported or unclear, add per-subscription flow log storage accounts: stflowspoke1 style names are not allowed, so use stnetlogsshared (sub-shared-ops / rg-shared-ops) and stnetlogspay (sub-prod-payment / rg-prod-payment-app), same settings as stnetlogshub, and point each spoke flow log at its own subscription's account. Storage names must be 3-24 chars, lowercase letters and digits only.

F5. Add a comment block under `features:` listing dependencies, e.g. firewall=false breaks spoke default routes (10.0.1.4); vpn_gateway=false makes peering use_remote_gateways invalid; dns_resolver=false disables the forwarding ruleset; private_endpoint=false makes stappdatahub unreachable; flow_logs requires network_watcher. Comments only, no logic.

PART 2 - SYNTAX AND VALUE VALIDATION (script lives in %TEMP%, not in the repo)

V1. Strict YAML parse that FAILS on duplicate keys (plain yaml.safe_load silently overwrites duplicates, so use a custom loader or yamllint with key-duplicates). Also check: no tabs, consistent 2-space indentation, no stray non-YAML text, no unquoted values that YAML would convert to booleans or numbers by mistake (yes/no/on/off, versions, "*" must be quoted).
V2. Parse with Terraform's own yamldecode: create a temp folder in %TEMP% with an empty main.tf and run  echo 'yamldecode(file("<absolute path to network.yaml>"))' | terraform console  and confirm it prints without error.
V3. Network value checks with python ipaddress:
  - all CIDRs valid; hub and spoke VNet address spaces do not overlap each other or 192.168.0.0/16
  - every subnet sits inside its VNet address space; no two subnets in the same VNet overlap
  - minimum sizes: GatewaySubnet >= /27, AzureFirewallSubnet >= /26, AzureBastionSubnet >= /26, RouteServerSubnet >= /27, resolver subnets >= /28 and delegated to Microsoft.Network/dnsResolvers
  - firewall private_ip (10.0.1.4) lies inside AzureFirewallSubnet and equals the next hop in all route-table firewall routes
  - NSG rule priorities are unique per NSG and within 100-4096; priorities unique per firewall collection group
  - VPN gateway bgp_asn is not 65515; sku ends in AZ; pips used by AZ resources have zones
  - every public IP is referenced exactly once (firewall, vpn, bastion, nat, route server)
  - storage names: 3-24 chars, lowercase letters and digits only, unique across the file
  - every resource that needs subscription/resource_group has them explicitly or inherits from defaults
V4. Re-run the reference-integrity check from before and print the full table again (reference | where used | resolved? | where defined). Unresolved count must be 0.

PART 3 - REPORT
Give me: (1) a table F1..F5 -> what changed, (2) results of V1..V4 with PASS/FAIL per check, (3) every issue found by V3 that you fixed, and anything you did NOT fix and why, (4) the git diff against network.yaml.bak, (5) the F4 doc source and conclusion. Stop and ask me before making any change that is not described in this prompt.