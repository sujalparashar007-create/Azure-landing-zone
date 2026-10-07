TASK: Pure restructuring of the network.yaml-related Terraform modules. NO logic, resource or behavior change.

CONTEXT
- The network modules are already implemented, validated and working. Treat their code as correct.
- Same workflow and execution as today; each module is still deployed independently.

DO NOT TOUCH
- azure.yaml, custom-policy.yaml, network.yaml (content)
- Modules for management groups, subscriptions, resource groups, built-in policy, custom policy, iam, yaml-processing
- Any Azure resource: NO terraform apply / destroy / import / state commands. Plan only.

TARGET STRUCTURE
- One parent folder: modules/network/
- Inside it, each existing network-related module becomes its own subfolder (keep the current module names, do not rename or invent modules).
- Each subfolder contains ONLY ONE file: main.tf.

STEPS
1. Inventory: list every network.yaml-related module (folder, files, who calls it). Print "current -> target path" table. STOP and wait for my "go" before moving anything.
2. Move with `git mv` (keep history) into modules/network/<module>/. Keep .terraform.lock.hcl, tfvars and any local state files together with their folder. Do not delete them.
3. In each module merge providers.tf, variables.tf, outputs.tf (and any other .tf) into main.tf in this order: terraform{} + required_providers -> provider blocks -> variables -> locals/data -> resources -> outputs. Copy content verbatim: same names, same resource labels, same for_each keys, same versions, same defaults. Only one terraform{} block per module. Then remove the merged files.
4. Fix only paths broken by the move: relative `source = "../x"`, file()/fileset()/path.module paths to network.yaml and other config (the folder is now one level deeper), backend path settings, README/doc references.
5. Do not change any resource address, so the state stays valid.

VALIDATION (per moved module)
- terraform fmt -check, terraform init, terraform validate
- terraform plan must show "No changes". Any create/update/destroy/replace -> STOP, revert that module with git, and report.

FINAL REPORT (short)
Before/after tree, per-module list of merged files, paths fixed, validate/plan result per module, git status. Do not commit.