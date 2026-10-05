Implement the approved reference design for the existing network.yaml P1 VNet implementation.

IMPORTANT ARCHITECTURE REQUIREMENT:

The project flow and working flow must remain exactly the same as the existing Azure Landing Zone implementation:

azure.yaml / custom-policy.yaml / network.yaml
        ↓
modules/yaml-processing
        ↓
YAML decode + flattening
        ↓
module outputs
        ↓
individual Terraform modules
        ↓
Azure resources

Do NOT introduce a new architecture, wrapper module, or separate processing flow.

REFERENCE REQUIREMENT:

network.yaml consumes some resources that already exist in the previous ALZ deployment and are already defined in azure.yaml.

For these existing resources only:
- subscriptions
- resource groups

network.yaml must use references instead of repeating their names throughout the network resource definitions.

Use the approved references approach:

references:
  subscriptions:
    network: "sub-prod-network"
    shared_services: "sub-shared-ops"
    payments: "sub-prod-payment"

  resource_groups:
    network: "rg-prod-network"
    shared_services: "rg-shared-ops"
    payments: "rg-prod-payment-app"

Then network resources must use:
- subscription_ref
- resource_group_ref

instead of directly repeating the existing subscription/resource-group names.

IMPORTANT:
The references block is only a mapping for existing ALZ resources. Do not redesign the rest of network.yaml.

NEW NETWORK RESOURCE CONFIGURATION:

All configuration belonging to resources that network.yaml is creating must remain in network.yaml exactly as the existing design intends.

Do not move network.yaml configuration into Terraform modules.
Do not hard-code network.yaml values inside Terraform modules.
Do not duplicate network.yaml values inside Terraform modules.

The modules must continue consuming only the flattened outputs from modules/yaml-processing, exactly like the existing azure.yaml/custom-policy.yaml flow.

YAML-PROCESSING:

1. Extend the existing network.yaml processing in modules/yaml-processing.
2. Resolve subscription_ref against the existing flattened azure.yaml subscription data.
3. Resolve resource_group_ref against the existing flattened azure.yaml resource-group data.
4. Validate that:
   - the reference exists
   - the referenced subscription exists
   - the referenced resource group exists
   - the resource group belongs to the referenced subscription
5. Inject the resolved values into the flattened network data.
6. Expose the resolved network data through the existing yaml-processing outputs.
7. Preserve the existing azure.yaml and custom-policy.yaml processing unchanged.
8. Do not create a second YAML parser or separate processing mechanism.

VNET MODULE:

Update modules/vnet so that it consumes the resolved flattened VNet data from yaml-processing.

The VNet module must NOT contain hard-coded:
- subscription names
- resource-group names
- VNet names
- locations
- address spaces
- or any other network.yaml configuration values.

It must use only the values received from yaml-processing.

Remove the current independent subscription/resource-group discovery where it duplicates the reference resolution already performed by yaml-processing.

If Azure subscription GUID resolution is technically required because yaml-processing has no Azure provider, keep only the minimum provider-side lookup necessary to translate the already-resolved subscription value into its Azure ID. Do not recreate the reference-resolution logic inside modules/vnet.

SCOPE:

- This change is only for the approved P1 VNet implementation and the reusable subscription/resource-group reference mechanism.
- Do not implement subnets or any other network resource.
- Do not modify unrelated ALZ modules.
- Do not create duplicate resources.
- Do not apply Terraform.

VALIDATION:

After implementation run:

terraform fmt
terraform validate
terraform plan

Do not run terraform apply.

Before finishing, report:
1. Exact files changed.
2. Final network.yaml reference structure.
3. How subscription_ref and resource_group_ref are resolved.
4. What flattened data is exposed to modules/vnet.
5. Confirmation that no network.yaml configuration is hard-coded inside modules/vnet.
6. Terraform fmt result.
7. Terraform validate result.
8. Terraform plan result.
9. Confirm that no apply was performed.

Preserve the existing project conventions and implementation pattern wherever possible. Make the minimum changes required to implement this reference mechanism correctly.