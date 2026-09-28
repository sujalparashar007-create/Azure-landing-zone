CONTEXT
Azure Landing Zone Terraform project. Run all Terraform commands from the repo ROOT only, never inside a module folder. Shell is Git Bash on Windows.

Layout: root main.tf/variables.tf/outputs.tf/providers.tf, config/azure.yaml (source of truth), modules/yaml-processing, modules/management-groups, modules/policies/built-in-policy, modules/policies/custom-policy.

Current state (fully applied, terraform plan = "No changes"):
- yaml-processing decodes azure.yaml once, flattens everything, classifies policies into builtin_policies / custom_policies, and has null_resource.yaml_flatten with sha256 triggers (its hash includes the policies).
- modules/policies/custom-policy/main.tf creates ONE azurerm_policy_definition.this per unique definition key (for_each over local.custom_policy_definitions built from var.policies, using policy_rule, display_name, definition_parameters) at var.definitions_management_group_id (tenant root MG), plus azurerm_management_group_policy_assignment.this per policy.
- Existing custom definitions: "Deny-PublicIP", "Require NSG on subnet", "Require encryption". There are 6 custom assignments.
- custom-policy/main.tf also contains a recently added azurerm_role_assignment.policy_definition_writer + time_sleep.role_propagation (fix for the policyDefinitions/write 403). DO NOT modify, move or remove this role-assignment/time_sleep code or the depends_on that uses it.

TASK (from my instructor)
The custom policy details/code (the custom policy definition content: policy_rule JSON, display_name, definition parameters, and any hardcoded custom policy rule block, wherever it currently lives) must be moved out into a SEPARATE module named "custom-yaml" located at modules/yaml-processing/custom-yaml/. If moving it causes ANY change anywhere else in the project, you must FIRST show me every change and only fix it AFTER I confirm.

WORKFLOW: follow these stages in order and stop at each gate.

STAGE 1: read-only investigation (change NOTHING)
1. Find exactly where the custom policy details/code currently live (file + line ranges): the policy_rule JSON, display_name, definition parameters, any local.custom_policy_rules-style block, and how they reach the custom-policy module (through yaml-processing outputs, root main.tf, or hardcoded).
2. Say clearly what you understand by "a separate module named custom-yaml inside yaml-processing". Default interpretation: a child module folder modules/yaml-processing/custom-yaml/ with the standard 3 files (main.tf, variables.tf, outputs.tf) that holds the custom policy definition details and exposes them as outputs. If you see another reasonable interpretation, state it and ask me before continuing.

STAGE 2: proposal only (still change NOTHING)
Give me a written plan containing:
a) The exact block(s) to move, source -> destination, with file paths.
b) The new module's inputs and outputs, and how yaml-processing will call it.
c) A full IMPACT LIST: every other file that would need to change because of this move (root main.tf, root outputs.tf, yaml-processing outputs/variables, custom-policy variables.tf/main.tf, azure.yaml, README, etc.), each with file, line range, what changes and why. If nothing else needs to change, say "no other changes".
d) Terraform state impact. Resource addresses such as module.custom_policy.azurerm_policy_definition.this["Deny-PublicIP"] must stay identical, with NO destroy/recreate of any definition, assignment, MG, subscription or the role assignment. If any address would change, propose moved blocks and show them.
e) Note that the null_resource.yaml_flatten trigger hash may change because the structure changed, which would show as a null_resource replacement in plan. Tell me if this will happen. It is acceptable, but report it.
STOP after this and wait for my explicit confirmation.

STAGE 3: implementation (only after I say "confirmed")
1. Create modules/yaml-processing/custom-yaml/ and move only the approved blocks. Keep the 3-file module structure. Do not move any Azure resource blocks (azurerm_*) out of custom-policy.
2. Apply ONLY the changes listed in the approved impact list. If you discover an additional needed change, STOP, show it to me and wait for confirmation.
3. Run from repo root: terraform fmt -recursive, terraform init, terraform validate, terraform plan. Do NOT run terraform apply.
4. Show me the full plan output. Target result: "No changes" (or only the null_resource replacement if I approved it). If anything else appears (any azurerm_* create/change/destroy), stop and explain.

RULES
- Do not rebuild or rewrite completed work; change the minimum needed.
- One logical module per concern; every module keeps main.tf, variables.tf, outputs.tf.
- Policy behaviour must stay the same: same 3 definitions, same 6 assignments, same scopes and effects (Deny-PublicIP: Deny at tenant-root, mg-network, mg-production, mg-shared-services; Require NSG on subnet: Deny at mg-network-prod; Require encryption: Audit at mg-prod-payments).
- Do not touch config/azure.yaml unless the impact list includes it and I confirmed.
- Never run terraform apply or destroy, and never delete state files.
- Show diffs before and after; explain each change in simple words.