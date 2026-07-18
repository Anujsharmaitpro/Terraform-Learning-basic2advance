# Meridian Bank — Cloud Infrastructure Training Series
## Private Networking + Standard Load Balancer
**Project Code:** `MRB-INFRA-004` | **Level:** Beginner+ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained

---

> **From your Team Lead:** Two VMs, one Load Balancer distributing
> traffic between them. If one VM goes down, traffic keeps flowing
> to the other. This is the most universally used networking
> pattern in the industry — startup or bank, everyone builds this.
> — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | No dependencies — standalone

---

## 1. Overview

**Two Linux VMs behind one Standard Load Balancer, with a health
probe checking availability and a rule distributing HTTP traffic.**

```
                Load Balancer (mrb-dev-004-lb)
                Public IP → Frontend IP Config
                       │
          ┌────────────┴────────────┐
          ▼                          ▼
   VM1 (mrb-dev-004-vm1)      VM2 (mrb-dev-004-vm2)
   Backend Pool member        Backend Pool member
   Health probe: TCP 80       Health probe: TCP 80
```

### New Concepts
| Concept | What It Does |
|---|---|
| `azurerm_lb` | The Load Balancer resource itself |
| `azurerm_lb_backend_address_pool` | Group of VMs receiving traffic |
| `azurerm_lb_probe` | Health check — is this VM alive? |
| `azurerm_lb_rule` | Which traffic goes where |
| `azurerm_network_interface_backend_address_pool_association` | Links a VM's NIC to the pool |

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network`, `azurerm_subnet`,
`azurerm_network_security_group`, `azurerm_network_interface`,
`azurerm_linux_virtual_machine` (× 2, use `for_each`), `locals` tags.

> **Note:** Unlike NCT-002, these VMs do NOT get individual public
> IPs — only the Load Balancer has a public IP. The VMs are only
> reachable through it. This is the private/secure pattern Meridian
> requires.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-004-rg` |
| VNet / Subnet | `mrb-dev-004-vnet` / `mrb-dev-004-subnet` |
| NSG | `mrb-dev-004-nsg` |
| Load Balancer | `mrb-dev-004-lb` |
| LB Public IP | `mrb-dev-004-lb-pip` |
| Backend Pool | `mrb-dev-004-pool` |
| Health Probe | `mrb-dev-004-probe` |
| LB Rule | `mrb-dev-004-rule` |
| VMs | `mrb-dev-004-vm1`, `mrb-dev-004-vm2` (via `for_each`) |

Same 8 MRB tags. `DataClassification = "internal"`.

```hcl
# terraform.tfvars
org_prefix          = "mrb"
environment         = "dev"
azure_location      = "East US"
resource_group_name = "mrb-dev-004-rg"
vm_size             = "Standard_B1s"
admin_username      = "mrbadmin"
allowed_ssh_ip      = "YOUR_PUBLIC_IP/32"
owner_name          = "alex-morgan"
cost_centre         = "CC-CLOUD-001"
data_classification = "internal"
compliance_scope    = "internal-audit"

vm_names = ["vm1", "vm2"]   # set(string) — used with for_each
```

---

## 3. Core Components

### Component 1 — Networking Foundation
RG, VNet, Subnet, NSG (allow inbound TCP 80 from anywhere — the LB
needs to reach the VMs; allow SSH only from `var.allowed_ssh_ip`).
Build from memory.

### Component 2 — Two VMs via `for_each` (NO Public IP Each)

```hcl
resource "azurerm_network_interface" "vm_nic" {
  for_each            = toset(var.vm_names)
  name                = "mrb-dev-004-${each.value}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    # NOTE: no public_ip_address_id here — that's the whole point
  }
  tags = local.common_tags
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = toset(var.vm_names)
  name                = "mrb-dev-004-${each.value}"
  # ... size, admin_username, ssh key, os_disk, source_image_reference
  network_interface_ids = [azurerm_network_interface.vm_nic[each.key].id]
  tags = local.common_tags
}
```

> Same `for_each` + `set(string)` pattern from NCT-008. `each.key`
> and `each.value` are identical here — both give you `"vm1"`/`"vm2"`.

### Component 3 — Load Balancer

```hcl
resource "azurerm_public_ip" "lb_pip" {
  name                = "mrb-dev-004-lb-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"    # must match LB SKU below
  tags                = local.common_tags
}

resource "azurerm_lb" "lb" {
  name                = "mrb-dev-004-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "mrb-dev-004-pool"
}

resource "azurerm_lb_probe" "probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "mrb-dev-004-probe"
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "mrb-dev-004-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
  probe_id                       = azurerm_lb_probe.probe.id
}
```

> **`azurerm_lb_backend_address_pool` and `azurerm_lb_probe` do NOT
> accept `tags`** — Azure API limitation, same pattern as subnets.
> Don't add tags to these two.

### Component 4 — Connect Each VM's NIC to the Backend Pool

```hcl
resource "azurerm_network_interface_backend_address_pool_association" "assoc" {
  for_each                = toset(var.vm_names)
  network_interface_id    = azurerm_network_interface.vm_nic[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}
```

> This is the missing link — without it, the LB has a pool and the
> VMs exist, but they are never actually IN the pool. Traffic would
> never reach them. Same category of mistake as forgetting the NSG
> association back in NCT-002.

### Component 5 — Variables + Outputs
Variable `vm_names` declared as `type = set(string)`.
Outputs: `lb_public_ip` (from `azurerm_public_ip.lb_pip.ip_address`),
`vm_names_created` (via `keys()`), `resource_group_name`.

---

## 4. Hints

**Hint 1 — SKU mismatch breaks everything:** Public IP `sku` and
Load Balancer `sku` MUST both be `"Standard"` or both `"Basic"`.
Mixing them causes an apply-time error. Standard is the MRB
requirement — always use Standard for both.

**Hint 2 — No public IP on the VMs is intentional, not a mistake:**
If you try to SSH directly to a VM's IP, it will fail — there isn't
one reachable from outside. Access in this project is proven via
Azure CLI checks, not direct SSH. (A future project introduces
Azure Bastion or a jump box for secure access — not covered here.)

**Hint 3 — The backend pool association is easy to forget:** the
Load Balancer, VMs, and pool can all apply successfully without
Component 4. Nothing errors — traffic just silently never reaches
the VMs. Always verify pool membership via CLI, not just a clean
`terraform apply`.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\mrb-infra-004
terraform init; terraform validate; terraform fmt; terraform plan
terraform apply    # type: yes

terraform output lb_public_ip
az network lb address-pool list --lb-name mrb-dev-004-lb --resource-group mrb-dev-004-rg --output table
az network lb probe list --lb-name mrb-dev-004-lb --resource-group mrb-dev-004-rg --output table

# Confirm both NICs are in the pool
az network nic show --name mrb-dev-004-vm1-nic --resource-group mrb-dev-004-rg --query "ipConfigurations[0].loadBalancerBackendAddressPools" --output table
az network nic show --name mrb-dev-004-vm2-nic --resource-group mrb-dev-004-rg --query "ipConfigurations[0].loadBalancerBackendAddressPools" --output table

terraform destroy    # type: yes
```

---

## 6. Checklist

```
[ ] Public IP + LB both sku = "Standard"
[ ] VMs have NO public IP — internal only
[ ] azurerm_lb_backend_address_pool and azurerm_lb_probe have NO tags
[ ] for_each with set(string) used for VMs and their NICs
[ ] NIC-to-pool association resource present (Component 4) — easy to skip
[ ] lb_rule references both probe_id and backend_address_pool_ids
[ ] Both VMs confirmed in backend pool via CLI
[ ] terraform destroy completed
```

---

## 7. Cost
Standard LB (~$0.025/hr) + 2× Standard_B1s VMs (~$0.026/hr combined)
+ Standard Public IP (~$0.005/hr). **A few hours of lab time: well
under $1.**

## Next: MRB-INFRA-005 — Traffic Manager + Routing Concepts

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
