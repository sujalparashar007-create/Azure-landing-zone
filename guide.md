Clean up all Resources-related Terraform code from `modules/yaml-processing`.

IMPORTANT:
- Do NOT modify or remove any Resources configuration from `modules/yaml-processing/config/azure.yaml`.
- Resource definitions must remain only in `azure.yaml` for future use.
- Resources are intentionally skipped/not deployable in the current project.
- Do NOT create a `modules/resources` module.
- Do NOT modify Management Groups, Resource Groups, Policies, IAM, or Budgets logic.
- Do NOT run terraform plan/apply/destroy.
- Only run terraform fmt and terraform validate.

Tasks:
1. Inspect `modules/yaml-processing/main.tf`, `outputs.tf`, and `variables.tf` for all Resources-specific locals, flattening logic, outputs, maps, references, and dependencies.
2. Remove all Resources-specific processing from yaml-processing, including:
   - `resources` local/flattening
   - `resources_map`
   - `resource_configuration` outputs if they exist only for Resources
   - any other Resources-only locals/references
3. Keep the existing `null_resource.yaml_flatten`, but update its hash/trigger logic so it no longer depends on the removed Resources locals.
4. Remove any downstream references to those deleted Resources outputs.
5. Do not remove YAML parsing of `azure.yaml` itself; other active configuration must continue working.
6. Confirm `yamldecode()` remains only in `yaml-processing`.
7. Do not remove or alter the actual resource definitions inside `azure.yaml`.

After changes, verify:
- No Resources-specific Terraform code remains in `modules/yaml-processing`.
- No active module references removed Resources outputs.
- `azure.yaml` still contains the resource definitions unchanged.
- `null_resource.yaml_flatten` still works with the remaining configuration.
- `terraform fmt` succeeds.
- `terraform validate` succeeds.

Report:
- exact files changed
- Resources-related code removed
- outputs/locals removed
- confirmation that `azure.yaml` resource data was preserved
- fmt/validate results