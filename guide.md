
Phase 1 — Azure-Side DNS Validation (READ-ONLY)

Goal:
Independently validate the Azure DNS configuration and identify the evidence-based root cause of the current DNS issue.

Instructions:

1. Check Azure CLI access:
   - Run `az account show`.
   - If authentication is missing, check whether an existing Azure CLI session or accessible profile is available.
   - Do not run `az login` or change CLI profiles automatically.
   - If authentication is unavailable, report the exact blocker and stop Azure-side checks.

2. If authenticated, identify the correct project subscription and validate:
   - VNet DNS server configuration.
   - Private Endpoint connection state and associated NIC private IP.
   - Relevant Private DNS Zone and expected A record.
   - Private DNS Zone VNet links and their provisioning states.
   - DNS zone, endpoint, VNet and VM resource relationships.

3. VM-side DNS validation:
   - If an existing authorized SSH/Bastion session is available, collect:
     - `cat /etc/resolv.conf`
     - `resolvectl status`
     - `dig <expected-private-fqdn>`
   - Do not create a VM, open SSH access, change network rules, or initiate a new connection requiring configuration changes.
   - If VM access is unavailable, report the missing evidence.

4. Report actual command outputs or concise evidence:
   - Check performed.
   - Resource name and resource group.
   - Expected vs actual result.
   - Pass / Fail / Blocked.
   - Exact error message, if any.
   - Evidence-based findings and remaining unknowns.

5. Root-cause decision:
   - Identify a root cause only when supported by collected evidence.
   - Clearly distinguish confirmed findings from hypotheses.
   - If evidence is insufficient, state exactly what is missing.

STRICT SAFETY:
- READ-ONLY ONLY.
- Do not edit, create, delete, import, or deploy any resource.
- Do not modify Terraform, YAML, scripts, provider configuration, or state.
- Do not run Terraform apply/destroy or any remediation.
- Do not print secrets, credentials, tokens, or sensitive connection strings.
- Do not claim a check passed unless its result was actually verified.

Final response:
Provide a concise DNS validation report with:
1. Azure authentication status.
2. Validation results for every check.
3. Actual evidence and errors.
4. Confirmed root cause, or why it remains unconfirmed.
5. Exact next step required to unblock Phase 1.

Stop after reporting. Wait for approval before making any changes.
