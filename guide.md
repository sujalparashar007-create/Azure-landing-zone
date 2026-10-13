
Perform a read-only review of the planned null_resource.yaml_flatten replacement.

1. Inspect its declaration and provisioners in modules/yaml-processing/main.tf.
2. Explain exactly what executes when network_yaml_file_hash changes.
3. Identify any generated files, local files, or external side effects that the provisioner may modify.
4. Confirm whether the replacement is the expected result of the 16 network.yaml reference migrations.
5. Verify that the reviewed plan contains no Azure resource actions.

STRICT RULES:
- Do not run apply, destroy, or state-changing commands.
- Do not rerun the provisioner manually.
- Do not modify any files.
- Ignore guide.md.
- Do not make unrelated changes.

Return the provisioner behaviour, expected side effects, and whether the replacement is consistent with the intended YAML migration.
