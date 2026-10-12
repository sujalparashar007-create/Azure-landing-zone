Continue the existing Azure Landing Zone Terraform network project from its current state. Do not restart or redesign the project.

CONTEXT
- YAML-driven architecture: YAML → modules/yaml-processing → flattening/null_resource/for_each → modules/network → Azure.
- Scope ONLY: modules/yaml-processing/config/network.yaml, modules/yaml-processing/main.tf, and modules/network/*.tf.
- Existing Azure resources, including vm-test-hub and nic-vm-test-hub, are fully implemented and validated.
- The VM administrator password is already configured as an environment variable in my workspace. Do not assume it is missing.
- The network.yaml cleanup has already removed: features.flow_logs, flow_logs, network_watcher, diagnostics, monitoring.log_analytics_workspace, monitoring.data_collection_rules, monitoring.storage_accounts.stnetlogshub, routing.route_server, and public_ips.pip-rs-hub.
- features.route_server=false, pip-vpn-gw, VPN configuration, GatewaySubnet, RouteServerSubnet, stappdatahub, existing peerings, and all protected configuration remain.
- The previous plan showed an unexpected in-place update to azapi_resource.virtual_machine["vm-test-hub"] after a temporary plan-only password was supplied. Nothing was applied.

PHASE 1 — READ-ONLY AUDIT
1. Inspect the current Git diff, YAML, yaml-processing logic, network module, Terraform variables, environment-variable naming, and latest available plan output.
2. Do not display, print, log, or request any secret/password.
3. Verify how the VM password environment variable is mapped to the Terraform sensitive variable. Check variable names and whether the current shell/workspace has the required input without revealing its value.
4. Identify the exact VM attribute causing the proposed update. Do not assume the password is the only possible cause.
5. Verify every removed YAML key has no remaining required references in flattening code, validations, locals, dependencies, or implemented resources.
6. Check that removing YAML entries has not changed existing resource for_each keys or IDs.

PHASE 2 — MINIMAL FIX
1. Do not modify validated VM configuration merely to suppress the plan.
2. Do not replace, recreate, reset, or redeploy the VM.
3. If the password input is missing or incorrectly mapped, explain the exact environment-variable name and safe local setup needed. Do not invent a password or modify Azure credentials.
4. Prefer reusing the existing environment variable. If Azure CLI is considered for password recovery/reset, first explain that a VM password reset changes credentials and is not equivalent to supplying Terraform's existing password. Do not execute a reset.
5. Make no file changes until you show the proposed diff and explain the cause and impact. Ask for approval before any code/configuration edit.
6. Do not alter unrelated modules, provider architecture, state, or deployed Azure resources.

PHASE 3 — VALIDATION AFTER APPROVAL
1. Run formatting, git diff --check, and Terraform validation in the correct module/workspace.
2. Generate a fresh plan using the correct existing sensitive environment input; never use a temporary/dummy password.
3. Inspect the complete plan, especially vm-test-hub, nic-vm-test-hub, and every state-backed network resource.
4. The local null_resource.yaml_flatten replacement may be expected due to the YAML hash change, but verify its effects.
5. If any existing Azure resource shows an unexpected update, replacement, or destruction, STOP. Do not apply.
6. Report exact plan counts and every non-no-op Azure resource action. Do not claim success based only on terraform validate.

PHASE 4 — CONTINUE PROJECT AUDIT
Only after the cleanup plan is confirmed safe, audit modules/yaml-processing/main.tf and all modules/network/*.tf files for AzAPI consistency, YAML references, stale code, dependency wiring, and missing implementations.
Preserve the existing YAML-driven architecture and all validated resources. Do not start new resource implementations or remove more YAML without a separate proposal and my approval.

STRICT SAFETY
- No terraform apply/destroy/import, state mutation, Azure mutation, VM password reset, or deployment.
- Do not modify files during the initial audit.
- Do not expose secrets or place passwords in command history, source code, logs, or plan output.
- First return findings, the exact root cause, the proposed minimal fix, and validation commands. Wait for my approval before editing files or making changes.
- Work one phase at a time and keep the report concise and specific.