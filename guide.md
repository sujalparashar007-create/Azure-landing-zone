Fix only the currently identified IAM blockers.

1. Keep modules/iam fully standalone and YAML-driven.
2. Keep `sujalparashar700@gmail.com` as the IAM principal in azure.yaml.
3. Since this is an external/#EXT# user, change the azuread_user lookup so it reliably resolves the existing user object without hard-coding the principal into the Terraform resource logic.
   Known existing object ID:
   7452eab3-30b8-42b8-a9d4-a3d07a495ad3
   Prefer a YAML-driven solution; do not hard-code this ID in main.tf.
4. Reconcile the IAM role name `Security Administrator` with the role that actually exists in this tenant: `Security Admin`.
   Keep the role assignment YAML-driven; do not hard-code role IDs.
5. Fix the subscription-level IAM flattening issue in `modules/yaml-processing` so the existing subscription-scoped `Key Vault Administrator` assignment under `sub-shared-ops` reaches `iam_assignments`.
6. Do not change unrelated modules or existing IAM scopes/roles.
7. Preserve all existing `for_each` logic.
8. Do not remove any IAM assignment.
9. Do not create a root module or any extra files.
10. After edits, only run `terraform fmt` and `terraform validate` for the affected module(s). Do NOT run plan/apply/destroy.
11. Report exactly which files changed and summarize the fixes and validation results.