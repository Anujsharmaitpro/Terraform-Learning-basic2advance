# Terraform Mini Project — Azure VNet Peering
## Deep-Dive Learning Guide — Day 15 / 28 Days of Easy Terraform
### Beginner-First Edition | Full Project + Real Debugging Walkthrough | PowerShell Throughout

---

## Before You Start

This is Day 15 — your second mini project. Today's topic is **VNet
Peering** — connecting two separate Virtual Networks so resources inside
them can talk to each other privately, without going through the public
internet.

This guide is unusual in one respect: the instructor made a **real,
instructive mistake** during the demo — both virtual machines accidentally
ended up in the SAME virtual network, which made the peering test
results misleading. This guide walks through that mistake in full,
because debugging a wrong assumption is one of the most valuable skills
in Terraform (and in IT generally).

---

## Table of Contents

1. What Is VNet Peering? (Plain English First)
2. Why Would You Need Two Separate VNets to Talk to Each Other?
3. The Default Behaviour — Same VNet vs Different VNets
4. Planning Your IP Address Ranges — CIDR Recap
5. Building VNet 1 and Subnet 1
6. Building VNet 2 and Subnet 2 — The Critical Mistake to Avoid
7. The Peering Resource — Two-Directional by Design
8. Writing the Peering Connections
9. Adding Virtual Machines to Each Subnet
10. The Instructor's Real Bug — Same VNet, Wrong Test Results
11. How the Bug Was Diagnosed — A Real Debugging Walkthrough
12. The Fix — Correcting the Subnet's Parent VNet
13. Azure Bastion — Secure Access Without Public IPs
14. Testing Peering Connectivity — Ping and Telnet
15. Testing WITHOUT Peering vs WITH Peering
16. The Complete Working Code — All Files (Corrected)
17. Common Mistakes Beginners Make
18. Assignment Tasks
19. Practice Exercises
20. Complete Cheat Sheet

---

## 1. What Is VNet Peering? (Plain English First)

### The neighbourhood analogy

Imagine two separate gated communities (VNets). Each community has its
own streets (subnets) and houses (VMs). By default, residents of
Community A cannot walk into Community B — there's a wall between them.

**VNet Peering is building a private bridge between the two communities.**
Once the bridge exists, residents can walk freely between them — using
private roads, never touching the public highway (the internet).

### The technical definition

**VNet Peering** is an Azure networking feature that connects two Virtual
Networks so that resources in either network can communicate with each
other using PRIVATE IP addresses — as if they were in the same network —
without their traffic ever leaving Azure's private backbone.

### Why this matters for security

```
Without peering, connecting two VNets would require:
  - Public IP addresses on both ends
  - Traffic routes through the public internet
  - VPN tunnels or other complex setups
  - More exposure to attack

With peering:
  - Traffic stays entirely within Azure's private network
  - No public IP needed for the communication
  - Low latency (Azure's backbone, not the public internet)
  - Simple to configure
```

---

## 2. Why Would You Need Two Separate VNets to Talk to Each Other?

### The instructor's scenario

```
SHARED VNET (managed centrally)
- Storage Account  -> shared data resource
- Virtual Machine  -> shared service (e.g., a database, an API)

YOUR TEST VNET (your own team's space)
- Subnet
  - VM1
  - VM2  -> VMs in the SAME VNet can already talk to each other
```

VM1 and VM2 are in the same VNet — they can already communicate by
default (covered in Section 3). But what if your team's VM needs to
reach the shared storage account or shared VM in the OTHER VNet?

By default: **no connectivity**. You need VNet Peering to bridge the two networks.

### Real-world use cases

```
- A central "shared services" VNet (DNS, monitoring, logging) that
  every team's VNet needs to reach

- A "hub" VNet with shared firewalls/gateways that all "spoke" VNets
  route through (this is called Hub-and-Spoke architecture — the
  instructor mentioned this as a more advanced topic for later)

- Connecting a Dev VNet to a Shared Database VNet without exposing
  the database to the public internet

- Multi-team organizations where each team owns their own VNet but
  needs occasional access to another team's resources
```

---

## 3. The Default Behaviour — Same VNet vs Different VNets

This is the single most important concept in this entire video.

```
SAME VNet, SAME or DIFFERENT subnet:
  VM1 and VM2 can talk to each other AUTOMATICALLY
  No peering needed. No extra configuration needed.
  This is Azure's default behaviour.

DIFFERENT VNets (even in the same region, same subscription):
  VM1 (in VNet A) and VM2 (in VNet B) CANNOT talk to each other
  Connection attempts will time out or be refused
  You MUST explicitly create VNet Peering to enable communication
```

### Why this distinction matters for THIS video

The instructor's entire demo was meant to prove: "VMs in different VNets
cannot talk UNLESS you peer them." But due to a configuration mistake
(covered in Section 10), both VMs accidentally ended up in the SAME VNet
— meaning the connectivity test showed "it works!" even AFTER the peering
was deleted. This confused the demo until the root cause was found.

**The lesson:** Always verify which VNet a resource actually belongs to
before drawing conclusions from a connectivity test. Don't assume your
`.tf` file did what you think it did — verify in the Azure Portal.

---

## 4. Planning Your IP Address Ranges — CIDR Recap

### Quick CIDR refresher (full detail was in Day 14)

```
/16 = 65,536 addresses   (used for the VNet itself — lots of room)
/24 = 256 addresses      (used for subnets — a smaller slice)
```

### The instructor's IP planning for this project

```
VNet 1 (Pier1 VNet):
  Address space: 10.0.0.0/16   -> covers 10.0.0.0 to 10.0.255.255

  Subnet 1 (Pier1 Subnet):
    Address prefix: 10.0.0.0/24   -> covers 10.0.0.0 to 10.0.0.255

VNet 2 (Pier2 VNet):
  Address space: 10.1.0.0/16   -> covers 10.1.0.0 to 10.1.255.255

  Subnet 2 (Pier2 Subnet):
    Address prefix: 10.1.0.0/24   -> covers 10.1.0.0 to 10.1.0.255
```

### Why the VNets must NOT overlap

VNet Peering REQUIRES that the two VNets have non-overlapping address
spaces. If both VNets used `10.0.0.0/16`, Azure would refuse to create
the peering because it couldn't tell which network an IP address belongs to.

```
VALID for peering:
   VNet 1: 10.0.0.0/16
   VNet 2: 10.1.0.0/16
   (different ranges — no overlap)

INVALID for peering:
   VNet 1: 10.0.0.0/16
   VNet 2: 10.0.0.0/16
   (identical ranges — Azure rejects this)
```

---

## 5. Building VNet 1 and Subnet 1

**`network.tf`**
```hcl
# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "day15-rg"
  location = "Canada Central"
}

# VNet 1
resource "azurerm_virtual_network" "vnet1" {
  name                = "pier1-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  address_space        = ["10.0.0.0/16"]
}

# Subnet 1 (inside VNet 1)
resource "azurerm_subnet" "subnet1" {
  name                 = "pier1-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  # MUST reference vnet1 — this is the critical link
  address_prefixes     = ["10.0.0.0/24"]
}
```

### Anatomy of the subnet block — the critical field

```hcl
resource "azurerm_subnet" "subnet1" {
  virtual_network_name = azurerm_virtual_network.vnet1.name
  # This field determines WHICH VNet the subnet
  # belongs to. Get this wrong, and the subnet
  # ends up in the wrong network entirely.
}
```

This single line is exactly where the instructor's bug originated later
in the video (Section 10).

---

## 6. Building VNet 2 and Subnet 2 — The Critical Mistake to Avoid

**Continuing `network.tf`**
```hcl
# VNet 2
resource "azurerm_virtual_network" "vnet2" {
  name                = "pier2-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  address_space        = ["10.1.0.0/16"]
  # Different range from VNet 1 (10.0.0.0/16) — required for peering
}

# Subnet 2 (inside VNet 2)
resource "azurerm_subnet" "subnet2" {
  name                 = "pier2-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  # MUST reference vnet2, NOT vnet1!
  address_prefixes     = ["10.1.0.0/24"]
}
```

### THE EXACT MISTAKE TO AVOID

The instructor initially copy-pasted Subnet 1's code to create Subnet 2,
then forgot to update ONE field:

```hcl
# THE BUG — copy-paste error, virtual_network_name not updated
resource "azurerm_subnet" "subnet2" {
  name                 = "pier2-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name   # STILL vnet1!
  address_prefixes     = ["10.1.0.0/24"]
}

# THE FIX — correctly references vnet2
resource "azurerm_subnet" "subnet2" {
  name                 = "pier2-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name   # correctly vnet2
  address_prefixes     = ["10.1.0.0/24"]
}
```

**Why this is dangerous:** Terraform did NOT throw an error for this
mistake. The address prefix `10.1.0.0/24` was technically valid as a
sub-range — Azure just placed "subnet2" inside "vnet1" instead of "vnet2"
without complaint. The mistake only became visible during connectivity
testing, much later in the process.

**The lesson:** When copy-pasting resource blocks, ALWAYS re-check every
single reference field — especially ones pointing to parent resources
like `virtual_network_name`, `resource_group_name`, etc. A find-and-replace
or careful manual review catches this before it costs you debugging time.

---

## 7. The Peering Resource — Two-Directional by Design

### Why peering needs TWO resource blocks

This is conceptually different from most Azure resources. VNet Peering
is NOT one resource — it's two SEPARATE resources, each living in a
different VNet, pointing at each other.

```
Peering Connection A -> B:
  Lives in VNet A
  Says: "I am peered with VNet B"

Peering Connection B -> A:
  Lives in VNet B
  Says: "I am peered with VNet A"

BOTH must exist for the peering to actually work.
If only A->B exists, the connection is incomplete/one-sided.
```

### The resource type

```hcl
resource "azurerm_virtual_network_peering" "peering_name" {
  name                      = "descriptive-name"
  resource_group_name       = "..."
  virtual_network_name      = "..."   # the LOCAL vnet (where this peering lives)
  remote_virtual_network_id = "..."   # the REMOTE vnet (what it connects to)
}
```

---

## 8. Writing the Peering Connections

**`network.tf` (continued)**
```hcl
# Peering: VNet 1 -> VNet 2
resource "azurerm_virtual_network_peering" "peer_1_to_2" {
  name                      = "pier1-to-pier2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  # This peering connection LIVES IN VNet 1

  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  # It points TO VNet 2 (note: .id, not .name, for the remote target)
}

# Peering: VNet 2 -> VNet 1
resource "azurerm_virtual_network_peering" "peer_2_to_1" {
  name                      = "pier2-to-pier1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  # This peering connection LIVES IN VNet 2

  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  # It points TO VNet 1
}
```

### Why `.id` for the remote network but `.name` for the local network?

```hcl
virtual_network_name      = azurerm_virtual_network.vnet1.name   # local — by NAME
remote_virtual_network_id = azurerm_virtual_network.vnet2.id     # remote — by ID
```

This is simply how Azure's API for peering is designed:
- The LOCAL VNet (where the peering resource is created) is identified by name
- The REMOTE VNet (the target of the peering) is identified by its full
  Azure resource ID (a globally unique path)

This is a documentation detail you check when writing the resource —
don't try to memorise the "why," just remember the pattern.

### Verifying with `terraform plan`

```powershell
terraform plan
```

```
Terraform will perform the following actions:

  # azurerm_resource_group.rg will be created
  # azurerm_virtual_network.vnet1 will be created
  # azurerm_virtual_network.vnet2 will be created
  # azurerm_subnet.subnet1 will be created
  # azurerm_subnet.subnet2 will be created
  # azurerm_virtual_network_peering.peer_1_to_2 will be created
  # azurerm_virtual_network_peering.peer_2_to_1 will be created

Plan: 7 to add, 0 to change, 0 to destroy.
```

Seven resources total — exactly as the instructor confirmed.

---

## 9. Adding Virtual Machines to Each Subnet

**`vm.tf`**
```hcl
# Network Interface for VM 1
resource "azurerm_network_interface" "nic1" {
  name                = "pier1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machine 1 (in VNet 1 / Subnet 1)
resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "pier1-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "testadmin"
  admin_password      = "P@ssword1234!"

  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic1.id]

  os_disk {
    name                 = "osdisk1"   # MUST be unique across both VMs!
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Network Interface for VM 2
resource "azurerm_network_interface" "nic2" {
  name                = "pier2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machine 2 (in VNet 2 / Subnet 2)
resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "pier2-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "testadmin"
  admin_password      = "P@ssword1234!"

  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic2.id]

  os_disk {
    name                 = "osdisk2"   # different name from VM1's disk!
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
```

### The instructor's OS disk naming error

When the instructor first applied this configuration, both VMs had
`name = "myosdisk"` for their OS disk:

```
Error: A disk with the name "myosdisk" already exists in the Resource Group.
```

**Why this happened:** OS disk names must be unique within a Resource
Group. Since both VMs were in the same RG, identical disk names collided.

**The fix:** Give each disk a unique name (`osdisk1`, `osdisk2`).

**A second error appeared:** changing the disk name on an EXISTING VM
("OS disk name change not allowed") because the first VM had already
been created with the conflicting name. The fix required destroying and
recreating the resources cleanly.

---

## 10. The Instructor's Real Bug — Same VNet, Wrong Test Results

This is the central debugging lesson of this video. Walking through it
in full teaches you HOW to debug Terraform networking issues.

### What happened

Due to the copy-paste mistake in Section 6, `subnet2`'s `virtual_network_name`
still pointed to `vnet1` instead of `vnet2`. This meant:

```
INTENDED setup:
  vnet1 (10.0.0.0/16)
    -> subnet1 (10.0.0.0/24) -> vm1

  vnet2 (10.1.0.0/16)
    -> subnet2 (10.1.0.0/24) -> vm2

ACTUAL setup (due to the bug):
  vnet1 (10.0.0.0/16)
    -> subnet1 (10.0.0.0/24) -> vm1
    -> subnet2 (10.1.0.0/24) -> vm2   <- WRONG — should be in vnet2!

  vnet2 (10.1.0.0/16)
    (empty — nothing was actually placed here)
```

Both VMs ended up in `vnet1`, just in different subnets. Since same-VNet
communication works by default (Section 3), the ping and telnet tests
"succeeded" — but NOT because peering was working. They succeeded because
the VMs were never actually in separate networks to begin with.

### Why this fooled the test

```
Test performed: ping from vm1 to vm2 -> SUCCESS
Instructor's assumption: "Peering must be working!"
Reality: VMs are in the SAME VNet — peering was never the reason it worked

Test performed AFTER deleting BOTH peering connections: ping still works
This is the moment that revealed something was wrong —
because deleting peering should have broken connectivity,
but it didn't change anything.
```

---

## 11. How the Bug Was Diagnosed — A Real Debugging Walkthrough

### Step-by-step diagnostic process the instructor used

**Step 1 — Notice the unexpected result**
```
Expected: after deleting peering, ping should FAIL
Actual:   ping still SUCCEEDS
-> Something doesn't match the mental model
```

**Step 2 — Check the Network Security Group (NSG)**
```
Hypothesis: maybe an NSG rule is allowing traffic regardless of peering
Investigation: checked NIC-level and subnet-level NSGs
Result: NO NSG was attached to either NIC or subnet
-> Ruled out: it's not an NSG misconfiguration
```

**Step 3 — Check for other connectivity features**
```
Hypothesis: maybe a VNet Manager, Service Endpoint, or Private Endpoint
            is providing an alternate path
Investigation: checked virtual network manager settings, service endpoints
Result: None configured
-> Ruled out: no other Azure feature is bridging the networks
```

**Step 4 — Check which VNet each resource ACTUALLY belongs to**
```
Investigation: opened vm2's networking page in Azure Portal
Discovery: vm2 shows "Virtual Network: pier1-vnet"
           NOT "pier2-vnet" as intended!
-> ROOT CAUSE FOUND: subnet2 was actually inside vnet1
```

### The diagnostic principle

When a result contradicts your model of how the system should behave,
work backward through every assumption — starting with the most basic
one ("which network is this resource actually in?") rather than jumping
to complex explanations. The instructor initially suspected NSGs and
other advanced features before realising the basic subnet assignment
was wrong.

**PowerShell — verify which VNet a subnet belongs to:**
```powershell
# Check subnet's parent VNet
az network vnet subnet show `
  --resource-group "day15-rg" `
  --vnet-name "pier1-vnet" `
  --name "pier2-subnet" `
  --query "name" -o tsv

# If this command SUCCEEDS, subnet2 is actually inside vnet1 (the bug)
# If it FAILS with "not found", subnet2 is correctly NOT in vnet1

# Correct check — verify subnet2 is in vnet2
az network vnet subnet show `
  --resource-group "day15-rg" `
  --vnet-name "pier2-vnet" `
  --name "pier2-subnet" `
  --query "name" -o tsv
```

---

## 12. The Fix — Correcting the Subnet's Parent VNet

```hcl
# BEFORE (the bug):
resource "azurerm_subnet" "subnet2" {
  name                 = "pier2-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name   # WRONG
  address_prefixes     = ["10.1.0.0/24"]
}

# AFTER (the fix):
resource "azurerm_subnet" "subnet2" {
  name                 = "pier2-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name   # CORRECT
  address_prefixes     = ["10.1.0.0/24"]
}
```

### Why this requires a DESTROY and RECREATE

Changing `virtual_network_name` on an existing subnet is NOT an in-place
update — Azure doesn't support "moving" a subnet between VNets. Terraform
detects this and marks the change as **forces replacement**:

```
  # azurerm_subnet.subnet2 must be replaced
  -/+ resource "azurerm_subnet" "subnet2" {
      ~ virtual_network_name = "pier1-vnet" -> "pier2-vnet"  # forces replacement
    }
```

But subnet2 has a VM attached to it (via the network interface) — Azure
won't let you delete a subnet that has active resources inside it.

**The instructor's resolution:** Run a full `terraform destroy`, fix the
code, then `terraform apply` again from a clean state. This is sometimes
the pragmatic choice for foundational networking mistakes rather than
trying to force in-place migrations.

```powershell
# Full clean restart after fixing the bug
terraform destroy --auto-approve
# Fix the virtual_network_name in network.tf
terraform apply --auto-approve
```

### A more advanced option — `create_before_destroy`

For production scenarios where downtime matters, you could attempt:
```hcl
resource "azurerm_subnet" "subnet2" {
  # ...
  lifecycle {
    create_before_destroy = true
  }
}
```
But for fundamental structural mistakes like a wrong parent VNet, a clean
destroy-and-rebuild is often simpler and safer than fighting Terraform's
replacement mechanics.

---

## 13. Azure Bastion — Secure Access Without Public IPs

### Why the instructor couldn't just SSH directly

Neither VM has a public IP address (by design — they're private VMs).
Without a public IP, you cannot directly SSH from your laptop to the VM
over the internet.

### What is Azure Bastion?

**Azure Bastion** is a managed jump-box service. You connect to Bastion
through the Azure Portal (using your browser), and Bastion relays your
SSH/RDP session to the target VM over Azure's private network.

```
Your Laptop -> Azure Portal (HTTPS) -> Azure Bastion -> Private VM (SSH)
                                       (no public IP needed on the VM)
```

### Why Bastion is better than a manual jump box

```
OLD APPROACH (manual jump VM):
  Create a VM with a public IP just to act as a relay
  SSH into that jump VM, then SSH again into the target VM
  RISK: if the jump VM is compromised, attacker reaches everything

Azure Bastion (managed service):
  No VM to manage, patch, or secure yourself
  Connects via the Azure Portal — uses your Azure login (MFA-protected)
  No public IP needed on ANY of your VMs
  Microsoft manages and secures the Bastion infrastructure
```

### Deploying Bastion via Terraform (the instructor's assignment for you)

The instructor deployed Bastion manually through the Portal during the
demo and explicitly assigned writing this in Terraform as an assignment.
Here's the implementation:

```hcl
# bastion.tf

# Bastion requires its own dedicated subnet, named EXACTLY "AzureBastionSubnet"
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"   # name is mandatory, exact match required
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.1.0/26"]   # minimum /26 required by Azure
}

# Bastion needs its own public IP
resource "azurerm_public_ip" "bastion_pip" {
  name                = "bastion-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# The Bastion Host itself
resource "azurerm_bastion_host" "bastion" {
  name                = "day15-bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}
```

**PowerShell — connect via Bastion using Azure CLI (alternative to Portal):**
```powershell
az network bastion ssh `
  --name "day15-bastion" `
  --resource-group "day15-rg" `
  --target-resource-id (az vm show --name "pier1-vm" --resource-group "day15-rg" --query "id" -o tsv) `
  --auth-type "password" `
  --username "testadmin"
```

---

## 14. Testing Peering Connectivity — Ping and Telnet

### Inside the VM, using the Bastion session

```bash
# Test 1: Ping the remote VM's private IP
ping 10.1.0.4

# Expected with peering: replies received
# Expected without peering: "Request timed out" or no response

# Test 2: Telnet to check a specific port (e.g., SSH port 22)
telnet 10.1.0.4 22

# Expected with peering + port open: "Connected to 10.1.0.4"
# Expected without peering: "Connection timed out" or refused

# Test 3: Telnet to a CLOSED port (to verify it's not just "anything works")
telnet 10.1.0.4 80

# Expected: "Connection refused" (port not listening) —
# this is DIFFERENT from a network-level block (which times out silently)
```

### Reading the difference between "refused" and "timed out"

```
Connection REFUSED -> network path exists, but nothing is listening
                      on that specific port (this is actually GOOD —
                      it proves the network connectivity works)

Connection TIMED OUT -> no network path exists at all
                        (this means peering — or routing — isn't working)
```

This distinction is exactly how the instructor confirmed Port 22 was
reachable (SSH service listening) while Port 80 was refused (no web
server running) — both results actually PROVED network connectivity,
just showed different service availability.

---

## 15. Testing WITHOUT Peering vs WITH Peering

This is the assignment the instructor explicitly gave: test BOTH states
and compare.

### The testing protocol

```powershell
# PHASE 1: Test WITHOUT peering
# Comment out both peering resources in network.tf
# resource "azurerm_virtual_network_peering" "peer_1_to_2" { ... }
# resource "azurerm_virtual_network_peering" "peer_2_to_1" { ... }

terraform apply --auto-approve
# Connect via Bastion to vm1
# Try: ping 10.1.0.4
# EXPECTED RESULT: "Request timed out" — no connectivity

# PHASE 2: Test WITH peering
# Uncomment the peering resources
terraform apply --auto-approve
# Connect via Bastion to vm1
# Try: ping 10.1.0.4
# EXPECTED RESULT: replies received — connectivity works
```

### Why this comparison matters

Only by testing BOTH states can you be confident peering is the actual
cause of connectivity, rather than some other factor (like the instructor's
accidental same-VNet bug). This is the scientific control — change ONE
variable (peering on/off) and observe the difference.

---

## 16. The Complete Working Code — All Files (Corrected)

**`provider.tf`**
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

---

**`variables.tf`**
```hcl
variable "location" {
  type    = string
  default = "Canada Central"
}

variable "prefix" {
  type    = string
  default = "day15"
}
```

---

**`network.tf`** (corrected version)
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# VNet 1 and Subnet 1
resource "azurerm_virtual_network" "vnet1" {
  name                = "pier1-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "pier1-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name   # vnet1 — correct
  address_prefixes     = ["10.0.0.0/24"]
}

# VNet 2 and Subnet 2
resource "azurerm_virtual_network" "vnet2" {
  name                = "pier2-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "pier2-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name   # vnet2 — CORRECTED
  address_prefixes     = ["10.1.0.0/24"]
}

# VNet Peering (bidirectional)
resource "azurerm_virtual_network_peering" "peer_1_to_2" {
  name                      = "pier1-to-pier2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
}

resource "azurerm_virtual_network_peering" "peer_2_to_1" {
  name                      = "pier2-to-pier1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
}
```

---

**`vm.tf`**
```hcl
# VM 1 (in VNet 1 / Subnet 1)
resource "azurerm_network_interface" "nic1" {
  name                = "pier1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "pier1-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "testadmin"
  admin_password      = "P@ssword1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic1.id]

  os_disk {
    name                 = "osdisk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# VM 2 (in VNet 2 / Subnet 2)
resource "azurerm_network_interface" "nic2" {
  name                = "pier2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "pier2-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "testadmin"
  admin_password      = "P@ssword1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic2.id]

  os_disk {
    name                 = "osdisk2"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
```

---

**`outputs.tf`**
```hcl
output "vm1_private_ip" {
  value = azurerm_network_interface.nic1.private_ip_address
}

output "vm2_private_ip" {
  value = azurerm_network_interface.nic2.private_ip_address
}

output "vnet1_name" {
  value = azurerm_virtual_network.vnet1.name
}

output "vnet2_name" {
  value = azurerm_virtual_network.vnet2.name
}
```

---

**PowerShell — full workflow:**

```powershell
Set-Location "C:\projects\day15"

$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraform init
terraform validate
terraform plan
# Expect: Plan: 7 to add (rg, vnet1, vnet2, subnet1, subnet2, 2 peerings)

terraform apply --auto-approve

# Verify VM IPs and VNet assignments
terraform output

# Verify subnet's actual parent VNet (catches the bug from Section 10/11)
az network vnet subnet show `
  --resource-group "day15-rg" `
  --vnet-name "pier2-vnet" `
  --name "pier2-subnet" `
  --query "name" -o tsv
# Should succeed — confirms subnet2 is correctly inside vnet2

# Clean up
terraform destroy --auto-approve

Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 17. Common Mistakes Beginners Make

### Mistake 1 — Copy-paste without updating ALL references

```hcl
# The exact bug from this video
resource "azurerm_subnet" "subnet2" {
  virtual_network_name = azurerm_virtual_network.vnet1.name   # forgot to update
}
```

**Fix:** After copy-pasting a resource block, search for EVERY occurrence
of the old resource's local name and verify each one was intentionally
updated.

---

### Mistake 2 — Overlapping VNet address spaces

```hcl
# Both VNets use the same range — peering will fail
resource "azurerm_virtual_network" "vnet1" {
  address_space = ["10.0.0.0/16"]
}
resource "azurerm_virtual_network" "vnet2" {
  address_space = ["10.0.0.0/16"]   # same range!
}
```

```
Error: The VNets being peered have overlapping address spaces.
```

**Fix:** Always plan distinct, non-overlapping ranges before writing code.

---

### Mistake 3 — Duplicate OS disk names across VMs

```hcl
# Both VMs use the same disk name in the same Resource Group
os_disk { name = "myosdisk" }   # VM 1
os_disk { name = "myosdisk" }   # VM 2 — collision!
```

**Fix:** Use unique names, ideally derived from the VM name:
```hcl
os_disk { name = "${var.vm_name}-osdisk" }
```

---

### Mistake 4 — Assuming peering exists if traffic flows

The central lesson of this video. If connectivity tests succeed, ALWAYS
verify in the Azure Portal which VNet each resource actually belongs to
before concluding "peering worked." Same-VNet default connectivity can
mimic peering's effect in test results.

---

### Mistake 5 — Trying to SSH directly without a public IP or Bastion

```powershell
# This will hang/fail — VM has no public IP
ssh testadmin@10.0.0.4
```

**Fix:** Use Azure Bastion (or a VPN, or a jump box) to reach private VMs.

---

### Mistake 6 — Forgetting peering is bidirectional

```hcl
# Only one direction created — connectivity won't fully work
resource "azurerm_virtual_network_peering" "peer_1_to_2" { ... }
# Missing the reverse peering!

# Both directions required
resource "azurerm_virtual_network_peering" "peer_1_to_2" { ... }
resource "azurerm_virtual_network_peering" "peer_2_to_1" { ... }
```

---

## 18. Assignment Tasks

The instructor explicitly assigned these as homework:

### Task 1 — Use Variables Throughout

Replace hardcoded values (VM names, subnet names, address prefixes) with
variables so the configuration is reusable.

### Task 2 — Store SSH Keys in Azure Key Vault

Instead of password authentication, generate an SSH key pair, store the
public key in an Azure Key Vault, and reference it via a data source.

### Task 3 — Deploy Azure Bastion via Terraform

Implement the Bastion host configuration shown in Section 13 instead of
creating it manually through the Portal.

### Task 4 — Use `count` or `for_each` to Avoid Duplication

```hcl
variable "vnets" {
  type = map(object({
    address_space = string
    subnet_prefix = string
  }))
  default = {
    pier1 = { address_space = "10.0.0.0/16", subnet_prefix = "10.0.0.0/24" }
    pier2 = { address_space = "10.1.0.0/16", subnet_prefix = "10.1.0.0/24" }
  }
}

resource "azurerm_virtual_network" "vnets" {
  for_each            = var.vnets
  name                = "${each.key}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [each.value.address_space]
}
```

### Task 5 — Test Both States

Test connectivity WITHOUT peering, then WITH peering, and document the
difference (as shown in Section 15).

---

## 19. Practice Exercises

### Exercise 1 — Spot the Bug

```hcl
resource "azurerm_virtual_network" "vnet_a" {
  name           = "vnet-a"
  address_space  = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "vnet_b" {
  name           = "vnet-b"
  address_space  = ["10.0.0.0/16"]
}
```

**Answer:** Both VNets use the identical address space `10.0.0.0/16`.
Peering between them would fail with an overlapping address space error.
Fix: change `vnet_b` to a non-overlapping range like `10.1.0.0/16`.

---

### Exercise 2 — Write the Peering Pair

Given `vnet_dev` and `vnet_shared`, write both directions of peering.

**Answer:**
```hcl
resource "azurerm_virtual_network_peering" "dev_to_shared" {
  name                      = "dev-to-shared"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet_dev.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_shared.id
}

resource "azurerm_virtual_network_peering" "shared_to_dev" {
  name                      = "shared-to-dev"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet_shared.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_dev.id
}
```

---

### Exercise 3 — Diagnose This Scenario

A VM in VNet A can ping a VM in VNet B even though you never created
any peering resources. List three possible explanations and how to
verify each.

**Answer:**
```
1. Both VMs are actually in the SAME VNet (subnet misconfiguration)
   -> Verify: az network vnet subnet show, check which VNet each subnet
     actually belongs to

2. A VPN Gateway or ExpressRoute connects the two networks
   -> Verify: check for azurerm_virtual_network_gateway resources

3. Both VMs have public IPs and are reaching each other over the
   public internet (not via Azure's private network at all)
   -> Verify: check if either VM has a public IP attached; check the
     route taken (traceroute)
```

---

## 20. Complete Cheat Sheet

```
================================================================================
          TERRAFORM VNET PEERING — DAY 15 QUICK REFERENCE
================================================================================
  THE GOLDEN RULE
  Same VNet  -> VMs talk by default, NO peering needed
  Diff VNets -> VMs CANNOT talk by default, peering REQUIRED
--------------------------------------------------------------------------------
  PEERING IS BIDIRECTIONAL — TWO RESOURCES REQUIRED

  resource "azurerm_virtual_network_peering" "a_to_b" {
    name                      = "a-to-b"
    resource_group_name       = azurerm_resource_group.rg.name
    virtual_network_name      = azurerm_virtual_network.vnet_a.name  <- LOCAL
    remote_virtual_network_id = azurerm_virtual_network.vnet_b.id    <- REMOTE
  }
  + the REVERSE (b_to_a) is also required
--------------------------------------------------------------------------------
  ADDRESS SPACE PLANNING
  VNets being peered MUST have non-overlapping CIDR ranges
  VNet1: 10.0.0.0/16    VNet2: 10.1.0.0/16   valid
  VNet1: 10.0.0.0/16    VNet2: 10.0.0.0/16   overlap — fails
--------------------------------------------------------------------------------
  THE #1 BUG TO WATCH FOR
  When copy-pasting a subnet block, ALWAYS verify:
    virtual_network_name = azurerm_virtual_network.CORRECT_VNET.name
  Terraform will NOT error if you point to the wrong VNet —
  it just silently creates the subnet in the wrong place.
--------------------------------------------------------------------------------
  DEBUGGING UNEXPECTED CONNECTIVITY
  1. Check NSG rules (subnet + NIC level)
  2. Check for VPN Gateway / Service Endpoints / Private Endpoints
  3. VERIFY which VNet each resource actually belongs to (Azure Portal)
     az network vnet subnet show --vnet-name X --name Y
  4. Don't assume — confirm
--------------------------------------------------------------------------------
  AZURE BASTION (secure access without public IPs)
  Requires: dedicated subnet named EXACTLY "AzureBastionSubnet" (min /26)
  Requires: its own public IP (Standard SKU)
  Connect via Azure Portal browser session — no SSH client needed on host
--------------------------------------------------------------------------------
  CONNECTIVITY TEST COMMANDS (inside the VM via Bastion)
  ping <remote-private-ip>          -> tests basic network reachability
  telnet <remote-private-ip> <port> -> tests specific port connectivity

  Connection REFUSED -> network works, nothing listening on that port (OK)
  Connection TIMED OUT -> no network path exists (peering/routing problem)
--------------------------------------------------------------------------------
  TESTING PROTOCOL
  1. Test connectivity WITHOUT peering -> should FAIL (timeout)
  2. Add peering, apply
  3. Test connectivity WITH peering -> should SUCCEED
  4. Compare the two results to confirm peering caused the difference
--------------------------------------------------------------------------------
  POWERSHELL VERIFICATION
  az network vnet subnet show --vnet-name X --name Y --resource-group Z
    -> confirms which VNet a subnet actually belongs to
  terraform output
    -> confirms private IPs assigned to each VM
================================================================================
```

---

## The Core Mental Model for This Video

```
SAME VNET = One house with two rooms
  Residents in either room can walk freely between them. No extra setup.

DIFFERENT VNETS = Two separate houses
  By default, no path between them — like two houses with no door connecting them.

VNET PEERING = Building a private hallway between the two houses
  Requires construction work on BOTH sides (two peering resources)
  Once built, residents of either house can walk through privately
  Never touching the public street (the internet) to visit each other

THE DEBUGGING LESSON:
  If you think you built a hallway between House A and House B,
  but you actually built two rooms inside House A —
  walking between them will "work" — but NOT because of the hallway.
  Always verify which house (VNet) each room (subnet) is actually in
  before trusting your test results.
```

---

*Guide covers: Azure VNet Peering, azurerm_virtual_network_peering,
bidirectional peering requirement, same-VNet default connectivity,
cross-VNet connectivity requirements, CIDR address space planning for
peering, non-overlapping address space requirement, subnet virtual_network_name
field, copy-paste configuration errors, OS disk naming uniqueness, Azure
Bastion, AzureBastionSubnet naming requirement, secure VM access without
public IPs, debugging unexpected network connectivity, NSG verification,
ping and telnet connectivity testing, connection refused vs timed out,
testing protocol for before/after peering comparison, real-world debugging
methodology, PowerShell az network vnet subnet show verification commands,
hub-and-spoke architecture mention, ARM credential management.*
