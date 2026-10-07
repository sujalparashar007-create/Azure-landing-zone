Fix the remaining P3 NSG rule API errors only.

Current issue:
- 9 of 12 NSG rules are already created.
- Only these 3 rules fail:
  - nsg-prod/deny-internet-inbound
  - nsg-spoke-shared-app/deny-internet-inbound
  - nsg-spoke-payments-app/deny-internet-inbound
- Current payload uses:
  sourceAddressPrefixes = ["Internet"]
- Azure still rejects "Internet" with:
  SecurityRuleParameterContainsUnsupportedValue.

Required:
1. Inspect the current NSG rule payload and Azure API requirements.
2. Correctly represent the "Internet" service tag for these rules.
3. Keep ["*"] wildcard mapping correct.
4. Keep CIDR/source-prefix lists correct.
5. Do not change network.yaml or security semantics.
6. Do not modify the 9 successful rules or existing NSGs.
7. Preserve:
   parent_id = azapi_resource.nsg[each.value.nsg_name].id
8. Change only the minimum required code.
9. Run terraform fmt, terraform validate and terraform plan only.
10. DO NOT run terraform apply.

Expected:
- Only the 3 failed rules planned for creation.
- 3 to add, 0 to change, 0 to destroy.
- No NSG recreation.
- No changes to the 9 successful rules.

Return the exact fix, files changed, validation result and plan result.