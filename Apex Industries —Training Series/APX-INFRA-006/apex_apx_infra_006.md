# Apex Industries — Cloud Infrastructure Training Series
## Load Balancer + VMSS Together
**Project Code:** `APX-INFRA-006` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.50/session

---

> **From your Team Lead:** A Scale Set with no way in isn't very
> useful on its own. This ticket adds the Load Balancer — same
> resource type from MRB-004, but this time pooling a Scale Set
> instead of individual VMs. You'll notice the wiring is actually
> simpler this way. — *Morgan Chen*

---

## 1. Overview — Reusing MRB-004, New Connection Mechanism

You already built a Standard Load Balancer in MRB-004, pooling
two individually-managed VMs. This project reuses that exact
Load Balancer resource shape — but connects it to the VMSS from
APX-005 instead, which changes HOW the connection is made, even
though the Load Balancer resource itself is identical.

```
MRB-004 pattern:
  VM's NIC → separate azurerm_network_interface_backend_address_pool_association
             resource → Backend Pool

This project's pattern:
  VMSS's network_interface block → load_balancer_backend_address_pool_ids
             argument, set DIRECTLY inside the VMSS resource
             → Backend Pool
```

**Why the difference?** A Scale Set manages its own network
interface template internally — there's no separate NIC resource
to attach an association to, because there's no separate NIC
resource at all (as you saw in APX-005, the NIC is a nested block
inside the VMSS itself). So the pool connection happens INSIDE
that nested block instead of as its own resource.

### What You Are Building

```
Load Balancer (apx-dev-006-lb), Standard SKU
  Public IP → Frontend
  Backend Pool → connected to VMSS instances directly
  Health Probe: TCP 80
  Rule: forward port 80 → backend pool
```

### Reused Without Guidance
Everything from APX-005 (RG, VNet, Subnet, the VMSS resource
itself with its boot script) — build this exactly as before, one
change: add the pool connection inside the `network_interface`
block (shown in Component 2 below).

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-006-rg` |
| Load Balancer | `apx-dev-006-lb` |
| LB Public IP | `apx-dev-006-lb-pip` |
| Backend Pool | `apx-dev-006-pool` |
| VM Scale Set | `apx-dev-006-vmss` |

```hcl
# terraform.tfvars — same shape as APX-005
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-006-rg"
vmss_instance_count  = 2
admin_username       = "apxadmin"
owner_name           = "sam-rivera"
```

---

## 3. Core Components

### Component 1 — Load Balancer (Same Pattern as MRB-004, Build From Memory)

Public IP (`Standard` SKU), `azurerm_lb` (`Standard` SKU),
`azurerm_lb_backend_address_pool`, `azurerm_lb_probe` (TCP, port
80), `azurerm_lb_rule` (port 80 → 80, references the probe and
pool). You built every one of these in MRB-004 — no new guidance.

**One small reuse of `for_each`, for the probe, matching the
pattern from MRB-004/NCT-007:**

```hcl
resource "azurerm_lb_probe" "probes" {
  for_each        = { "http" = 80 }
  loadbalancer_id = azurerm_lb.lb.id
  name            = "${each.key}-probe"
  protocol        = "Tcp"
  port            = each.value
}
```

> This is a slightly unusual use of `for_each` — a map with just
> one entry. It's not strictly necessary here (a single static
> probe would work fine), but it's included deliberately to keep
> the `for_each` mechanic in active rotation, per the standing
> rule about not letting mechanics go stale between projects. If
> you later needed a second probe (e.g. HTTPS on port 443), you'd
> just add a second map entry — no new resource block required.

### Component 2 — VMSS, Connected to the Pool (The New Piece)

Build the VMSS exactly as in APX-005, with ONE change to the
`network_interface` block:

```hcl
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  # ... name, sku, instances, admin_username, admin_ssh_key,
  #     source_image_reference, os_disk — identical to APX-005 ...

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name                                    = "internal"
      primary                                  = true
      subnet_id                                 = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids    = [azurerm_lb_backend_address_pool.pool.id]
    }
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.tpl", {}))
  tags         = local.common_tags
}
```

**The single new argument:** `load_balancer_backend_address_pool_ids`
— a list (because a NIC could theoretically belong to multiple
pools, though this project only uses one). This is what actually
puts every VMSS instance into the Load Balancer's backend pool,
automatically, for every instance Azure creates — including any
future instances if you scaled up later. This is a meaningful
advantage over MRB-004's approach: with individual VMs, EVERY new
VM needs its own separate association resource; with VMSS, the
pool membership is baked into the template once, and every
instance inherits it automatically.

### Component 3 — Variables + Outputs

Outputs:
```
lb_public_ip
vmss_id
resource_group_name
```

---

## 4. Hints

**Hint 1 — Same trap as MRB-004: a clean apply doesn't prove
traffic actually flows:** verify actual pool membership via CLI
before trusting it works, same discipline as before.

**Hint 2 — Boot script timing:** it takes 1-2 minutes after
`terraform apply` completes for cloud-init to finish running on
each instance and start the tiny web server. If your first test
request fails or times out, wait a minute and try again before
assuming something is broken.

**Hint 3 — SKU mismatch, same rule as MRB-004:** Public IP and
Load Balancer must both be `Standard` SKU — mixing `Basic` and
`Standard` breaks the apply.

---

## 5. Workflow (PowerShell) — Including the Testable Output

```powershell
cd C:\Projects\apx-infra-006

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

terraform output lb_public_ip

# Wait ~2 minutes for cloud-init to finish on both instances

# THE ACTUAL TEST — hit the LB repeatedly, watch responses rotate
$lbIp = terraform output -raw lb_public_ip
1..6 | ForEach-Object {
    (Invoke-WebRequest "http://$lbIp" -TimeoutSec 5).Content
    Start-Sleep -Seconds 1
}
```

**What you should see:** the hostname in each response should
alternate between your two instances — real, visible evidence
that the Load Balancer is distributing traffic across a live VMSS
pool, not just a resource that exists on paper.

```powershell
# Verify pool membership via CLI too
az network lb address-pool show `
  --lb-name apx-dev-006-lb `
  --resource-group apx-dev-006-rg `
  --name apx-dev-006-pool `
  --output table

terraform destroy
```

---

## 6. Checklist

```
[ ] Public IP + LB both sku = "Standard"
[ ] load_balancer_backend_address_pool_ids set INSIDE the VMSS
    network_interface block — no separate association resource
[ ] Health probe uses for_each (even for a single entry, per the
    standing mechanic-rotation rule)
[ ] Repeated requests to the LB IP show alternating instance hostnames
[ ] terraform destroy completed
```

---

## 7. Cost
Standard LB (~$0.025/hr) + 2× `Standard_B1s` (~$0.026/hr) +
Standard Public IP (~$0.005/hr). **A few hours of lab time: well
under $1.**

## Series Status
```
APX-005   ✅  VM Scale Set Basics
APX-006   ✅  Load Balancer + VMSS Together                 ← THIS PROJECT
APX-007   📋  Multi-Tier Lab 1 — Web + App Tier
```

*Apex Industries — Cloud Platform Engineering | Training Series*
