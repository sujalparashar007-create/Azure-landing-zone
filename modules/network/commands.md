# Hub-and-Spoke Network Validation

Main validation commands and their recorded outputs, in test order. Each step has a one-line purpose, the command, and the output.

| Step | Area | Run from |
|---|---|---|
| 1 | Azure Firewall health | Git Bash (Azure CLI) |
| 2 | VNet peerings | Git Bash (Azure CLI) |
| 3 | NAT Gateway egress (hub VM) | Git Bash + `vm-test-hub` |
| 4 | Spoke to hub connectivity | `vm-test-shared` |
| 5 | Spoke egress through Firewall | `vm-test-shared` + Git Bash |
| 6 | Private DNS + Private Endpoint | `vm-test-hub` + Git Bash |

---

## 1. Azure Firewall health

Firewall `afw-prod` is deployed, has private IP `10.0.1.4`, and uses policy `fwp-prod`.

```bash
az network firewall show --subscription 8e3af5dd-dd04-45fb-9986-23ac2180a4cf -g rg-prod-network -n afw-prod --query "{state:provisioningState,sku:sku,privateIp:ipConfigurations[0].privateIPAddress,policy:firewallPolicy.id}" -o json
```

```json
{
  "policy": "/subscriptions/8e3af5dd-dd04-45fb-9986-23ac2180a4cf/resourceGroups/rg-prod-network/providers/Microsoft.Network/firewallPolicies/fwp-prod",
  "privateIp": "10.0.1.4",
  "sku": {
    "name": "AZFW_VNet",
    "tier": "Standard"
  },
  "state": "Succeeded"
}
```

---

## 2. VNet peerings

All hub-and-spoke peerings are connected from both sides.

Hub side:

```bash
az network vnet peering list --subscription 8e3af5dd-dd04-45fb-9986-23ac2180a4cf -g rg-prod-network --vnet-name vnet-prod-hub --query "[].{name:name,state:peeringState,sync:peeringSyncLevel}" -o table
```

```text
Name                        State      Sync
--------------------------  ---------  -----------
peer-hub-to-spoke-payments  Connected  FullyInSync
peer-hub-to-spoke-shared    Connected  FullyInSync
```

Shared spoke side:

```bash
az network vnet peering list --subscription ad8d35e1-6b28-4d24-ad9a-a51dc655c3ad -g rg-shared-ops --vnet-name vnet-spoke-shared --query "[].{name:name,state:peeringState,sync:peeringSyncLevel}" -o table
```

```text
Name                      State      Sync
------------------------  ---------  -----------
peer-spoke-shared-to-hub  Connected  FullyInSync
```

Payments spoke side:

```bash
az network vnet peering list --subscription 3fe97833-5b60-4af0-8c9a-4478460d7705 -g rg-prod-payment-app --vnet-name vnet-spoke-payments --query "[].{name:name,state:peeringState,sync:peeringSyncLevel}" -o table
```

```text
Name                        State      Sync
--------------------------  ---------  -----------
peer-spoke-payments-to-hub  Connected  FullyInSync
```

---

## 3. NAT Gateway egress (hub VM)

The hub VM leaves the network through the NAT Gateway public IP.

Expected NAT public IP:

```bash
az network public-ip show --subscription 8e3af5dd-dd04-45fb-9986-23ac2180a4cf -g rg-prod-network -n pip-nat-hub --query ipAddress -o tsv
```

```text
20.115.28.183
```

Public IP seen from `vm-test-hub`:

```bash
curl -s https://ifconfig.me; echo
```

```text
20.115.28.183
```

---

## 4. Spoke to hub connectivity (`vm-test-shared`)

The shared spoke VM reaches the hub VM `10.0.4.4` over the peering.

VM network address:

```bash
ip addr
```

```text
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:4e:f1:ea brd ff:ff:ff:ff:ff:ff
    inet 10.1.0.4/24 metric 100 brd 10.1.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe4e:f1ea/64 scope link 
       valid_lft forever preferred_lft forever
```

ICMP to the hub VM:

```bash
ping -c 4 10.0.4.4
```

```text
PING 10.0.4.4 (10.0.4.4) 56(84) bytes of data.
64 bytes from 10.0.4.4: icmp_seq=1 ttl=64 time=1.18 ms
64 bytes from 10.0.4.4: icmp_seq=2 ttl=64 time=0.719 ms
64 bytes from 10.0.4.4: icmp_seq=3 ttl=64 time=0.651 ms
64 bytes from 10.0.4.4: icmp_seq=4 ttl=64 time=0.671 ms

--- 10.0.4.4 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3045ms
rtt min/avg/max/mdev = 0.651/0.805/1.181/0.218 ms
```

SSH port to the hub VM:

```bash
nc -vz -w 3 10.0.4.4 22
```

```text
Connection to 10.0.4.4 22 port [tcp/ssh] succeeded!
```

---

## 5. Spoke egress through Azure Firewall (`vm-test-shared`)

The spoke default route sends internet traffic to the Firewall, so the VM shows the Firewall public IP.

Public IP seen from `vm-test-shared`:

```bash
curl -sS --connect-timeout 10 https://api.ipify.org
```

```text
52.149.233.47
```

Firewall public IP (`pip-afw-prod`):

```bash
az network public-ip show --subscription 8e3af5dd-dd04-45fb-9986-23ac2180a4cf -g rg-prod-network -n pip-afw-prod --query ipAddress -o tsv
```

```text
52.149.233.47
```

HTTPS response from the internet:

```bash
curl -sSI --connect-timeout 10 https://www.microsoft.com
```

```text
HTTP/2 200 
server: AkamaiGHost
mime-version: 1.0
content-type: text/html
content-length: 419
expires: Tue, 13 Oct 2026 19:04:24 GMT
cache-control: max-age=0, no-cache, no-store
pragma: no-cache
date: Tue, 13 Oct 2026 19:04:24 GMT
```

---

## 6. Private DNS + Private Endpoint (`stappdatahub`)

The storage account is reached only through its Private Endpoint IP `10.1.1.4`.

VM DNS configuration (`vm-test-hub`):

```bash
cat /etc/resolv.conf
```

```text
nameserver 127.0.0.53
search mnbtjkt5l1eurobpham0kzra1d.bx.internal.cloudapp.net
```

Storage name resolves through the `privatelink` zone to the private IP:

```bash
nslookup stappdatahub.blob.core.windows.net
```

```text
Server:127.0.0.53
Address:127.0.0.53#53

Non-authoritative answer:
stappdatahub.blob.core.windows.netcanonical name = stappdatahub.privatelink.blob.core.windows.net.
Name:stappdatahub.privatelink.blob.core.windows.net
Address: 10.1.1.4
```

Same result from the system resolver:

```bash
getent ahostsv4 stappdatahub.blob.core.windows.net
```

```text
10.1.1.4
```

TCP port 443 reaches the Private Endpoint:

```bash
nc -vz -w 5 stappdatahub.blob.core.windows.net 443
```

```text
Connection to stappdatahub.blob.core.windows.net (10.1.1.4) 443 port [tcp/https] succeeded!
```

HTTPS reaches the private IP (HTTP 400 is a normal reply for a request without a container or token):

```bash
curl -sS -o /dev/null -w 'HTTP Status: %{http_code} | Remote IP: %{remote_ip}\n' --connect-timeout 5 https://stappdatahub.blob.core.windows.net/
```

```text
HTTP Status: 400 | Remote IP: 10.1.1.4
```

Storage account public network access is disabled:

```bash
az storage account show --subscription "ad8d35e1-6b28-4d24-ad9a-a51dc655c3ad" --resource-group rg-shared-ops --name stappdatahub --query "{Name:name,PublicNetworkAccess:publicNetworkAccess,DefaultAction:networkRuleSet.defaultAction,ProvisioningState:provisioningState}" --output json
```

```json
{
  "DefaultAction": "Allow",
  "Name": "stappdatahub",
  "ProvisioningState": "Succeeded",
  "PublicNetworkAccess": "Disabled"
}
```

---

## Limits of this validation

- Authenticated Blob read/write: not tested.
- `corp.example.com` forwarding: lookups time out because no DNS server exists at `192.168.100.10` (expected).
- Output of the spoke tests is recorded for `vm-test-shared` only.
- Firewall logs and diagnostics: not configured (deferred).