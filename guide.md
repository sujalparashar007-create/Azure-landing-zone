Implement only the approved minimal cleanup in modules/yaml-processing/config/network.yaml.

1. Correct the stale header comments that refer to external_references and explain that subscription/resource-group references are resolved through the existing references block.
2. Update the tags comment to accurately state that supported resource definitions inherit defaults.tags where implemented, while the current VNet and subnet implementations do not assign tags. Do not add tags to resources or change implementation code.
3. Remove the trailing whitespace reported at line 34 without changing the meaning or formatting of surrounding content.

Strict exclusions:
- Do not change either spoke-to-hub use_remote_gateways value.
- Do not change remote_gateways_ready or variables.tf.
- Do not add/remove feature flags or YAML sections.
- Do not edit guide.md or any other file.
- Do not run terraform apply/destroy/import or change Terraform state/Azure resources.

Before editing, inspect the current diff and preserve unrelated existing changes. After editing, show the exact diff and run git diff --check. Confirm only the intended lines in network.yaml changed. Do not claim success unless command output confirms it. Stop and report if the current file differs materially from the reviewed findings; do not overwrite or revert unrelated user changes.