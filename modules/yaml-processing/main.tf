locals {
  # ----------------------------------------------------------
  # Load YAML
  # ----------------------------------------------------------

  landing_zone = yamldecode(file(var.yaml_file))

  # Custom policy YAML lives with the main YAML in this module.
  # It holds the custom policy assignments and the custom policy
  # definitions.
  custom_policy_config = yamldecode(file("${path.module}/config/custom-policy.yaml"))

  # IAM user directory object ids, keyed by sign-in email. Used to resolve
  # external (#EXT#) users whose directory UPN differs from their email.
  users = try(local.landing_zone.users, {})


  # ----------------------------------------------------------
  # Management Group Hierarchy
  #
  # YAML has a maximum of 4 levels:
  #
  # Level 1 → Platform
  # Level 2 → Shared Services / Network / Production
  # Level 3 → Production Network / Production Applications
  # Level 4 → Payments
  # ----------------------------------------------------------

  mg_level_1 = local.landing_zone.management_groups

  mg_level_2 = flatten([
    for mg1 in local.mg_level_1 : [
      for mg2 in try(mg1.children, []) : merge(
        mg2,
        {
          parent = mg1.name
        }
      )
    ]
  ])

  mg_level_3 = flatten([
    for mg2 in local.mg_level_2 : [
      for mg3 in try(mg2.children, []) : merge(
        mg3,
        {
          parent = mg2.name
        }
      )
    ]
  ])

  mg_level_4 = flatten([
    for mg3 in local.mg_level_3 : [
      for mg4 in try(mg3.children, []) : merge(
        mg4,
        {
          parent = mg3.name
        }
      )
    ]
  ])


  # ----------------------------------------------------------
  # All Management Groups
  # ----------------------------------------------------------

  management_groups = concat(
    local.mg_level_1,
    local.mg_level_2,
    local.mg_level_3,
    local.mg_level_4
  )


  # ----------------------------------------------------------
  # Subscriptions
  # ----------------------------------------------------------

  subscriptions = flatten([
    for mg in local.management_groups : [
      for sub in try(mg.subscriptions, []) : merge(
        sub,
        {
          management_group = mg.name
        }
      )
    ]
  ])


  # ----------------------------------------------------------
  # Resource Groups
  # ----------------------------------------------------------

  resource_groups = flatten([
    for sub in local.subscriptions : [
      for rg in try(sub.resource_groups, []) : merge(
        rg,
        {
          subscription = sub.name
        }
      )
    ]
  ])

  # ----------------------------------------------------------
  # IAM assignments
  #
  # Principals are kept as user principal names (UPNs), for
  # example azure-security@example.com. The IAM module resolves
  # each UPN to an Entra ID user object ID.
  # ----------------------------------------------------------

  tenant_iam = flatten([
    for role, principals in try(coalesce(try(local.landing_zone.tenant.iam, null), {}), {}) : [
      for principal in principals : {
        scope_type = "management_group"
        scope_name = "tenant-root"
        role       = role
        principal  = principal
      }
    ]
  ])

  management_group_iam = flatten([
    for mg in local.management_groups : [
      for role, principals in try(coalesce(try(mg.iam, null), {}), {}) : [
        for principal in principals : {
          scope_type = "management_group"
          scope_name = mg.name
          role       = role
          principal  = principal
        }
      ]
    ]
  ])

  subscription_iam = flatten([
    for sub in local.subscriptions : [
      for role, principals in try(coalesce(try(sub.iam, null), {}), {}) : [
        for principal in principals : {
          scope_type = "subscription"
          scope_name = sub.name
          role       = role
          principal  = principal
        }
      ]
    ]
  ])

  resource_group_iam = flatten([
    for rg in local.resource_groups : [
      for role, principals in try(coalesce(try(rg.iam, null), {}), {}) : [
        for principal in principals : {
          scope_type = "resource_group"
          scope_name = "${rg.subscription}/${rg.name}"
          role       = role
          principal  = principal
        }
      ]
    ]
  ])

  iam_assignments = concat(
    local.tenant_iam,
    local.management_group_iam,
    local.subscription_iam,
    local.resource_group_iam
  )

  iam_assignments_map = {
    for assignment in local.iam_assignments :
    "${assignment.scope_type}/${assignment.scope_name}/${assignment.role}/${assignment.principal}" => assignment
  }

  features = try(local.network_config.features, {})

  public_ip_definitions = try(local.network_config.public_ips, [])

  enabled_public_ip_names = toset(concat(
    try(local.features.firewall, false) ? [
      for gateway in try(local.network_config.gateways.firewall, []) : gateway.public_ip
    ] : [],
    try(local.features.vpn_gateway, false) ? [
      for gateway in try(local.network_config.gateways.vpn_gateway, []) : gateway.public_ip
    ] : [],
    try(local.features.bastion, false) ? [
      for bastion in try(local.network_config.gateways.bastion, []) : bastion.public_ip
    ] : [],
    try(local.features.nat_gateway, false) ? [
      for nat_gateway in try(local.network_config.nat, []) : nat_gateway.public_ip
    ] : [],
    try(local.features.route_server, false) ? [
      for route_server in try(local.network_config.routing.route_server, []) : route_server.public_ip
    ] : []
  ))

  public_ips = {
    for public_ip in local.public_ip_definitions :
    public_ip.name => {
      name           = public_ip.name
      location       = try(public_ip.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(public_ip.subscription_ref, public_ip.subscription)], public_ip.subscription)
      resource_group = try(local.resource_group_refs[try(public_ip.resource_group_ref, public_ip.resource_group)], public_ip.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(public_ip.subscription_ref, public_ip.subscription)], public_ip.subscription)].display_name,
        null
      )
      sku        = public_ip.sku
      allocation = public_ip.allocation
      zones      = try(public_ip.zones, [])
      tags       = try(public_ip.tags, local.network_config.defaults.tags)
    }
    if contains(local.enabled_public_ip_names, public_ip.name)
  }

  nat_gateway_definitions = try(local.network_config.nat, [])

  nat_gateways = {
    for nat_gateway in local.nat_gateway_definitions :
    nat_gateway.name => {
      name           = nat_gateway.name
      location       = try(nat_gateway.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(nat_gateway.subscription_ref, nat_gateway.subscription)], nat_gateway.subscription)
      resource_group = try(local.resource_group_refs[try(nat_gateway.resource_group_ref, nat_gateway.resource_group)], nat_gateway.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(nat_gateway.subscription_ref, nat_gateway.subscription)], nat_gateway.subscription)].display_name,
        null
      )
      sku       = nat_gateway.sku
      public_ip = nat_gateway.public_ip
      tags      = try(nat_gateway.tags, local.network_config.defaults.tags)
    }
    if try(local.features.nat_gateway, false)
  }

  bastion_definitions = try(local.network_config.gateways.bastion, [])

  bastions = {
    for bastion in local.bastion_definitions :
    bastion.name => {
      name           = bastion.name
      location       = try(bastion.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(bastion.subscription_ref, bastion.subscription)], bastion.subscription)
      resource_group = try(local.resource_group_refs[try(bastion.resource_group_ref, bastion.resource_group)], bastion.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(bastion.subscription_ref, bastion.subscription)], bastion.subscription)].display_name,
        null
      )
      sku                = bastion.sku
      subnet             = bastion.subnet
      public_ip          = bastion.public_ip
      copy_paste_enabled = try(bastion.copy_paste_enabled, false)
      file_copy_enabled  = try(bastion.file_copy_enabled, false)
      tunneling_enabled  = try(bastion.tunneling_enabled, false)
      ip_connect_enabled = try(bastion.ip_connect_enabled, false)
      enabled            = try(local.features.bastion, false)
    }
    if try(local.features.bastion, false)
  }

  private_dns_resolvers = {
    for resolver in try(local.network_config.dns.private_dns_resolver, []) :
    resolver.name => {
      name           = resolver.name
      location       = try(resolver.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(resolver.subscription_ref, resolver.subscription)], resolver.subscription)
      resource_group = try(local.resource_group_refs[try(resolver.resource_group_ref, resolver.resource_group)], resolver.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(resolver.subscription_ref, resolver.subscription)], resolver.subscription)].display_name,
        null
      )
      vnet = resolver.vnet
      tags = try(resolver.tags, local.network_config.defaults.tags)
    }
  }

  private_dns_resolver_inbound_endpoints = {
    for endpoint in try(local.network_config.dns.resolver_endpoints.inbound, []) :
    endpoint.name => {
      name                  = endpoint.name
      resolver              = endpoint.resolver
      subnet                = endpoint.subnet
      private_ip_allocation = endpoint.private_ip_allocation
    }
  }

  private_dns_resolver_outbound_endpoints = {
    for endpoint in try(local.network_config.dns.resolver_endpoints.outbound, []) :
    endpoint.name => {
      name     = endpoint.name
      resolver = endpoint.resolver
      subnet   = endpoint.subnet
    }
  }

  private_dns_forwarding_rulesets = {
    for ruleset in try(local.network_config.dns.forwarding_rulesets, []) :
    ruleset.name => {
      name           = ruleset.name
      location       = try(ruleset.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(ruleset.subscription_ref, ruleset.subscription)], ruleset.subscription)
      resource_group = try(local.resource_group_refs[try(ruleset.resource_group_ref, ruleset.resource_group)], ruleset.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(ruleset.subscription_ref, ruleset.subscription)], ruleset.subscription)].display_name,
        null
      )
      outbound_endpoint = ruleset.outbound_endpoint
      tags              = try(ruleset.tags, local.network_config.defaults.tags)
    }
  }

  private_dns_forwarding_rules = merge([
    for ruleset in try(local.network_config.dns.forwarding_rulesets, []) : {
      for rule in try(ruleset.forwarding_rules, []) :
      "${ruleset.name}/${rule.name}" => {
        name               = rule.name
        ruleset            = ruleset.name
        domain_name        = rule.domain_name
        enabled            = rule.enabled
        target_dns_servers = rule.target_dns_servers
      }
    }
  ]...)

  private_dns_forwarding_ruleset_vnet_links = merge([
    for ruleset in try(local.network_config.dns.forwarding_rulesets, []) : {
      for vnet in try(ruleset.vnet_links, []) :
      "${ruleset.name}/${vnet.vnet}" => {
        name    = vnet.vnet
        ruleset = ruleset.name
        vnet    = vnet.vnet
      }
    }
  ]...)

  private_dns_zones = {
    for zone in try(local.network_config.dns.private_dns_zones, []) :
    zone.name => {
      name           = zone.name
      subscription   = try(local.subscription_refs[try(zone.subscription_ref, zone.subscription)], zone.subscription)
      resource_group = try(local.resource_group_refs[try(zone.resource_group_ref, zone.resource_group)], zone.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(zone.subscription_ref, zone.subscription)], zone.subscription)].display_name,
        null
      )
      tags = try(zone.tags, local.network_config.defaults.tags)
      vnet_links = try([
        for link in zone.vnet_links : link.vnet
      ], [])
    }
  }

  private_dns_zone_vnet_links = merge([
    for zone in try(local.network_config.dns.private_dns_zones, []) : {
      for link in try(zone.vnet_links, []) :
      "${zone.name}/${link.vnet}" => {
        name = link.vnet
        zone = zone.name
        vnet = link.vnet
      }
    }
  ]...)

  storage_accounts = {
    for storage in try(local.network_config.monitoring.storage_accounts, []) :
    storage.name => {
      name           = storage.name
      location       = try(storage.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(storage.subscription_ref, storage.subscription)], storage.subscription)
      resource_group = try(local.resource_group_refs[try(storage.resource_group_ref, storage.resource_group)], storage.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(storage.subscription_ref, storage.subscription)], storage.subscription)].display_name,
        null
      )
      sku                             = storage.sku
      kind                            = storage.kind
      access_tier                     = try(storage.access_tier, null)
      https_only                      = try(storage.https_only, true)
      minimum_tls_version             = try(storage.minimum_tls_version, "TLS1_2")
      public_network_access           = try(storage.public_network_access_enabled, true)
      allow_nested_items_to_be_public = try(storage.allow_nested_items_to_be_public, false)
      tags                            = try(storage.tags, local.network_config.defaults.tags)
    }
  }

  private_endpoints = {
    for endpoint in try(local.network_config.private_endpoints, []) :
    endpoint.name => {
      name           = endpoint.name
      location       = try(endpoint.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(endpoint.subscription_ref, endpoint.subscription)], endpoint.subscription)
      resource_group = try(local.resource_group_refs[try(endpoint.resource_group_ref, endpoint.resource_group)], endpoint.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(endpoint.subscription_ref, endpoint.subscription)], endpoint.subscription)].display_name,
        null
      )
      target               = endpoint.target
      target_subresource   = endpoint.target_subresource
      subnet               = endpoint.subnet
      private_dns_zone     = endpoint.private_dns_zone
      is_manual_connection = try(endpoint.is_manual_connection, false)
    }
  }

  private_endpoint_storage_accounts = {
    for endpoint in local.private_endpoints :
    endpoint.target => local.storage_accounts[endpoint.target]
  }

  firewall_definitions = try(local.network_config.gateways.firewall, [])

  firewalls = {
    for firewall in local.firewall_definitions :
    firewall.name => {
      name           = firewall.name
      location       = try(firewall.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(firewall.subscription_ref, firewall.subscription)], firewall.subscription)
      resource_group = try(local.resource_group_refs[try(firewall.resource_group_ref, firewall.resource_group)], firewall.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(firewall.subscription_ref, firewall.subscription)], firewall.subscription)].display_name,
        null
      )
      sku_name                 = firewall.sku_name
      sku_tier                 = firewall.sku_tier
      threat_intelligence_mode = firewall.threat_intelligence_mode
      subnet                   = firewall.subnet
      public_ip                = firewall.public_ip
      private_ip               = firewall.private_ip
      policy                   = firewall.policy
      enabled                  = try(local.features.firewall, false)
    }
    if try(local.features.firewall, false)
  }

  firewall_policy_definitions = try(local.network_config.gateways.firewall_policy, [])

  firewall_policies = {
    for policy in local.firewall_policy_definitions :
    policy.name => {
      name           = policy.name
      location       = try(policy.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(policy.subscription_ref, policy.subscription)], policy.subscription)
      resource_group = try(local.resource_group_refs[try(policy.resource_group_ref, policy.resource_group)], policy.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(policy.subscription_ref, policy.subscription)], policy.subscription)].display_name,
        null
      )
      sku                    = policy.sku
      rule_collection_groups = try(policy.rule_collection_groups, [])
      enabled                = try(local.features.firewall, false)
    }
    if try(local.features.firewall, false)
  }

  firewall_policy_groups = merge([
    for policy_name, policy in local.firewall_policies : {
      for group in policy.rule_collection_groups :
      "${policy_name}/${group.name}" => {
        name        = group.name
        policy_name = policy_name
        priority    = group.priority
        collections = try(group.collections, [])
      }
    }
  ]...)


  # ----------------------------------------------------------
  # Policies (tenant-level + every management group level)
  #
  # Built-in policies live in the main YAML (azure.yaml).
  # Custom policies live in config/custom-policy.yaml.
  # Each policy lives wherever it applies (tenant root or a
  # specific management group), so we walk all sources and tag
  # each entry with its scope.
  #
  # The "== null ? [] :" checks keep this working even when a
  # policies: key is missing or left empty in the YAML.
  # ----------------------------------------------------------

  tenant_policies = [
    for p in try(local.landing_zone.tenant.policies, []) : merge(
      p,
      {
        scope_type  = "management_group"
        scope_name  = "tenant-root"
        policy_type = "built-in"
      }
    )
  ]

  mg_policies = flatten([
    for mg in local.management_groups : [
      for p in try(mg.policies, []) : merge(
        p,
        {
          scope_type  = "management_group"
          scope_name  = mg.name
          policy_type = "built-in"
        }
      )
    ]
  ])

  custom_tenant_policies = [
    for p in try(local.custom_policy_config.tenant.policies, []) : merge(
      p,
      {
        scope_type  = "management_group"
        scope_name  = "tenant-root"
        policy_type = "custom"
      }
    )
  ]

  custom_mg_policies = flatten([
    for mg in try(local.custom_policy_config.management_groups, []) : [
      for p in try(mg.policies, []) : merge(
        p,
        {
          scope_type  = "management_group"
          scope_name  = mg.name
          policy_type = "custom"
        }
      )
    ]
  ])

  all_policies_raw = concat(
    local.tenant_policies,
    local.mg_policies,
    local.custom_tenant_policies,
    local.custom_mg_policies
  )

  custom_policy_definitions = try(local.custom_policy_config.custom_policy_definitions, {})

  # ----------------------------------------------------------
  # Policy type (built-in vs custom)
  #
  # The type is carried through from the source YAML: policies in
  # azure.yaml are built-in, policies in custom-policy.yaml are
  # custom. No name-based allowlist is required.
  # ----------------------------------------------------------

  all_policies = [
    for p in local.all_policies_raw : {
      name                  = p.name
      definition            = p.definition
      scope_type            = p.scope_type
      scope_name            = p.scope_name
      effect                = try(p.effect, "Deny")
      parameters            = try(p.parameters, {})
      display_name          = try(local.custom_policy_definitions[p.definition].display_name, null)
      policy_rule           = try(local.custom_policy_definitions[p.definition].policy_rule, null)
      definition_parameters = try(local.custom_policy_definitions[p.definition].parameters, null)
      policy_type           = p.policy_type
    }
  ]


  # ----------------------------------------------------------
  # Split into built-in vs custom, converted to maps
  # ----------------------------------------------------------

  builtin_policies = [
    for p in local.all_policies : p if p.policy_type == "built-in"
  ]

  custom_policies = [
    for p in local.all_policies : p if p.policy_type == "custom"
  ]

  builtin_policies_map = {
    for p in local.builtin_policies :
    "${p.scope_name}-${p.name}" => p
  }

  custom_policies_map = {
    for p in local.custom_policies :
    "${p.scope_name}-${p.name}" => p
  }


  # ----------------------------------------------------------
  # Convert to maps
  #
  # Maps make it easier for future modules to use for_each.
  # ----------------------------------------------------------

  management_groups_map = {
    for mg in local.management_groups :
    mg.name => mg
  }

  subscriptions_map = {
    for sub in local.subscriptions :
    sub.name => sub
  }

  resource_groups_map = {
    for rg in local.resource_groups :
    "${rg.subscription}/${rg.name}" => rg
  }

  # ----------------------------------------------------------
  # Budgets
  #
  # Budget definitions live under tenant.budgets; subscriptions
  # reference them by name via budget_references. Flatten each
  # reference into a standalone budget instance.
  # ----------------------------------------------------------

  budget_definitions = {
    for name, b in try(local.landing_zone.tenant.budgets, {}) :
    name => merge(
      b,
      {
        contact_emails = flatten([
          for n in try(b.notifications, []) : n.recipients
        ])
      }
    )
  }

  budgets = flatten([
    for sub in local.subscriptions : [
      for ref in try(sub.budget_references, []) : merge(
        local.budget_definitions[ref],
        {
          budget_name  = ref
          subscription = sub.name
        }
      )
    ]
  ])

  budgets_map = {
    for b in local.budgets :
    "${b.subscription}/${b.budget_name}" => b
  }


  # ----------------------------------------------------------
  # Network YAML (incremental processing)
  #
  # network.yaml is consumed phase-by-phase. Phase 1 flattens
  # ONLY the Virtual Network data (hub + spokes). Subnets and
  # all other network resources are handled by later phases.
  #
  # Subscriptions and resource groups that already exist in the
  # ALZ (defined in azure.yaml) are referenced by logical key
  # (subscription_ref / resource_group_ref) and resolved here
  # against the flattened azure.yaml data.
  # ----------------------------------------------------------

  network_config = yamldecode(file(var.network_yaml_file))

  subscription_refs   = try(local.network_config.references.subscriptions, {})
  resource_group_refs = try(local.network_config.references.resource_groups, {})

  hub_vnet = {
    name           = local.network_config.network.hub.vnet
    location       = local.network_config.network.hub.location
    address_space  = local.network_config.network.hub.address_space
    subscription   = try(local.subscription_refs[local.network_config.network.hub.subscription_ref], null)
    resource_group = try(local.resource_group_refs[local.network_config.network.hub.resource_group_ref], null)
    subscription_display_name = try(
      local.subscriptions_map[local.subscription_refs[local.network_config.network.hub.subscription_ref]].display_name,
      null
    )
    subnets = local.network_config.network.hub.subnets
  }

  spoke_vnets = {
    for sp in try(local.network_config.network.spokes, []) :
    sp.name => {
      name           = sp.name
      location       = sp.location
      address_space  = sp.address_space
      subscription   = try(local.subscription_refs[sp.subscription_ref], null)
      resource_group = try(local.resource_group_refs[sp.resource_group_ref], null)
      subscription_display_name = try(
        local.subscriptions_map[local.subscription_refs[sp.subscription_ref]].display_name,
        null
      )
      subnets = sp.subnets
    }
  }

  vnets = merge({ (local.hub_vnet.name) = local.hub_vnet }, local.spoke_vnets)

  raw_peerings = try(local.network_config.connectivity.peerings, [])

  peerings = {
    for peering in local.raw_peerings :
    peering.name => {
      name                    = peering.name
      vnet                    = peering.vnet
      remote_vnet             = peering.remote_vnet
      allow_forwarded_traffic = peering.allow_forwarded_traffic
      allow_gateway_transit   = peering.allow_gateway_transit
      use_remote_gateways     = peering.use_remote_gateways
    }
  }

  # Flatten every subnet (hub + spokes) into a single map keyed by
  # "vnet/subnet". Each entry inherits the resolved subscription and resource
  # group of its parent VNet. route_table / nsg / nat_gateway are carried as
  # metadata for later phases.
  subnets = merge([
    for vnet_key, vnet in local.vnets :
    {
      for s in try(vnet.subnets, []) :
      "${vnet.name}/${s.name}" => {
        name                              = s.name
        vnet_name                         = vnet.name
        address_prefix                    = s.address_prefix
        subscription                      = vnet.subscription
        resource_group                    = vnet.resource_group
        subscription_display_name         = vnet.subscription_display_name
        route_table                       = try(s.route_table, null)
        nsg                               = try(s.nsg, null)
        nat_gateway                       = try(s.nat_gateway, null)
        delegation                        = try(s.delegation, null)
        private_endpoint_network_policies = try(s.private_endpoint_network_policies, null)
      }
    }
  ]...)

  # Flatten route tables and resolve their subscription/resource group values
  # through the same references used by the VNet and NSG data.
  route_tables = {
    for rt in try(local.network_config.routing.route_tables, []) :
    rt.name => {
      name           = rt.name
      location       = try(rt.location, local.network_config.defaults.location)
      subscription   = try(local.subscription_refs[try(rt.subscription_ref, rt.subscription)], rt.subscription)
      resource_group = try(local.resource_group_refs[try(rt.resource_group_ref, rt.resource_group)], rt.resource_group)
      subscription_display_name = try(
        local.subscriptions_map[try(local.subscription_refs[try(rt.subscription_ref, rt.subscription)], rt.subscription)].display_name,
        null
      )
      bgp_route_propagation_enabled = try(rt.bgp_route_propagation_enabled, true)
      routes                        = try(rt.routes, [])
    }
  }

  route_table_routes = merge([
    for route_table_name, route_table in local.route_tables :
    {
      for route in route_table.routes :
      "${route_table_name}/${route.name}" => {
        name                = route.name
        route_table_name    = route_table_name
        address_prefix      = route.address_prefix
        next_hop_type       = route.next_hop_type
        next_hop_ip_address = try(route.next_hop_ip_address, null)
      }
    }
  ]...)

  # Flatten every Network Security Group (P3) and its security rules. Each
  # NSG resolves its subscription/resource group via the same references
  # mechanism; rules inherit the parent NSG's subscription/resource group.
  nsgs = {
    for nsg in try(local.network_config.security.network_security_groups, []) :
    nsg.name => {
      name           = nsg.name
      location       = nsg.location
      subscription   = try(local.subscription_refs[nsg.subscription_ref], null)
      resource_group = try(local.resource_group_refs[nsg.resource_group_ref], null)
      subscription_display_name = try(
        local.subscriptions_map[local.subscription_refs[nsg.subscription_ref]].display_name,
        null
      )
      rules = try(nsg.rules, [])
    }
  }

  nsg_rules = merge([
    for nsg_key, nsg in local.nsgs :
    {
      for r in try(nsg.rules, []) :
      "${nsg.name}/${r.name}" => {
        name                         = r.name
        nsg_name                     = nsg.name
        resource_group               = nsg.resource_group
        priority                     = r.priority
        direction                    = r.direction
        access                       = r.access
        protocol                     = r.protocol
        source_address_prefixes      = r.source_address_prefixes
        source_port_range            = r.source_port_range
        destination_address_prefixes = r.destination_address_prefixes
        destination_port_ranges      = r.destination_port_ranges
      }
    }
  ]...)

  # Flatten NSG-to-subnet associations. Every subnet that references an NSG by
  # name becomes an association keyed by "vnet/subnet". The NSG module consumes
  # this to associate each NSG with its subnet without hard-coding Azure IDs.
  nsg_subnet_associations = {
    for key, subnet in local.subnets :
    key => subnet
    if subnet.nsg != null
  }

  route_table_subnet_associations = {
    for key, subnet in local.subnets :
    key => subnet
    if subnet.route_table != null
  }

  nat_gateway_subnet_associations = {
    for key, subnet in local.subnets :
    key => subnet
    if subnet.nat_gateway != null
  }

}

check "public_ip_definitions_valid" {
  assert {
    condition     = length(local.public_ip_definitions) == length(distinct([for public_ip in local.public_ip_definitions : public_ip.name]))
    error_message = "Public IP names must be unique in network.yaml."
  }

  assert {
    condition = alltrue([
      for public_ip in local.public_ips :
      public_ip.subscription != null &&
      public_ip.resource_group != null &&
      public_ip.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${public_ip.subscription}/${public_ip.resource_group}")
    ])
    error_message = "Every enabled Public IP must reference a subscription and resource group that exist in azure.yaml."
  }
}

check "public_ip_feature_references_resolve" {
  assert {
    condition = alltrue([
      for public_ip_name in local.enabled_public_ip_names :
      contains([for public_ip in local.public_ip_definitions : public_ip.name], public_ip_name)
    ])
    error_message = "Every enabled network feature must reference a Public IP defined in network.yaml."
  }

  assert {
    condition = !try(local.features.route_server, false) || alltrue([
      for route_server in try(local.network_config.routing.route_server, []) :
      contains(keys(local.public_ips), route_server.public_ip)
    ])
    error_message = "Route Server Public IPs must be defined only when features.route_server is enabled."
  }

  assert {
    condition = try(local.features.route_server, false) || alltrue([
      for route_server in try(local.network_config.routing.route_server, []) :
      !contains(keys(local.public_ips), route_server.public_ip)
    ])
    error_message = "Route Server Public IPs must remain disabled while features.route_server is false."
  }
}

check "nat_gateway_definitions_valid" {
  assert {
    condition     = length(local.nat_gateway_definitions) == length(distinct([for nat_gateway in local.nat_gateway_definitions : nat_gateway.name]))
    error_message = "NAT Gateway names must be unique in network.yaml."
  }

  assert {
    condition = alltrue([
      for nat_gateway in local.nat_gateways :
      nat_gateway.subscription != null &&
      nat_gateway.resource_group != null &&
      nat_gateway.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${nat_gateway.subscription}/${nat_gateway.resource_group}") &&
      contains(keys(local.public_ips), nat_gateway.public_ip)
    ])
    error_message = "Every enabled NAT Gateway must resolve its subscription, resource group, and Public IP reference."
  }
}

check "nat_gateway_subnet_references_resolve" {
  assert {
    condition = alltrue([
      for key, subnet in local.subnets :
      subnet.nat_gateway == null ||
      (contains(keys(local.nat_gateways), subnet.nat_gateway) &&
        local.nat_gateways[subnet.nat_gateway].subscription == subnet.subscription &&
      local.nat_gateways[subnet.nat_gateway].resource_group == subnet.resource_group)
    ])
    error_message = "Every subnet NAT Gateway reference must resolve to an enabled NAT Gateway in the same subscription and resource group."
  }
}

check "bastion_definitions_valid" {
  assert {
    condition     = length(local.bastion_definitions) == length(distinct([for bastion in local.bastion_definitions : bastion.name]))
    error_message = "Bastion names must be unique in network.yaml."
  }

  assert {
    condition = alltrue([
      for bastion in local.bastions :
      bastion.subscription != null &&
      bastion.resource_group != null &&
      bastion.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${bastion.subscription}/${bastion.resource_group}") &&
      contains(keys(local.public_ips), bastion.public_ip) &&
      contains([
        for subnet in local.subnets :
        "${subnet.subscription}/${subnet.resource_group}/${subnet.name}"
      ], "${bastion.subscription}/${bastion.resource_group}/${bastion.subnet}")
    ])
    error_message = "Every enabled Bastion must resolve its subscription, resource group, Public IP, and subnet references."
  }
}

check "firewall_definitions_valid" {
  assert {
    condition     = length(local.firewall_definitions) == length(distinct([for firewall in local.firewall_definitions : firewall.name]))
    error_message = "Firewall names must be unique in network.yaml."
  }

  assert {
    condition = alltrue([
      for firewall in local.firewalls :
      firewall.subscription != null &&
      firewall.resource_group != null &&
      firewall.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${firewall.subscription}/${firewall.resource_group}") &&
      contains(keys(local.public_ips), firewall.public_ip) &&
      contains([for subnet in local.subnets : subnet.name], firewall.subnet) &&
      contains(keys(local.firewall_policies), firewall.policy)
    ])
    error_message = "Every enabled Firewall must resolve its subscription, resource group, Public IP, subnet, and Firewall Policy references."
  }
}

check "firewall_policy_definitions_valid" {
  assert {
    condition     = length(local.firewall_policy_definitions) == length(distinct([for policy in local.firewall_policy_definitions : policy.name]))
    error_message = "Firewall Policy names must be unique in network.yaml."
  }

  assert {
    condition = alltrue([
      for policy in local.firewall_policies :
      policy.subscription != null &&
      policy.resource_group != null &&
      policy.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${policy.subscription}/${policy.resource_group}")
    ])
    error_message = "Every enabled Firewall Policy must reference an existing subscription and resource group."
  }
}

check "firewall_policy_group_definitions_valid" {
  assert {
    condition = length(flatten([
      for policy in local.firewall_policy_definitions :
      [for group in try(policy.rule_collection_groups, []) : "${policy.name}/${group.name}"]
      ])) == length(distinct(flatten([
        for policy in local.firewall_policy_definitions :
        [for group in try(policy.rule_collection_groups, []) : "${policy.name}/${group.name}"]
    ])))
    error_message = "Firewall Policy rule collection group names must be unique within each policy."
  }
}


# ----------------------------------------------------------
# Validate network.yaml references resolve to existing ALZ
# subscriptions and resource groups.
# ----------------------------------------------------------

check "network_references_resolve" {
  assert {
    condition = alltrue([
      for key, vnet in local.vnets :
      vnet.subscription != null &&
      vnet.resource_group != null &&
      vnet.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${vnet.subscription}/${vnet.resource_group}")
    ])
    error_message = "Every network resource must reference a subscription and resource group that exist in azure.yaml, and the resource group must belong to the referenced subscription."
  }
}

check "peering_definitions_valid" {
  assert {
    condition     = length(local.raw_peerings) == length(local.peerings)
    error_message = "VNet peering names must be unique in network.yaml."
  }

  assert {
    condition = length(distinct([
      for peering in local.raw_peerings :
      "${peering.vnet}/${peering.remote_vnet}"
    ])) == length(local.raw_peerings)
    error_message = "Duplicate local-to-remote VNet peering definitions are not allowed in network.yaml."
  }

  assert {
    condition = alltrue([
      for peering in local.peerings :
      peering.name != "" &&
      peering.vnet != "" &&
      peering.remote_vnet != "" &&
      peering.vnet != peering.remote_vnet
    ])
    error_message = "Every VNet peering must have a unique name, distinct local and remote VNet references, and both references must be non-empty."
  }
}

check "peering_vnet_references_resolve" {
  assert {
    condition = alltrue([
      for peering in local.peerings :
      contains(keys(local.vnets), peering.vnet)
    ])
    error_message = "Every VNet peering local VNet reference must resolve to a VNet defined in network.yaml."
  }

  assert {
    condition = alltrue([
      for peering in local.peerings :
      contains(keys(local.vnets), peering.remote_vnet)
    ])
    error_message = "Every VNet peering remote VNet reference must resolve to a VNet defined in network.yaml."
  }
}

# ----------------------------------------------------------
# Validate network.yaml NSG references resolve to existing
# ALZ subscriptions and resource groups.
# ----------------------------------------------------------

check "nsg_references_resolve" {
  assert {
    condition = alltrue([
      for key, nsg in local.nsgs :
      nsg.subscription != null &&
      nsg.resource_group != null &&
      nsg.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${nsg.subscription}/${nsg.resource_group}")
    ])
    error_message = "Every network security group must reference a subscription and resource group that exist in azure.yaml, and the resource group must belong to the referenced subscription."
  }
}

# ----------------------------------------------------------
# Validate every NSG-to-subnet association references an NSG
# that exists in network.yaml and lives in the same subscription
# as the subnet it protects.
# ----------------------------------------------------------

check "nsg_subnet_associations_resolve" {
  assert {
    condition = alltrue([
      for key, assoc in local.nsg_subnet_associations :
      contains(keys(local.nsgs), assoc.nsg) &&
      try(local.nsgs[assoc.nsg].subscription, null) == assoc.subscription
    ])
    error_message = "Every subnet that references an NSG must reference an NSG that exists in network.yaml's security.network_security_groups section and lives in the same subscription."
  }
}

# ----------------------------------------------------------
# Validate route tables and route-table-to-subnet associations.
# ----------------------------------------------------------

check "route_table_references_resolve" {
  assert {
    condition = alltrue([
      for key, route_table in local.route_tables :
      route_table.subscription != null &&
      route_table.resource_group != null &&
      route_table.subscription_display_name != null &&
      contains(keys(local.resource_groups_map), "${route_table.subscription}/${route_table.resource_group}")
    ])
    error_message = "Every route table must reference a subscription and resource group that exist in azure.yaml, and the resource group must belong to the referenced subscription."
  }
}

check "route_table_subnet_associations_resolve" {
  assert {
    condition = alltrue([
      for key, assoc in local.route_table_subnet_associations :
      contains(keys(local.route_tables), assoc.route_table) &&
      local.route_tables[assoc.route_table].subscription == assoc.subscription &&
      local.route_tables[assoc.route_table].resource_group == assoc.resource_group
    ])
    error_message = "Every subnet that references a route table must reference a route table that exists in network.yaml and lives in the same subscription and resource group."
  }
}

# ----------------------------------------------------------
# Required null_resource
#
# This does NOT create an Azure resource.
#
# It tracks the YAML + flattened configuration so Terraform
# knows when the processing layer has changed.
# ----------------------------------------------------------

resource "null_resource" "yaml_flatten" {
  triggers = {
    yaml_file_hash         = filesha256(var.yaml_file)
    network_yaml_file_hash = filesha256(var.network_yaml_file)

    flattened_configuration_hash = sha256(
      jsonencode({
        management_groups = local.management_groups
        subscriptions     = local.subscriptions
        resource_groups   = local.resource_groups
        policies          = local.all_policies
      })
    )
  }
}