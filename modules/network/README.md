# Network module

This flat Terraform module creates the VNets, VNet peerings, subnets, route tables and routes, enabled Public IPs, NAT Gateways, network security groups, security rules, and subnet associations defined by `network.yaml`. The `yaml-processing` child module reads `azure.yaml` and `network.yaml`, resolves their references, and supplies the flattened values consumed here. NSGs, route tables, and NAT Gateways are attached directly in subnet PUT bodies because a later subnet PUT would otherwise remove an association attached by a separate PATCH.

## Files

- `main.vnet.tf`: virtual networks.
- `main.peering.tf`: VNet peerings.
- `main.public-ip.tf`: enabled Public IPs.
- `main.nat-gateway.tf`: enabled NAT Gateways.
- `main.subnet.tf`: subnets and inline NSG associations.
- `main.route-table.tf`: route tables and routes.
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

`remote_gateways_ready` defaults to `false` because Azure rejects
`useRemoteGateways=true` until the remote VNet has a deployed gateway. The
YAML `use_remote_gateways` value remains the source of truth; the VPN gateway
phase must set this capability gate to `true` to reconcile the deferred
spoke-to-hub peerings.

## Adding a component

Add a new `main.<component>.tf` file. Append any new variables and outputs to the shared `variables.tf` and `outputs.tf` files. If the component needs a new provider, update `providers.tf`. Keep resource values driven by the flattened YAML data and preserve the existing dependency relationships.

## YAML flattening

Changing either YAML input changes the `yaml_flatten` hash trigger. A plan can therefore show one destroy and one add for `module.yaml_processing.null_resource.yaml_flatten`; this is only the local processing resource and is not an Azure resource.

## Azure 409 handling

The `azapi_retry` variable retries transient `AnotherOperationInProgress`, `RetryableError`, and `ReferencedResourceNotProvisioned` responses with bounded backoff. The module also keeps explicit VNet, NSG, subnet, and rule dependencies to avoid invalid ordering. If Azure still reports a 409, inspect the plan and provider response before changing concurrency; do not add broad sleeps or serialize unrelated resources.
