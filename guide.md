Revert only the temporary AzureRM subscription_id wiring added to fix the CLI default subscription issue.

1. Remove `subscription_id = var.subscription_id` from modules/network/providers.tf.
2. Remove the subscription_id variable block from modules/network/variables.tf.
3. Delete modules/network/terraform.tfvars.example if it was created only for this temporary subscription workaround.
4. Do NOT modify or revert the NSG association fix:
   - keep azapi provider `ignore_no_op_changes = false`
   - keep removal of subnet `ignore_missing_property`
   - keep inline subnet `networkSecurityGroup` association
5. Do not modify yaml-processing, network.yaml, NSG resources/rules, or any completed ALZ modules.
6. Do not run terraform plan/apply/destroy.
7. Run only terraform fmt and terraform validate, then report the exact files changed.