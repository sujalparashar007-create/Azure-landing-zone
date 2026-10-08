# PROJECT CURRENT STATE AUDIT REPORT

*Generated: 2026-10-08 · Branch: `feature-azure-network-01/10/2026` · HEAD: `1846bf4 Project-Restructured`*
*Scope: read-only inspection. No project files were modified, created, deleted, applied, or destroyed (except this report file).*

> Legend: **[VERIFIED]** = observed directly from files/git/state/plan. **[INFERRED]** = reasoned from evidence but not directly observed.

---

## 1. PROJECT STATUS

### Architecture
YAML-driven Azure Landing Zone (ALZ). The YAML config under `modules/yaml-processing/config/` is the single source of truth. The `yaml-processing` child module decodes it, resolves references, and flattens it into maps. Independent per-component modules (each a separate Terraform root with its own state) consume those flattened maps and create Azure resources.

```
azure.yaml + network.yaml + custom-policy.yaml
        → modules/yaml-processing (decode + resolve refs + flatten)
        → modules/* (per-component root modules)
        → Azure
```

### Module inventory (7 top-level directories)
| Module | Purpose | State |
|---|---|---|
| `management-groups` | Management groups (4 levels) + subscriptions + MG↔subscription associations | Applied |
| `resource-groups` | Resource groups (azapi) | Applied |
| `budgets` | Subscription budgets | Applied |
| `iam` | Role assignments (Entra ID users) | Applied |
| `policies/built-in-policy` | Built-in policy assignments | **NOT applied** (empty state) |
| `policies/custom-policy` | Custom policy definitions + assignments | **NOT applied** (empty state) |
| `network` | VNets + subnets + NSGs + rules + NSG↔subnet associations | Applied (migration pending) |
| `yaml-processing` | Shared child module (only `null_resource.yaml_flatten`) | N/A |

### Phase status
- **Completed & applied**: management groups, subscriptions, resource groups, budgets, IAM, VNets (P1), subnets (P2), NSGs + rules + NSG↔subnet associations (P3).
- **In progress**: NSG↔subnet association migration from a separate PATCH resource to inline subnet-PUT ownership (code changed, **not yet applied**).
- **Pending (defined in `network.yaml`, no module yet)**: firewall, VPN gateway, bastion, NAT gateway, route tables, VNet peering (connectivity), DNS private resolver, private endpoints, test VM, Log Analytics (monitoring), network watcher, VNet flow logs, diagnostics.
- **Pending (defined in YAML, not applied)**: built-in + custom policy assignments.

---

## 2. GIT STATUS

- Branch: `feature-azure-network-01/10/2026` (up to date with `origin/feature-azure-network-01/10/2026`).
- Latest commit: `1846bf4 Project-Restructured`.

### Recent history (last 7 commits) [VERIFIED]
```
1846bf4 Project-Restructured                        <- HEAD (consolidated vnet/subnet/nsg into modules/network)
5710039 nsg+nsg + rule + subnet-nsg-association     <- P3 associations (PATCH-based)
8b17447 5-NSG + 12-NSG-rule
f14ab86 subnet
6de779e vnet
b424b44 network.yaml
032a249 Management-Group, Resource-Group, Policies/, IAM, Budget modules-completed
```

### Uncommitted changes (working tree vs HEAD `1846bf4`) [VERIFIED]
| File | Change |
|---|---|
| `.gitignore` | added `*.log` |
| `guide.md` | (this audit task) |
| `modules/network/apply.log` | **deleted** |
| `modules/network/main.nsg.tf` | removed `azapi_update_resource.nsg_subnet_association` + `subnet_subscription_id` local + `subnet_subscriptions_resolvable` check |
| `modules/network/main.subnet.tf` | added inline `networkSecurityGroup` to subnet PUT, `ignore_missing_property = each.value.nsg == null`, `retry = var.azapi_retry` |
| `modules/network/main.vnet.tf` | added `retry = var.azapi_retry` |
| `modules/network/outputs.tf` | `nsg_subnet_association_ids` now derived from `azapi_resource.subnet` |
| `modules/network/providers.tf` | comment only |
| `modules/network/variables.tf` | added `azapi_retry` variable |
| `modules/network/README.md` | **new** (untracked) |

Net effect of the uncommitted changes: **migrate NSG↔subnet association ownership from a separate `azapi_update_resource` (PATCH) to the subnet PUT body (inline)**, add shared retry settings, and clean up (`apply.log`, README).

---

## 3. TERRAFORM

### Flow [VERIFIED]
`network.yaml` → `yaml-processing` locals (`vnets`, `subnets`, `nsgs`, `nsg_rules`, `nsg_subnet_associations`) → `modules/network` creates `azapi_resource.vnet`, `azapi_resource.subnet` (with inline NSG), `azapi_resource.nsg`, `azapi_resource.rule`.

### `modules/network` files [VERIFIED]
- `main.vnet.tf` — `azapi_resource.vnet` (3 VNets).
- `main.subnet.tf` — `azapi_resource.subnet` (11 subnets; inline `networkSecurityGroup` for NSG-attached subnets).
- `main.nsg.tf` — `azapi_resource.nsg` (5) + `azapi_resource.rule` (12).
- `providers.tf` — azapi `~> 2.0`, azurerm `~> 4.0`.
- `variables.tf` — `yaml_file`, `network_yaml_file`, `azapi_retry`.
- `outputs.tf` — `vnet_ids`, `subnet_ids`, `nsg_ids`, `rule_ids`, `nsg_subnet_association_ids`.

### Current Terraform state (`modules/network/terraform.tfstate`, serial 132) [VERIFIED]
| Resource | Count | Keys |
|---|---|---|
| `azapi_resource.vnet` | 3 | `vnet-prod-hub`, `vnet-spoke-shared`, `vnet-spoke-payments` |
| `azapi_resource.subnet` | 11 | 7 hub + 2 shared + 2 payments |
| `azapi_resource.nsg` | 5 | `nsg-prod`, `nsg-spoke-shared-app`, `nsg-spoke-shared-data`, `nsg-spoke-payments-app`, `nsg-spoke-payments-data` |
| `azapi_resource.rule` | 12 | 12 NSG security rules |
| `azapi_update_resource.nsg_subnet_association` | 5 | 5 associations (**being migrated away**) |
| `null_resource.yaml_flatten` | 1 | YAML processing tracker |

The 11 subnets:
- `vnet-prod-hub`: `GatewaySubnet`, `AzureFirewallSubnet`, `AzureBastionSubnet`, `RouteServerSubnet`, `snet-hub-shared`, `PrivateResolverInbound`, `PrivateResolverOutbound`
- `vnet-spoke-shared`: `snet-shared-app`, `snet-shared-data`
- `vnet-spoke-payments`: `snet-payments-app`, `snet-payments-data`

### Current plan summary (fresh `terraform plan`, matches saved `modules/network/tfplan`) [VERIFIED]
```
Plan: 0 to add, 5 to change, 5 to destroy.
```
- **5 change** (update in-place): `azapi_resource.subnet[...]` — `ignore_missing_property = true -> false` for the 5 NSG-attached subnets.
- **5 destroy**: `azapi_update_resource.nsg_subnet_association[...]` — removed from configuration.
- **0 create, 0 replace.**

Detailed resource addresses are listed in §7.

---

## 4. YAML

### `azure.yaml` [VERIFIED]
- `tenant`: id `59cbaf84-4354-45ff-9649-b586ddfe9335`, display name "Contoso", root IAM (Reader), 2 budgets (`security-budget`, `platform-budget`), `users` map (UPN → object id).
- `management_groups` (7 total):
  1. `mg-platform` (L1, parent tenant-root)
  2. `mg-shared-services` (L2) — subscription `sub-shared-ops` + RG `rg-shared-ops`
  3. `mg-network` (L2)
  4. `mg-network-prod` (L3, child of `mg-network`) — subscription `sub-prod-network` + RG `rg-prod-network`
  5. `mg-production` (L2)
  6. `mg-prod-apps` (L3, child of `mg-production`)
  7. `mg-prod-payments` (L4, child of `mg-prod-apps`) — subscription `sub-prod-payment` + RG `rg-prod-payment-app`
- 3 subscriptions: `sub-shared-ops`, `sub-prod-network`, `sub-prod-payment`.
- 3 resource groups: `rg-shared-ops`, `rg-prod-network`, `rg-prod-payment-app`.

### `custom-policy.yaml` [VERIFIED]
- 3 custom definitions: `Deny-PublicIP`, `Require NSG on subnet`, `Require encryption`.
- Assignments to MGs: `mg-shared-services`, `mg-network`, `mg-network-prod`, `mg-production`, `mg-prod-payments`.

### `network.yaml` [VERIFIED]
- `defaults`: location `eastus`, tags `Environment=prod`, `Project=landing-zone`.
- `external_references`: `law-shared-ops` (Log Analytics), `kv-shared-secrets` (Key Vault) — **referenced but not yet created**.
- `features`: nat_gateway, firewall, vpn_gateway, bastion, dns_resolver, private_endpoint, test_vm, flow_logs = true; route_server = false.
- `references`: 3 subscriptions (`network`, `shared_services`, `payments`) + 3 resource groups.
- `network`: hub `vnet-prod-hub` (10.0.0.0/16, 7 subnets) + spokes `vnet-spoke-shared` (10.1.0.0/16) and `vnet-spoke-payments` (10.2.0.0/16).
- `security.network_security_groups`: 5 NSGs + 12 rules (source/dest/port mappings; service tag `Internet` uses singular `sourceAddressPrefix`).
- Unimplemented sections (present but no module consumes them): `connectivity`, `public_ips`, `nat`, `routing`, `gateways`, `dns`, `private_endpoints`, `compute`, `monitoring`, `network_watcher`, `flow_logs`, `diagnostics`.

### Important references/dependencies [VERIFIED]
- Subnets reference NSGs by name (`nsg:` field) → `nsg_subnet_associations` (5 entries).
- NSGs/subnets reference subscription+RG via `subscription_ref`/`resource_group_ref` → resolved through the `references` block → matched against `azure.yaml` subscriptions/RGs.
- Validation checks (`network_references_resolve`, `nsg_references_resolve`, `nsg_subnet_associations_resolve`) assert these references resolve and that NSG+subnet share a subscription.

### Verified inconsistencies
1. **`custom-policy.yaml` "Require NSG on Subnets" assignment (to `mg-network-prod`) has no `effect` field**, unlike every other assignment which sets `effect: "Deny"`/`"Audit"`. The custom-policy module unconditionally emits `effect = { value = each.value.effect }`, so this would yield `effect = null`. **Latent** (custom-policy module not applied).
2. **`network.yaml` sets `route_server: false` but still defines `RouteServerSubnet` (10.0.3.0/27)**. Minor; subnet is pre-provisioned for a future Route Server.
3. **`network.yaml` header claims "afw-prod and vng-prod are fully defined here", but no module implements firewall/VPN gateway** — those are pending (see §1).

---

## 5. AZURE

### Current deployed resources (by major component) [VERIFIED from state files]
| Component | Module | Deployed (state) |
|---|---|---|
| Management groups | `management-groups` | 7 MGs (4 resource blocks: level1–4) + `azurerm_subscription` (3) + `azurerm_management_group_subscription_association` (3) |
| Resource groups | `resource-groups` | 3 RGs (`rg-shared-ops`, `rg-prod-network`, `rg-prod-payment-app`) |
| Budgets | `budgets` | 2 subscription budgets |
| IAM | `iam` | role assignments (Reader/Security Admin/Contributor/Key Vault Admin/Network Contributor) |
| Network | `network` | 3 VNets, 11 subnets, 5 NSGs, 12 rules, 5 NSG↔subnet associations |
| Policies | `policies/built-in-policy`, `policies/custom-policy` | **none** (empty state) |

### Terraform state vs actual Azure state [VERIFIED for state; INFERRED for Azure]
- **No verified drift**: the fresh `terraform plan` reports only configuration-driven actions (the association migration), not unexpected property drift on deployed resources.
- The subnet state body already contains `networkSecurityGroup` (from the prior PATCH), so the new inline association produces **no body diff** — only the `ignore_missing_property` meta-attribute changes.
- Azure itself was **not** queried in this audit (read-only inspection of git/state/plan only), so Azure-side drift cannot be independently confirmed beyond what `terraform plan` reveals.

---

## 6. CURRENT PROBLEMS

### P1 — NSG↔subnet association migration is uncommitted and unapplied
- **Problem**: association ownership was moved from a separate `azapi_update_resource` (PATCH) to the subnet PUT body, but the change is not committed and not applied. State still holds 5 `azapi_update_resource.nsg_subnet_association` resources that are no longer in code.
- **Evidence**: git diff (`main.nsg.tf` removed the resource; `main.subnet.tf` added inline `networkSecurityGroup`); plan `5 to destroy, 5 to change`.
- **Impact**: until applied, every plan shows 5 destroys + 5 changes; the subnet PUT does not yet own the NSG.
- **Priority**: P1.

### P2 — Policy modules not applied
- **Problem**: `policies/built-in-policy` and `policies/custom-policy` have empty state (no assignments deployed).
- **Evidence**: both `terraform.tfstate` files are 182 bytes with `"resources": []`.
- **Impact**: governance (Allowed locations, Deny Public IP, Require NSG on subnets, Require encryption) not enforced.
- **Priority**: P2.

### P3 — `network.yaml` defines many components with no implementing module
- **Problem**: firewall, VPN gateway, bastion, NAT, route tables, peering, DNS resolver, private endpoints, test VM, monitoring, network watcher, flow logs, diagnostics are in YAML but have no module.
- **Evidence**: `network.yaml` top-level sections; `modules/network` only implements vnet/subnet/nsg/rule/association.
- **Impact**: hub-and-spoke is only partially realized (no firewall, no VPN, no peering, no DNS, no private endpoints).
- **Priority**: P3 (next phase).

### P3 — Custom policy "Require NSG on Subnets" assignment missing `effect`
- **Problem**: the `mg-network-prod` assignment in `custom-policy.yaml` has no `effect` field; the module always emits `effect = { value = each.value.effect }`.
- **Evidence**: `custom-policy.yaml` lines 30–31 (no `effect`, unlike lines 12/18/24/35/41).
- **Impact**: potential `effect = null`; latent (module not applied).
- **Priority**: P3.

### P3 — `apply.log` committed then deleted (repo hygiene)
- **Problem**: `apply.log` (134 lines) was committed in `1846bf4`, now deleted (uncommitted); `.gitignore` gains `*.log`.
- **Evidence**: git status `deleted: modules/network/apply.log`; `.gitignore` `+*.log`.
- **Impact**: minor; the deletion itself is uncommitted.
- **Priority**: P3.

### P3 — Non-obvious `merge([ ... ]...)` spread syntax (observation, no action)
- **Problem**: `yaml-processing/main.tf` uses `merge([ ... ]...)` (a trailing `...` after `]`).
- **Evidence**: lines 426 and 464 (`]...)`).
- **Impact**: none verified — `terraform validate` and `terraform plan` pass and produce correct results (valid in Terraform 1.15.5).
- **Priority**: P3 (observation only).

---

## 7. PLAN / APPLY DECISION

### Current plan (exact actions) [VERIFIED]
```
Plan: 0 to add, 5 to change, 5 to destroy.
```

**5 changes (update in-place)** — `ignore_missing_property = true -> false` on the 5 NSG-attached subnets:
- `azapi_resource.subnet["vnet-prod-hub/snet-hub-shared"]`
- `azapi_resource.subnet["vnet-spoke-shared/snet-shared-app"]`
- `azapi_resource.subnet["vnet-spoke-shared/snet-shared-data"]`
- `azapi_resource.subnet["vnet-spoke-payments/snet-payments-app"]`
- `azapi_resource.subnet["vnet-spoke-payments/snet-payments-data"]`

**5 destroys** — `azapi_update_resource.nsg_subnet_association[...]` (same 5 keys), removed from configuration.

### Classification
- **Expected**: all 10 actions are the association migration.
- **Caused by recent changes**: yes — the uncommitted PATCH→inline migration.
- **Suspicious**: none. The 5 destroys are the removed `azapi_update_resource`; the 5 changes are the new `ignore_missing_property` meta-attribute. No VNet/NSG/rule changes; no recreation.

### Apply decision: **YES (safe)** — with a caveat
- **Reason**: (1) deleting `azapi_update_resource` performs **no Azure operation** (azapi leaves the subnet's `networkSecurityGroup` unchanged on destroy); (2) the subnet "update" re-PUTs a body whose `networkSecurityGroup` already matches current state, so it is **idempotent** and detaches nothing. No NSG is ever detached.
- **Caveat**: this is a migration — review and commit the uncommitted changes first, then apply, then verify `terraform plan` shows `No changes`.

---

## 8. NEXT STEPS

Shortest correct sequence:
1. Review the uncommitted `modules/network` changes (PATCH→inline migration) and the new `README.md`.
2. `cd modules/network && terraform fmt -check -recursive && terraform validate`.
3. `terraform plan` → confirm `0 to add, 5 to change, 5 to destroy`.
4. `terraform apply` (migration) → subnet PUT now owns the NSG inline; the 5 `azapi_update_resource` are removed from state (no Azure effect).
5. Re-run `terraform plan` → expect `No changes`; then `git add` + commit the migration.
6. Next phase: implement the pending `network.yaml` components (firewall/VPN/bastion/NAT/routing/peering/DNS/private endpoints/test VM/monitoring/flow logs/diagnostics) as new `main.<component>.tf` files in `modules/network` (per README), preserving the YAML→flatten→module flow.
7. Apply the policy modules (built-in + custom) and fix the missing `effect` on the "Require NSG on Subnets" assignment.

---

## FINAL SUMMARY

- **Current state**: governance (7 MGs, 3 subscriptions, 3 RGs, budgets, IAM) and the hub-and-spoke network core (3 VNets, 11 subnets, 5 NSGs, 12 rules, 5 NSG↔subnet associations) are deployed. Policy assignments are **not** applied; firewall/VPN/bastion/DNS/private-endpoints/flow-logs/diagnostics are defined in YAML but not yet implemented.
- **Main issue**: NSG↔subnet association ownership is being migrated (PATCH → inline subnet PUT), and that migration is uncommitted + unapplied — so every plan shows `5 to change, 5 to destroy`.
- **Required fix**: apply the migration (idempotent, no NSG detach) and commit it.
- **Apply decision**: **YES (safe)** — after reviewing/committing the uncommitted changes.
- **Next phase**: firewall / VPN gateway / bastion / routing / peering / DNS resolver / private endpoints, then policy enforcement.






