# Apex Industries — Cloud Infrastructure Training Series
## VNet Peering — Connecting Two Isolated Networks
**Project Code:** `APX-INFRA-004` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.10/session

---

> **From your Team Lead:** Every VNet you've built so far has
> been its own isolated island — nothing outside it could reach
> in, and it couldn't reach out. Most real orgs have MULTIPLE
> VNets — one per team, one per environment, one per region — and
> they need specific ones to talk to each other. VNet Peering is
> how you connect two networks without routing traffic through
> the public internet at all. — *Morgan Chen*

---

## 1. Overview — The New Concept

### What VNet Peering Actually Does

Two completely separate Virtual Networks, each with their own
address space, get connected directly — traffic between them
flows over Azure's private backbone network, never touching the
public internet, and typically with lower latency than a VPN.

```
VNet A (10.0.0.0/16)  <---- Peering ---->  VNet B (10.1.0.0/16)

Before peering: VMs in A cannot reach VMs in B at all
After peering:  VMs in A can reach VMs in B by private IP,
                as if they were on the same network
```

### The Critical Detail — Peering Is Two One-Way Connections

This trips up almost everyone the first time: peering isn't ONE
resource, it's TWO — one connection defined FROM VNet A's
perspective, and a separate one defined FROM VNet B's perspective.
Both must exist for traffic to flow in both directions.

```hcl
# Connection 1: "VNet A, you can now reach VNet B"
resource "azurerm_virtual_network_peering" "a_to_b" {
  name                       = "peer-a-to-b"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name        = azurerm_virtual_network.vnet_a.name
  remote_virtual_network_id     = azurerm_virtual_network.vnet_b.id
}

# Connection 2: "VNet B, you can now reach VNet A"
resource "azurerm_virtual_network_peering" "b_to_a" {
  name                       = "peer-b-to-a"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name        = azurerm_virtual_network.vnet_b.name
  remote_virtual_network_id     = azurerm_virtual_network.vnet_a.id
}
```

**If you only create ONE of these**, traffic flows in exactly one
direction — VNet A could reach VNet B, but VNet B couldn't reach
back. This asymmetry is a genuinely common real-world mistake, and
it's the single most important thing to get right in this project.

### What You Are Building

```
VNet A (10.0.0.0/16)              VNet B (10.1.0.0/16)
  subnet-a (10.0.1.0/24)            subnet-b (10.1.1.0/24)
  VM: apx-dev-004-vm-a               VM: apx-dev-004-vm-b
  Runs a tiny web page                Runs a tiny web page
       │                                    │
       └──────── Peering (both directions) ─┘

TEST: from VM-A, curl VM-B's PRIVATE IP → should succeed
      from VM-B, curl VM-A's PRIVATE IP → should succeed
      Both directions work only because BOTH peering
      connections exist
```

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network`, `azurerm_subnet`,
`azurerm_network_security_group`, `azurerm_public_ip`,
`azurerm_network_interface`, `azurerm_linux_virtual_machine` — you
know all of these from NCT-002/MRB-002/MRB-004/APX-010. Build TWO
full VM stacks (one per VNet) from memory; guidance here is only
for the peering resources themselves.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-004-rg` |
| VNet A / Subnet A | `apx-dev-004-vnet-a` (10.0.0.0/16) / `apx-dev-004-subnet-a` (10.0.1.0/24) |
| VNet B / Subnet B | `apx-dev-004-vnet-b` (10.1.0.0/16) / `apx-dev-004-subnet-b` (10.1.1.0/24) |
| VM A / VM B | `apx-dev-004-vm-a`, `apx-dev-004-vm-b` |
| Peering A→B / B→A | `apx-dev-004-peer-a-to-b`, `apx-dev-004-peer-b-to-a` |

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-004-rg"
vm_size                = "Standard_B1s"
admin_username           = "apxadmin"
allowed_ssh_ip             = "YOUR_PUBLIC_IP/32"
owner_name                   = "sam-rivera"
```

> **Both VNets and VMs must be in the SAME Azure region** for
> this project — VNet Peering across regions ("Global Peering")
> works too, but has a small additional cost per GB transferred.
> Keeping both in `East US` avoids that entirely for this lab.

---

## 3. Core Components

### Component 1 — Two Full VNet + VM Stacks (Build From Memory)

Build TWO complete, independent stacks — each with its own VNet,
subnet, NSG (allow SSH from `var.allowed_ssh_ip`, and allow TCP 80
from the OTHER VNet's address space — see note below), public IP,
NIC, and VM. Address spaces must NOT overlap
(`10.0.0.0/16` and `10.1.0.0/16`, as shown in Naming above).

**NSG note — this is the one small addition beyond a normal VM
build:** each VM's NSG needs an inbound rule allowing port 80
from the OTHER VNet's address range, not just from your own IP:

```hcl
# On VM-A's NSG — allow web traffic FROM VNet B
security_rule {
  name                       = "Allow-From-VNet-B"
  priority                    = 110
  direction                     = "Inbound"
  access                          = "Allow"
  protocol                          = "Tcp"
  source_port_range                   = "*"
  destination_port_range                = "80"
  source_address_prefix                    = "10.1.0.0/16"
  destination_address_prefix                  = "*"
}
```
(Mirror this on VM-B's NSG, with `source_address_prefix = "10.0.0.0/16"`)

### Component 2 — The Peering Resources (New — Both Directions)

```hcl
resource "azurerm_virtual_network_peering" "a_to_b" {
  name                       = "apx-dev-004-peer-a-to-b"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name        = azurerm_virtual_network.vnet_a.name
  remote_virtual_network_id     = azurerm_virtual_network.vnet_b.id

  allow_virtual_network_access = true
  allow_forwarded_traffic         = false
  allow_gateway_transit               = false
  use_remote_gateways                     = false
}

resource "azurerm_virtual_network_peering" "b_to_a" {
  name                       = "apx-dev-004-peer-b-to-a"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name        = azurerm_virtual_network.vnet_b.name
  remote_virtual_network_id     = azurerm_virtual_network.vnet_a.id

  allow_virtual_network_access = true
  allow_forwarded_traffic         = false
  allow_gateway_transit               = false
  use_remote_gateways                     = false
}
```

**The four boolean arguments, explained:**

```
allow_virtual_network_access = true
  → the core switch — lets resources in each VNet actually reach
    each other. Must be true on BOTH sides for basic peering to work.

allow_forwarded_traffic = false
  → whether traffic that originated OUTSIDE either VNet (e.g.
    forwarded from a third network) is allowed through. Not needed
    for this simple two-VNet lab — leave false.

allow_gateway_transit = false
  → whether this VNet can share its VPN/ExpressRoute gateway with
    the peered VNet. Neither VNet in this project has a gateway,
    so this is irrelevant here — leave false.

use_remote_gateways = false
  → the flip side of gateway_transit — whether THIS VNet should
    use the OTHER VNet's gateway. Same reasoning — leave false.
```

> For this lab, only `allow_virtual_network_access` actually
> matters. The other three become relevant in larger hub-and-spoke
> network designs — worth knowing they exist, not worth building
> further right now.

### Component 3 — The Testable Web Pages

**Reuse the `custom_data` + `cloud-init` pattern from APX-005**,
one script per VM, each reporting which VNet it belongs to:

**`cloud-init-a.tpl`:**
```bash
#!/bin/bash
apt-get update
apt-get install -y python3
mkdir -p /var/www/html
echo "<h1>Hello from VNet A — $(hostname -I | awk '{print $1}')</h1>" > /var/www/html/index.html
cd /var/www/html && nohup python3 -m http.server 80 &
```

**`cloud-init-b.tpl`** — identical, but says "VNet B" instead.

```hcl
resource "azurerm_linux_virtual_machine" "vm_a" {
  # ... standard config ...
  custom_data = base64encode(templatefile("${path.module}/cloud-init-a.tpl", {}))
}

resource "azurerm_linux_virtual_machine" "vm_b" {
  # ... standard config ...
  custom_data = base64encode(templatefile("${path.module}/cloud-init-b.tpl", {}))
}
```

### Component 4 — Variables + Outputs

Outputs:
```
vm_a_public_ip
vm_a_private_ip
vm_b_public_ip
vm_b_private_ip
resource_group_name
```

---

## 4. Hints

**Hint 1 — Peering status has three states, and both sides must
show "Connected":** check via CLI (shown below). If one side
shows `Connected` and the other shows something else, one of your
two `azurerm_virtual_network_peering` resources likely has an
error, or you accidentally pointed both at the same VNet instead
of at each other.

**Hint 2 — Non-overlapping address spaces are mandatory:** if
VNet A and VNet B share any overlapping IP range, peering will
fail outright at apply time with a clear address-space-conflict
error. This project's `10.0.0.0/16` and `10.1.0.0/16` don't
overlap — if you change these, double check the new ranges don't
either.

**Hint 3 — Peering does NOT automatically punch NSG holes:**
creating the peering connection alone doesn't let traffic through
— you still need the NSG rule (Component 1) explicitly allowing
inbound traffic from the other VNet's address range. Peering
makes the private IPs reachable at the network layer; NSGs still
decide what's actually allowed once traffic arrives.

---

## 5. Workflow (PowerShell) — Including the Real Cross-VNet Test

```powershell
cd C:\Projects\apx-infra-004

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

# Verify peering status on both sides
az network vnet peering show `
  --name apx-dev-004-peer-a-to-b `
  --resource-group apx-dev-004-rg `
  --vnet-name apx-dev-004-vnet-a `
  --query peeringState --output tsv
# Expected: Connected

az network vnet peering show `
  --name apx-dev-004-peer-b-to-a `
  --resource-group apx-dev-004-rg `
  --vnet-name apx-dev-004-vnet-b `
  --query peeringState --output tsv
# Expected: Connected

# Get both public IPs (for SSH) and private IPs (for the actual test)
$vmAPublicIp = terraform output -raw vm_a_public_ip
$vmBPublicIp = terraform output -raw vm_b_public_ip
$vmAPrivateIp = terraform output -raw vm_a_private_ip
$vmBPrivateIp = terraform output -raw vm_b_private_ip

# SSH into VM-A, from THERE curl VM-B's PRIVATE IP
ssh -i ~/.ssh/id_rsa apxadmin@$vmAPublicIp "curl http://$vmBPrivateIp"
# Expected: "Hello from VNet B — 10.1.1.x"

# SSH into VM-B, from THERE curl VM-A's PRIVATE IP
ssh -i ~/.ssh/id_rsa apxadmin@$vmBPublicIp "curl http://$vmAPrivateIp"
# Expected: "Hello from VNet A — 10.0.1.x"
```

**What you should see:** each VM successfully fetching the other
VM's web page using ONLY its private IP — proof that two
completely separate networks are now genuinely connected, with
traffic never touching the public internet.

```powershell
terraform destroy
```

---

## 6. Checklist

```
[ ] VNet A and VNet B use non-overlapping address spaces
[ ] Both azurerm_virtual_network_peering resources present — A→B AND B→A
[ ] allow_virtual_network_access = true on both
[ ] Both VMs' NSGs allow port 80 from the OTHER VNet's address range
[ ] Both peering connections show "Connected" via CLI
[ ] VM-A can curl VM-B's private IP and get a real response
[ ] VM-B can curl VM-A's private IP and get a real response
[ ] terraform destroy completed
```

---

## 7. Cost
Two `Standard_B1s` VMs (~$0.026/hr combined) + two Standard Public
IPs (~$0.01/hr combined). VNet Peering itself within the same
region has no separate charge beyond data transfer (negligible at
lab scale). **A 2-3 hour session: well under $0.15.**

## Series Status
```
APX-003   ✅  Storage + Lifecycle Policy
APX-004   ✅  VNet Peering — two networks, genuinely connected  ← THIS PROJECT
APX-005   ✅  VM Scale Set Basics
```

*Apex Industries — Cloud Platform Engineering | Training Series*
