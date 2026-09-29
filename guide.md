Refactor this Terraform Azure Landing Zone project to remove the root-level Terraform dependency and make each required module independently runnable.

IMPORTANT: This is an architecture refactor, not a resource/infrastructure redesign.

GOAL:
The current root `main.tf`, `variables.tf`, `providers.tf`, and `outputs.tf` create dependencies between the root module and child modules. Refactor the project so that the required Terraform logic/configuration is owned by the appropriate modules.

Required target architecture:

- `yaml-processing` owns and reads:
  - `modules/yaml-processing/config/azure.yaml`
  - `modules/yaml-processing/config/custom-policy.yaml`
- Other functional modules should consume the required flattened/configuration outputs through their own module configuration and should not depend on the root `main.tf`.
- Each functional module must be independently runnable from inside its own directory with Terraform commands.
- The root Terraform module should no longer be required.

TASK:

1. FIRST inspect the entire repository and map:
   - every block in root `main.tf`
   - every variable in root `variables.tf`
   - every provider configuration in root `providers.tf`
   - every output in root `outputs.tf`
   - all module dependencies
   - all references between modules
   - all YAML/config file references
   - all resource dependencies and scopes.

2. Determine which root blocks belong to which module.
   Move each block into the appropriate module's `main.tf`, `variables.tf`, `providers.tf` only when genuinely required, and `outputs.tf`.

3. Preserve the existing module convention where applicable:
   - `main.tf`
   - `variables.tf`
   - `outputs.tf`
   - do NOT create `providers.tf` inside a module unless that module genuinely requires its own provider configuration.
   - Keep modules clean and self-contained.

4. `yaml-processing` must remain the central configuration-processing layer:
   - It owns both YAML files under `modules/yaml-processing/config/`.
   - It should continue producing the flattened configuration required by downstream modules.
   - Do NOT change the contents of `azure.yaml` or `custom-policy.yaml`.
   - Do NOT duplicate YAML parsing logic across modules.

5. Remove unnecessary dependency on root `main.tf`.
   Functional modules should receive only the inputs they actually need and should not rely on resources or locals that exist only because of the root module.

6. Make each required functional module independently runnable.
   For example, a module should be able to run:
   
   `terraform init`
   `terraform validate`
   `terraform plan`

   from its own directory without requiring the root `main.tf`.

   If a module requires outputs from `yaml-processing`, design the dependency cleanly so the module can consume the required configuration without recreating the root-level orchestration dependency.

7. Preserve all existing Azure resource behavior:
   - Management Groups
   - Subscriptions
   - Resource Groups
   - Policies
   - Custom Policies
   - IAM/RBAC
   - YAML processing
   - all existing resources, names, IDs, scopes, assignments and relationships.

8. DO NOT:
   - redesign the infrastructure
   - rename existing Azure resources
   - change resource IDs
   - change YAML contents
   - manually modify Terraform state
   - recreate resources unnecessarily
   - remove required functionality
   - change policy definitions/assignments
   - change RBAC intent
   - run `terraform apply`
   - run `terraform destroy`.

9. Before deleting anything from the root:
   - verify that every required root block has been moved/replaced.
   - verify all references are updated.
   - verify no module still depends on the root module.
   - search the entire repository for stale references.

10. Once the migration is complete:
   - remove root `main.tf`
   - remove root `variables.tf`
   - remove root `providers.tf`
   - remove root `outputs.tf`
   - remove any other root Terraform file that is no longer required.
   - Do NOT delete `terraform.tfstate` or any state-related file unless it is clearly an unnecessary generated artifact and you explain it first.

11. IMPORTANT STATE SAFETY:
   Before finalizing, compare the resulting Terraform configuration against the current state and ensure the refactor does not cause existing Azure resources to appear as destroy/recreate operations.

12. Validation:
   Run `terraform fmt` on the complete project.

   Then validate each independently runnable module from its own directory using:
   `terraform init`
   `terraform validate`
   `terraform plan`

   Do NOT apply anything.

13. For every module plan:
   - If it shows `No changes`, report that.
   - If it proposes Add/Change/Destroy, STOP and investigate why before making further changes.
   - Do not accept unexpected resource changes just to make the plan pass.

14. Final verification:
   - Confirm root Terraform orchestration files have been removed.
   - Confirm all required modules are self-contained.
   - Confirm no stale root-module references remain.
   - Confirm YAML files remain under `modules/yaml-processing/config/`.
   - Confirm YAML contents are unchanged.
   - Confirm existing infrastructure has no unexpected Terraform drift.

At the end, give me:
1. Final directory structure.
2. List of root blocks moved and their destination modules.
3. List of files changed.
4. List of files deleted.
5. Module dependency flow.
6. Validation result for every module.
7. Terraform plan result for every module.
8. Confirmation that no `terraform apply` or `terraform destroy` was executed.

Do not make assumptions. Inspect the actual repository first and perform the refactor based on the existing code.