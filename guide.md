Perform a final read-only pre-apply verification for Azure Landing Zone Terraform Phase 9 Step 4 only. Do not edit any files and do not run terraform apply, import, destroy, or any Azure resource mutation.

1. Inspect the current network.yaml, modules/yaml-processing outputs, and modules/network/main.storage-private-endpoint.tf.
2. Verify that storage account stappdatahub resolves to subscription sub-shared-ops and resource group rg-shared-ops; SKU Standard_LRS; kind StorageV2; access tier Hot; public network access disabled; HTTPS-only enabled; minimum TLS TLS1_2.
3. Verify private endpoint pe-stappdata-blob targets that storage account, uses the existing vnet-spoke-shared/snet-shared-data subnet, and has groupId blob.
4. Verify its Private DNS Zone Group references the existing privatelink.blob.core.windows.net zone and does not create duplicate zones or links.
5. Perform a read-only, definitive Azure Storage Account name-availability check for stappdatahub using a supported Azure command/API. If unavailable or inconclusive, clearly report that; do not create the account or change its name.
6. Check that existing subnet settings and unrelated resources are not modified.
7. Run terraform plan from modules/network only if it is read-only and safe. Report the final plan summary and every create/update/replace/destroy action.

Return PASS or BLOCKED for each check. Do not apply. Do not make assumptions or modify any file.