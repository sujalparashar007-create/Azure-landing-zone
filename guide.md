Fix ONLY the built-in-policy `effect` handling.

Current error:
`UndefinedPolicyParameter: parameter(s) 'effect' are not defined in the policy definition`

Problem:
The module currently passes YAML `effect` as an assignment parameter to every built-in policy, but some built-in policy definitions do not declare an `effect` parameter.

Fix the implementation correctly:

1. Inspect each built-in policy definition's actual parameters.
2. Pass YAML `effect` ONLY when the referenced policy definition actually declares an `effect` parameter.
3. If the policy definition does not declare `effect`, do NOT send it in `parameters`.
4. Keep the YAML `effect` value intact and YAML-driven.
5. Do NOT hard-code which policy names support `effect`.
6. Do NOT bring back the old `builtin_definition_names` allowlist.
7. Preserve the existing `for_each`, policy names, scopes, and Terraform addresses.
8. Do NOT modify YAML unless the existing YAML structure itself is invalid.
9. Do NOT touch state.
10. Do NOT create extra files.

After the fix run:
terraform fmt
terraform init
terraform validate
terraform plan

Do NOT run apply yet.

Report:
- how the module detects whether `effect` is a valid parameter
- which current built-in policies receive `effect`
- which do not
- plan result
- any remaining issue