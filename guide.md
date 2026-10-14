
Resume Phase 1 — Azure-side DNS validation.

Azure CLI is authenticated in my terminal. `az account list` shows four enabled subscriptions, including Production Network.

Subscription ID:
8e3af5dd-dd04-45fb-9986-23ac2180a4cf

1. First run `az account show` in your own execution environment.
2. If authenticated, verify the active subscription ID. If not, report the exact environment/profile error; do not attempt login or change profiles.
3. If the correct subscription is active and accessible, perform the previously requested read-only DNS checks:
   - VNet DNS configuration
   - Private Endpoint connection state and NIC private IP
   - Private DNS Zone A record and VNet links
   - Relevant DNS/VNet/VM relationships
4. Collect VM-side DNS evidence only if an existing authorized session is available.
5. Report exact results, resource names, errors, and missing evidence. Distinguish confirmed findings from hypotheses.

STRICT: Read-only only. No file edits, Terraform changes, resource modifications, or remediation. Do not assume your execution environment shares my terminal's Azure CLI session.
