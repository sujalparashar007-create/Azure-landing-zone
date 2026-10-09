Refactor the Azure Bastion implementation to use AzAPI, following the existing VNet/subnet implementation pattern.

Project architecture must remain:
network.yaml → modules/yaml-processing (reference resolution and flattening) → modules/network → Azure resources.

Tasks:

1. Revert ONLY the recent provider-level Bastion fix:
   - Remove network_subscription_id from modules/network/variables.tf.
   - Restore modules/network/providers.tf to its exact pre-fix configuration.
   - Do not revert unrelated changes.

2. Replace azurerm_bastion_host in modules/network/main.bastion.tf with an azapi_resource that creates Microsoft.Network/bastionHosts using the existing AzAPI provider version and conventions in this project.

3. Resolve the Bastion subscription and resource group from existing network.yaml references through modules/yaml-processing. Follow the same established approach used by the working VNet/subnet resources. Do not hardcode subscription IDs or add a separate subscription variable.

4. Reuse the exact existing AzureBastionSubnet and pip-bastion-hub resource IDs resolved from the project configuration. Preserve the existing Bastion settings from the current implementation and use the correct AzAPI API version and request body schema for Microsoft.Network/bastionHosts.

5. Update outputs only as needed to preserve the existing bastion_ids output contract.

6. Do not modify network.yaml, existing deployed resources, other modules, Terraform state, or unrelated resources. Do not add provider aliases or implement other features.

7. Run terraform fmt and terraform validate only. Do not run plan, apply, destroy, import, or state-modifying commands.

Report the exact diff, the API version used, and validation results. Stop for review.