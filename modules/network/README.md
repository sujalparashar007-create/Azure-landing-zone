# Network module

This flat Terraform module creates the VNets, subnets, network security groups, security rules, and subnet-to-NSG associations defined by `network.yaml`. The `yaml-processing` child module reads `azure.yaml` and `network.yaml`, resolves their references, and supplies the flattened values consumed here. NSGs are attached directly in subnet PUT bodies because a later subnet PUT would otherwise remove an NSG attached by a separate PATCH.

## Files

- `main.vnet.tf`: virtual networks.
- `main.subnet.tf`: subnets and inline NSG associations.
- `main.nsg.tf`: NSGs and rules.
- `providers.tf`: Terraform and provider requirements/configuration.
- `variables.tf`: shared YAML paths and Azure API retry settings.
- `outputs.tf`: resource ID maps.

Run all commands from `modules/network`:

```text
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Do not run `apply`, `destroy`, or CLI import as part of validation.

## Adding a component

Add a new `main.<component>.tf` file. Append any new variables and outputs to the shared `variables.tf` and `outputs.tf` files. If the component needs a new provider, update `providers.tf`. Keep resource values driven by the flattened YAML data and preserve the existing dependency relationships.

## YAML flattening

Changing either YAML input changes the `yaml_flatten` hash trigger. A plan can therefore show one destroy and one add for `module.yaml_processing.null_resource.yaml_flatten`; this is only the local processing resource and is not an Azure resource.

## Azure 409 handling

The `azapi_retry` variable retries transient `AnotherOperationInProgress`, `RetryableError`, and `ReferencedResourceNotProvisioned` responses with bounded backoff. The module also keeps explicit VNet, NSG, subnet, and rule dependencies to avoid invalid ordering. If Azure still reports a 409, inspect the plan and provider response before changing concurrency; do not add broad sleeps or serialize unrelated resources.
