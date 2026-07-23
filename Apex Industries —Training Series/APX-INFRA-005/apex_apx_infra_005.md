# Apex Industries — Cloud Infrastructure Training Series
## VM Scale Set (VMSS) Basics
**Project Code:** `APX-INFRA-005` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.15/session

---

> **From your Team Lead:** You've built individual VMs several
> times now. This ticket introduces a genuinely different resource
> — one that manages a POOL of identical machines as a single
> unit. This is how most real production compute actually gets
> deployed, not one-VM-at-a-time. — *Morgan Chen*

---

## 1. Overview — The New Concept

### What a VM Scale Set Actually Is

Every VM you've built so far (NCT-002, MRB-002, MRB-004) was ONE
`azurerm_linux_virtual_machine` resource — one machine, one
Terraform resource. A Scale Set is different: ONE resource that
tells Azure "maintain a POOL of N identical machines," and Azure
handles the actual creation, replacement, and management of the
individual instances behind the scenes.

```
Old way (MRB-004):
  2 x azurerm_linux_virtual_machine   → 2 separate resources,
                                          you manage each individually

New way (this project):
  1 x azurerm_linux_virtual_machine_scale_set, instances = 2
                                        → 1 resource, Azure manages
                                          the individual machines
                                          FOR you
```

**Why this matters in the real world:** if one instance in a
Scale Set fails a health check, Azure can automatically replace
it — you never manually manage individual failed machines. This
is the actual foundation of "auto-healing" infrastructure. It's
also how autoscaling works (though this project keeps the count
fixed — autoscaling rules are a natural next step beyond this
lab's scope).

### What You Are Building

```
VM Scale Set (apx-dev-005-vmss)
  instances = 2
  Each instance boots and runs a tiny script that starts a
  one-line web server reporting its own hostname
```

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network` + `azurerm_subnet`,
SSH key auth pattern, `os_disk`/`source_image_reference` blocks —
you've built all of these multiple times across NCT-002, MRB-002,
MRB-004. Build the networking foundation from memory.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-005-rg` |
| VNet / Subnet | `apx-dev-005-vnet` / `apx-dev-005-subnet` |
| VM Scale Set | `apx-dev-005-vmss` |

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-005-rg"
vmss_instance_count  = 2
admin_username       = "apxadmin"
owner_name           = "sam-rivera"
```

---

## 3. Core Components

### Component 1 — Networking (Build From Memory)

RG, VNet (`10.0.0.0/16`), one subnet (`10.0.1.0/24`). No new
guidance — you know this pattern.

### Component 2 — The Scale Set Resource

```hcl
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "${local.name_prefix}-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B1s"
  instances           = var.vmss_instance_count
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching                = "ReadWrite"
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnet.id
    }
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.tpl", {}))

  tags = local.common_tags
}
```

**What's genuinely new here, argument by argument:**

```hcl
sku       = "Standard_B1s"
instances = var.vmss_instance_count
```
On a single VM, you used `size`. On a Scale Set, the argument is
`sku` — same VM size string, different argument name, because
Azure treats the Scale Set's "template" slightly differently from
a single VM. `instances` is entirely new — it's the count of
machines Azure should maintain matching this template.

```hcl
network_interface {
  name    = "vmss-nic"
  primary = true
  ip_configuration { ... }
}
```
Notice this is a NESTED BLOCK inside the Scale Set resource,
not a separate `azurerm_network_interface` resource like every
previous VM project. The Scale Set defines its OWN networking
template inline — Azure clones this template for every instance
it creates. `primary = true` marks this as the main network
interface (a Scale Set instance could theoretically have multiple,
though this project only uses one).

### Component 3 — Boot Script (`cloud-init.tpl`) — Genuinely New

Create this file in your project folder:

```bash
#!/bin/bash
apt-get update
apt-get install -y python3
HOSTNAME=$(hostname)
mkdir -p /var/www/html
echo "<h1>Hello from instance: $HOSTNAME</h1>" > /var/www/html/index.html
cd /var/www/html && nohup python3 -m http.server 80 &
```

**Two new pieces of Terraform machinery working together:**

```hcl
custom_data = base64encode(templatefile("${path.module}/cloud-init.tpl", {}))
```

- `templatefile(path, vars)` — reads a file and substitutes any
  `${variable}` placeholders inside it. This project passes an
  empty `{}` map because the script has nothing to substitute,
  but `templatefile()` is the general tool for injecting real
  values into boot scripts (an API key, a config value, etc.) —
  worth knowing it exists even though this simple version doesn't
  use its full substitution power.
- `base64encode(...)` — Azure's `custom_data` argument REQUIRES
  the script content be base64-encoded before it's sent. This is
  an Azure API requirement, not a Terraform choice — forgetting
  it means Azure receives garbled, unusable script content.

The script itself runs automatically the first time each instance
boots — this is called "cloud-init" and is a standard Linux
mechanism for running setup commands on first boot, which Azure's
`custom_data` argument feeds into.

### Component 4 — Variables + Outputs

```hcl
variable "vmss_instance_count" {
  description = "Number of VM instances in the scale set"
  type        = number
  validation {
    condition     = var.vmss_instance_count >= 1 && var.vmss_instance_count <= 5
    error_message = "vmss_instance_count must be between 1 and 5 for this lab."
  }
}
```

Outputs:
```
vmss_id
vmss_name
resource_group_name
```

---

## 4. Hints

**Hint 1 — Instances have no public IP, and that's intentional:**
you cannot browse directly to any instance yet. Scale Sets are
meant to sit behind a Load Balancer, which is exactly what
APX-006 adds next. This project's "done" state is proving the
instances exist and are individually running your boot script —
verified via CLI, not a browser, for now.

**Hint 2 — `base64encode(templatefile(...))` is a combo you'll
reuse:** any time you need to inject a boot script into a VM or
Scale Set, this exact pattern — read the file, encode it — is the
standard approach. Worth remembering as a reusable recipe, not
just a one-off for this project.

**Hint 3 — Changing `instances` and re-applying is non-destructive
scaling:** if you change `vmss_instance_count` from 2 to 3 and
re-run `terraform apply`, Azure adds ONE new instance — it does
not recreate the existing two. This is a genuinely useful property
of Scale Sets worth testing yourself: change the count, run
`terraform plan`, and notice it shows an update, not a full
replacement.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-005

terraform init
terraform validate
terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

terraform state list

# Verify both instances exist and are running
az vmss list-instances `
  --resource-group apx-dev-005-rg `
  --name apx-dev-005-vmss `
  --output table
# Expected: 2 instances, both "Succeeded" provisioning state

# Try the scaling test from Hint 3
# Edit terraform.tfvars: vmss_instance_count = 3
terraform plan -out=tfplan
# Read the plan — should show an in-place update, not a destroy/recreate
terraform apply tfplan

terraform destroy
```

---

## 6. Checklist

```
[ ] sku (not size) used for the VM size string
[ ] instances = var.vmss_instance_count, not hardcoded
[ ] network_interface block is nested INSIDE the resource, no separate NIC resource
[ ] custom_data uses base64encode(templatefile(...))
[ ] cloud-init.tpl script present in the project folder
[ ] validation{} block on vmss_instance_count (1-5 range)
[ ] terraform state list shows one vmss resource (not multiple VM resources)
[ ] Both instances confirmed running via az vmss list-instances
[ ] terraform destroy completed
```

---

## 7. Cost
`Standard_B1s` × 2 instances ≈ `$0.026/hr` combined. **A short
lab session: well under $0.15.**

## Series Status
```
APX-001 to 004   ✅  Azure AD, Dynamic Groups, Storage, VNet Peering
APX-005          ✅  VM Scale Set Basics                    ← THIS PROJECT
APX-006          📋  Load Balancer + VMSS Together
```

*Apex Industries — Cloud Platform Engineering | Training Series*
