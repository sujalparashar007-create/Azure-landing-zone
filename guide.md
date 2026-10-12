Remove VPN from network config. Scope: network.yaml, modules/yaml-processing (network parts), modules/network only.

REMOVE:
1. network.yaml: features.vpn_gateway, gateways.vpn_gateway (vng-prod, lng-onprem-hq, conn-onprem-hq), public_ips pip-vpn-gw, external_references vpn_psk_secret_name, VPN dependency comment (line ~48).
2. yaml-processing/main.tf: the vpn_gateway public-IP filter (lines ~186-187) and any VPN-only validation/locals left behind.
3. README/comments: VPN mentions only.

KEEP UNTOUCHED: GatewaySubnet, rt-gateway + its routes, RouteServerSubnet, all peering code/YAML (allowGatewayTransit, useRemoteGateways), remote_gateways_ready, everything else.

Rules: no state commands, no apply, no new features, no other cleanup. Keep outputs of other components unchanged.

THEN run: terraform fmt, validate. Do NOT run plan (I run it in Git Bash because of TF_VAR_admin_password).

REPORT: files changed (file:line), what was removed, and confirm nothing else was touched. Short.