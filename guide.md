Fix Phase P4 VNet Peering based on the actual Azure apply error.

IMPORTANT:
Do NOT start Phase P5.
Do NOT deploy VPN Gateway as part of P4.
Do NOT modify unrelated completed phases.

Current P4 apply result:
- peer-hub-to-spoke-shared: CREATED successfully
- peer-hub-to-spoke-payments: CREATED successfully
- peer-spoke-shared-to-hub: FAILED
- peer-spoke-payments-to-hub: FAILED

Both failures have the exact Azure error:

RemoteVnetHasNoGateways

Azure rejects the two spoke-to-hub peerings because:
useRemoteGateways = true
while the remote hub VNet vnet-prod-hub currently has no gateway.

The intended network.yaml configuration is:

Hub → Shared:
allow_forwarded_traffic = true
allow_gateway_transit = true
use_remote_gateways = false

Shared → Hub:
allow_forwarded_traffic = true
allow_gateway_transit = false
use_remote_gateways = true

Hub → Payments:
allow_forwarded_traffic = true
allow_gateway_transit = true
use_remote_gateways = false

Payments → Hub:
allow_forwarded_traffic = true
allow_gateway_transit = false
use_remote_gateways = true

Goal:
Make Phase P4 fully deployable now without deploying the VPN Gateway in P4, while preserving network.yaml as the single source of truth and preserving the intended final architecture.

Requirements:

1. Investigate the current P4 implementation and Terraform state first.
2. Do NOT destroy or recreate the two peerings that already exist successfully.
3. Do NOT deploy any VPN Gateway, Public IP, NAT Gateway, Firewall, Bastion, or other future-phase resource.
4. Do NOT change the existing VNet, subnet, NSG, NSG rules, route tables, or UDR implementations.
5. Do NOT permanently hard-code useRemoteGateways=false for the spoke-to-hub peerings because network.yaml explicitly defines it as true.
6. Design the implementation so that:
   - P4 can successfully create the peerings that Azure currently permits.
   - The configuration remains YAML-driven.
   - The intended use_remote_gateways=true behavior is preserved and can automatically reconcile once the Hub VPN Gateway exists in the later VPN Gateway phase.
7. Prefer a Terraform/Azure dependency-aware solution rather than changing the architecture or introducing manual Azure resources.
8. If the current architecture cannot satisfy both "P4 fully applied now" and "network.yaml remains the final source of truth" without a future-phase dependency, explain the exact limitation before making changes and propose the smallest clean implementation.
9. Do not introduce a new landing-zone wrapper or root orchestration.
10. Keep the existing:
    network.yaml → yaml-processing → flattening/null_resource/for_each → modules/network → Azure resources
    architecture.
11. Preserve all existing P4 validation checks:
    - duplicate peering names
    - duplicate local-to-remote definitions
    - empty/self-referencing VNets
    - unresolved local VNet references
    - unresolved remote VNet references
12. Run:
    terraform fmt -recursive
    terraform validate
    terraform plan
13. Do NOT run terraform apply.

The final report must clearly state:
- exact files changed
- exact root cause
- how the solution handles Azure's RemoteVnetHasNoGateways restriction
- how network.yaml remains the source of truth
- whether the plan will create/change/destroy resources
- whether the two already-created peerings remain untouched
- whether P4 is now safe to apply

Do not perform unrelated refactoring.