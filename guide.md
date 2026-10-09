Verify the Azure Firewall SKU placement mismatch.

1. Inspect modules/network/main.firewall.tf and identify the exact body structure for azapi_resource.firewall.
2. Confirm whether sku is nested inside properties or is a top-level sibling.
3. Compare the source with the latest Terraform plan generated from modules/network/.
4. Identify the exact cause of the mismatch. Do not modify files or run apply.
5. Report the relevant source structure and the minimum required fix, if any.