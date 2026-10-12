Fix the unsupported AzAPI ignore_body_changes configuration.

File: modules/network/main.storage-private-endpoint.tf

1. Remove the unsupported wildcard ignore_body_changes path.
2. Preserve privateLinkServiceConnectionState in the request body.
3. For automatic connections, configure description as "Auto-Approved" to match Azure's returned value. Preserve the existing manual-connection Pending behavior and description.
4. Do not change any other Private Endpoint properties or resources.
5. Run terraform fmt, terraform validate for both modules, and git diff --check.
6. Do not run plan/apply, modify state, or make Azure changes.
7. Show the exact diff and validation results.