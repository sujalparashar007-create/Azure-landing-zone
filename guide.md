Fix the current Budget module issues.

1. In `modules/yaml-processing/config/azure.yaml`, replace all budget notification recipients:
   `azure-security-alerts@example.com`
   `azure-ops-alerts@example.com`
   with:
   `sujalparashar700@gmail.com`

2. Fix the current Budget plan error:
   `azurerm_consumption_budget_subscription.subscription_id` is receiving a bare subscription GUID.
   It must receive `/subscriptions/<subscription-id>`.

3. Keep subscription lookup dynamic and YAML-driven. Do NOT hard-code subscription IDs.

4. Do not change:
   - budget scopes
   - budget amounts
   - thresholds
   - time grain
   - budget mappings
   - existing completed modules

5. Do NOT create a Resources module.

6. Do NOT run `terraform plan`, `terraform apply`, or `terraform destroy`.

7. Only run:
   - `terraform fmt`
   - `terraform validate`

Report the files changed, exact fixes, and validation results.