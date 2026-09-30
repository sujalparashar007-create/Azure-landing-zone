Fix the 4 remaining design issues in the current standalone Terraform modules.

IMPORTANT:
- Keep the current modular architecture.
- Preserve:
  azure.yaml + custom-policy.yaml
  → yaml-processing
  → flattening + null_resource + for_each
  → modules
  → Azure resources
- `modules/yaml-processing` must remain the ONLY YAML parser.
- Do NOT hard-code YAML-derived values.
- Preserve existing `for_each`.
- Do NOT create any wrapper/nested landing-zone module.
- Do NOT manually modify Terraform state.
- Do NOT run terraform plan, apply, or destroy during this task.

1. IAM — USE USERS INSTEAD OF GROUPS
- Replace `azuread_group` principal resolution with `azuread_user`.
- IAM roles must be assigned directly to users.
- Keep users, roles, scopes, and assignments YAML-driven.
- Preserve existing IAM `for_each`.
- Do not invent user identities. Verify users from the available configuration/environment.
- Remove the old `group:`-based logic.

2. SUBSCRIPTION LOOKUPS — MAKE THEM DETERMINISTIC
- Find all subscription lookups using `data.azurerm_subscriptions` with `[0]`.
- Replace them with deterministic lookup logic based on the subscription identity already provided by YAML/yaml-processing.
- Do NOT hard-code subscription IDs.
- Fail clearly if the expected subscription cannot be resolved.
- Apply this wherever the fragile lookup exists, especially resource-groups and IAM.

3. BUILT-IN POLICY EFFECT
- The built-in policy YAML already contains `effect`.
- Ensure the flattened YAML `effect` value is actually used by the built-in policy assignment.
- Do not hard-code the effect.
- Preserve existing policy `for_each`, names, scopes, and addresses where possible.
- Verify this matches the existing intended built-in-policy configuration.

4. BUILT-IN/CUSTOM POLICY CLASSIFICATION
- Remove the fragile hard-coded `builtin_definition_names` allowlist.
- Classification must come from the YAML/yaml-processing data.
- Do NOT duplicate YAML parsing.
- Do NOT hard-code policy names.
- Preserve existing built-in/custom policy behavior and `for_each`.

AFTER THE FIXES:
Check the entire project for:
- remaining `azuread_group`
- remaining `group:` IAM logic
- remaining `[0]` subscription selection
- built-in policy `effect` actually being consumed
- static built-in-policy name allowlists
- duplicated `yamldecode()`
- hard-coded YAML-derived values
- broken/stale references
- missing variables, outputs, locals, or blocks

Fix genuine issues immediately.

VALIDATION:
Run ONLY:
- terraform fmt
- terraform init
- terraform validate

Run the commands for every affected module.
If a provider/filesystem issue occurs, distinguish it from a Terraform configuration issue and fix only the environment/cache problem.

Do NOT run plan/apply/destroy.

FINAL REPORT:
- exact files changed
- what was fixed for each of the 4 issues
- whether IAM now assigns roles directly to users
- how subscription lookup is now resolved
- whether built-in policy effect is YAML-driven
- how policy classification now works
- validation result for every affected module
- any remaining issue

Do not start that deployment phase automatically.