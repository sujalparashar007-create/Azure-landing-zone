Fix ONLY the current Terraform AzureRM provider SubscriptionNotFound error.

Current error:
SubscriptionNotFound: The subscription 'ec8f75d9-5069-473c-aa6e-ffaf7e8bab98' could not be found.

Task:
1. Inspect the current providers.tf and all active network module/provider configuration.
2. Trace exactly where subscription ID `ec8f75d9-5069-473c-aa6e-ffaf7e8bab98` is coming from.
3. Compare it with the subscription references/resolution already used by the existing project.
4. Identify the correct existing subscription-resolution mechanism and fix the provider configuration accordingly.
5. Do NOT guess, invent, or hard-code any subscription ID.
6. Do NOT change network.yaml, azure.yaml, custom-policy.yaml, or the completed ALZ modules.
7. Do NOT modify the NSG/subnet implementation; that issue has already been fixed separately.
8. Do NOT redesign the provider architecture.
9. Do NOT run terraform plan, apply, destroy, or any Azure resource-changing command.
10. Keep the fix minimal and limited to the actual SubscriptionNotFound cause.

Protected components — DO NOT TOUCH:
- modules/management-group/
- modules/resource-group/
- modules/iam/
- modules/policies/
- modules/budget/
- config/azure.yaml
- config/custom-policy.yaml
- network.yaml
- NSG/subnet implementation

Before finishing:
- Run only safe static checks such as terraform fmt/validate if required.
- Report the exact root cause, files changed, and exact fix.
- Confirm that no subscription ID was guessed or hard-coded.
- Do NOT run terraform plan/apply. I will run them manually.