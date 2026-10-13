Complete the remaining validation for the two new spoke VMs.

1. Inspect the existing hub VM and both new VM definitions. Confirm they use the intended admin username, authentication method, and existing var.admin_password mechanism. Do not expose or print any password.

2. Verify:
   - vm-test-shared → vnet-spoke-shared / snet-shared-app
   - vm-test-payments → vnet-spoke-payments / snet-payments-app
   - NICs are generated correctly and attached to their respective VMs.
   - Both VMs have no public IP.
   - Both VMs use the correct shared_services/payments subscription and resource-group references.
   - Existing Bastion can be used to access both VMs.
   - Payments NSG SSH rule allows only TCP 22 from 10.0.2.0/26, with no priority conflict.
   - Shared Spoke's existing NSG permits Bastion SSH.
   - Disabled DNAT remains disabled.

3. Review the YAML flattening logic, VM/NIC resource loops, dependencies, and reference-resolution validations. Ensure the new definitions flow through the existing YAML-driven AzAPI architecture without duplicated hard-coded configuration.

4. Run terraform fmt and terraform validate for modules/network and modules/yaml-processing if needed. Do not change unrelated files or modules. Ignore guide.md completely.

5. Do not set, request, print, or modify the password. Do not run terraform plan; I will set the password and run the plan myself in my terminal.

6. Do not run terraform apply, terraform destroy, or state-changing commands.

7. Report:
   - Whether the same existing var.admin_password works for all three VMs.
   - Any issues found and the exact files/lines involved.
   - Validation results.
   - Whether the implementation is ready for me to run terraform plan.

Stop after the audit. Do not apply anything or make unnecessary changes.