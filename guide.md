RESUME PHASE A. A previous assistant (Copilot) stopped mid-task. Do NOT assume its edits are correct or complete.

CONTEXT: Terraform project "azure-landing-zone". Each module under modules/ is its own root with local state. Shared helper modules/yaml-processing. Architecture must stay: YAML -> yaml-processing -> null_resource + for_each -> modules -> Azure. Terraform v1.15.5, azapi 2.13.0, azurerm 4.81.0.
SCOPE: modules/network and modules/resource-groups ONLY. Do not touch any other module or YAML.

GOAL: replace data.azurerm_subscriptions.available with data "azapi_resource_list" (type "Microsoft.Resources/subscriptions@2022-12-01", parent_id "/") in both modules, same pattern and naming in both (symmetry). Locals must keep identical behavior: match display_name from YAML, state == "Enabled", return subscription_id. Verify the output shape against the installed azapi 2.13.0 schema; do not guess.

STEP 0 - INSPECT FIRST (read-only):
1. git status and git diff for both modules.
2. List what Copilot already changed in modules/network/main.vnet.tf and modules/resource-groups/main.tf, and whether the edits are complete, syntactically valid and consistent between the two modules.
3. grep both modules for every remaining reference to azurerm_subscriptions / data.azurerm_subscriptions (network has ~13 consumer files).

STEP 1 - FINISH:
- Fix or complete only what is missing or broken so both modules use the azapi lookup identically. No behavior change, no renamed outputs, no new features.
- KEEP the azurerm provider block and required_providers for now. Do not remove them.

RULES: no terraform plan/apply/state/import commands, no terraform init -upgrade, no git commit/push. Never print secrets. Run only: terraform fmt and terraform validate in both modules (if validate fails because init is missing, just report it, do not run init).

REPORT (short): files changed with file:line, the final data block, how the output is parsed, what Copilot left incomplete, validate result.