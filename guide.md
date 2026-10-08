Implement Phase P4 — VNet Peering for the Azure Landing Zone network extension.

Follow the existing architecture exactly:
network.yaml → modules/yaml-processing → YAML flattening/null_resource/for_each → modules/network → Azure resources.

Requirements:

1. Treat config/network.yaml as the single source of truth.
2. Parse and expose connectivity.peerings through modules/yaml-processing.
3. Create the 4 YAML-defined VNet peerings exactly as configured:

   - peer-hub-to-spoke-shared
     vnet-prod-hub → vnet-spoke-shared
     allow_forwarded_traffic = true
     allow_gateway_transit = true
     use_remote_gateways = false

   - peer-spoke-shared-to-hub
     vnet-spoke-shared → vnet-prod-hub
     allow_forwarded_traffic = true
     allow_gateway_transit = false
     use_remote_gateways = true

   - peer-hub-to-spoke-payments
     vnet-prod-hub → vnet-spoke-payments
     allow_forwarded_traffic = true
     allow_gateway_transit = true
     use_remote_gateways = false

   - peer-spoke-payments-to-hub
     vnet-spoke-payments → vnet-prod-hub
     allow_forwarded_traffic = true
     allow_gateway_transit = false
     use_remote_gateways = true

4. Resolve VNet IDs using the existing YAML-derived VNet/reference maps.
   Do not hard-code subscription IDs, resource group names, or VNet IDs.

5. Implement peerings inside the existing independent modules/network module.
   Do not create a new landing-zone wrapper or root orchestration.

6. Preserve all completed P0/P1/P2/P3 implementations:
   - VNets
   - Subnets
   - NSGs
   - NSG rules
   - NSG-subnet associations
   - Route Tables
   - UDRs
   Do not modify/recreate them unless strictly required for peering.

7. Do not deploy Route Server because features.route_server = false.

8. Add appropriate validation/checks for:
   - unresolved local VNet references
   - unresolved remote VNet references
   - invalid/duplicate peering definitions

9. Use for_each and keep the implementation fully YAML-driven.

10. Run:
    terraform fmt -recursive
    terraform validate
    terraform plan

Do NOT run terraform apply.

Report:
- files changed
- peering resources created by the plan
- plan summary
- any validation issues
- confirm that there are no unexpected destroys or unrelated changes.

Do not perform unrelated refactoring.