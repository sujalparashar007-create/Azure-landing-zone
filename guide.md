TASK: Validate the finished modules/network module (vnet, subnet, nsg flat module). The fresh apply is done and the state is live. PHASE A is a READ-ONLY audit. Do not change files until I say "go".

HARD RULES
- No terraform apply / destroy / import, no state commands, no moved blocks.
- Do not touch other modules, azure.yaml, custom-policy.yaml, network.yaml (content).
- Any later fix must keep `terraform plan` at "No changes".
- Do not redesign the existing architecture.
- Preserve the current YAML → yaml-processing → modules/network → Azure resource flow.

PHASE A - AUDIT (read-only)

1. STRUCTURE AND WIRING
   - List every file in modules/network and its role. Expected: main.vnet.tf, main.subnet.tf, main.nsg.tf, ONE providers.tf, ONE variables.tf, ONE outputs.tf, .terraform.lock.hcl. Flag anything else.
   - Every variable is used; every output is valid and used or intentional; no dead locals; no duplicated blocks; descriptions and types present on variables and outputs; consistent naming (component prefix on locals).
   - Print the dependency chain from `terraform graph` (summarize): VNets/NSGs -> rules/subnets -> associations.
   - Confirm the module reads azure.yaml / network.yaml only through ../yaml-processing and that it does not depend on any other module's state.

2. STALE REFERENCES (search the WHOLE repo, not only modules/network)
   - old paths and addresses: modules/vnet, modules/subnet, modules/nsg, module.vnet, module.subnet, module.nsg, azapi_resource.this, imports.tf, external_references, old field names (subscription / resource_group where the YAML now uses *_ref aliases).
   - README, guide.md, docs and comments that describe the old structure or old commands.
   - leftovers: tfplan, *.tfstate*, .terraform/ in old folders, tracked files that should be ignored (git ls-files).
   Report file:line for every hit.

3. SYNTAX AND CONFIGURATION
   - terraform fmt -check -recursive, terraform validate, terraform plan (must be "No changes"), terraform plan -refresh-only (drift check).
   - Run tflint or trivy/checkov only if already installed; do not install anything.
   - YAML vs state: every vnet, subnet, NSG, rule and association defined in network.yaml exists in state and vice versa (expected 3 / 11 / 5 / 12 / 5, plus the yaml_flatten null_resource). List mismatches.

4. AZURE NETWORK OPERATION CONCURRENCY / 409 AUDIT
   - Specifically inspect the current subnet, NSG, NSG-rule and NSG-to-subnet-association resources for possible Azure Network API concurrency issues.
   - The project has repeatedly experienced HTTP 409 `AnotherOperationInProgress` during both `terraform apply` and `terraform destroy`, including subnet operations and NSG-to-subnet associations.
   - Identify where Terraform may currently allow multiple dependent Azure Network operations on the same VNet/subnet hierarchy to execute concurrently.
   - Inspect the dependency graph and current `for_each` relationships carefully.
   - Determine whether explicit `depends_on` relationships are needed between:
       a) VNet and subnet operations
       b) subnet creation/update and NSG association
       c) NSG creation/rules and NSG association
       d) other network resources that currently have a real ordering dependency
   - Identify where a small `time_sleep` delay would be appropriate ONLY if Azure needs propagation/settling time after a dependent network operation.
   - Do NOT recommend adding sleeps everywhere. Keep any proposed delay minimal and targeted.
   - Check both CREATE/APPLY and DESTROY ordering implications. A dependency that helps apply must not introduce an invalid or unnecessary destroy dependency.
   - Do not change files in PHASE A.
   - Report the exact file:line where each proposed `depends_on` or `time_sleep` should be added, why it is required, what resource it should depend on, and whether it is expected to preserve "No changes".
   - If the current dependency graph is already sufficient and no code change is justified, explicitly report that.
   - Do NOT treat the fact that the latest apply succeeded as proof that the concurrency issue is permanently fixed. The audit must inspect the implementation itself.

5. HARD-CODING
   Grep all .tf files for literals: subscription GUIDs, subscription / resource group / resource names from the YAML, locations, CIDRs, IPs, API versions, tags, absolute paths. For each hit give file:line and classify: OK (a named constant in one central local/variable) or HARD-CODED (must come from YAML or a variable). Everything environment-specific must come from the YAML or variables.

6. REUSABILITY TEST (no repo changes)
   - Copy network.yaml to a temp folder outside the repo. In the COPY add one new subnet, one new NSG with one rule and the matching association. Point the module at the copy (through the existing yaml variables, or the same mechanism the module already uses) and run `terraform plan` only.
   - Expected: ONLY the new items show as "to add"; existing resources unchanged. Then delete the temp copy.
   - If the module cannot be pointed at another YAML without editing code, report that as a reusability gap.

7. FUTURE-READINESS
   - Confirm that adding a new component only needs a new main.<component>.tf plus appended variables/outputs, with no edits to existing component files. Report what would break that.
   - Check header comments in each file (purpose, inputs from YAML, outputs) and whether a short README exists in modules/network (how to run, how to add a component).

8. SCOPE CHECK
   - `git status` and `git diff --stat` outside modules/network must show only the expected changes (old module folders removed, .gitignore). Flag anything else.

PHASE A REPORT
A table:

check | PASS / WARN / FAIL | finding with file:line | proposed fix | type = SAFE (no plan change) or DECISION (needs my choice)

For the 409 concurrency section, clearly separate:
- Current dependency behavior
- Root cause / likely concurrency point
- Proposed `depends_on`
- Proposed `time_sleep`
- Apply impact
- Destroy impact

STOP and wait for my "go".

PHASE B - after my "go"
Apply only the SAFE fixes I approve (comments, headers, README, unused variable cleanup, centralizing literals into locals/variables, stale doc references, and approved targeted `depends_on` / `time_sleep` changes).

For any approved `depends_on` / `time_sleep` change:
- Keep the change minimal and targeted.
- Do not redesign the module architecture.
- Do not add unnecessary sleeps or serialise unrelated resources.
- Preserve the existing for_each-based implementation.
- After each fix run fmt, validate and plan; plan must stay "No changes".
- If it does not, revert that fix and tell me.
- Do not commit.

FINAL REPORT:
- what was fixed
- what is left (DECISION items)
- exact 409 concurrency fix, if any
- final plan result
- git status