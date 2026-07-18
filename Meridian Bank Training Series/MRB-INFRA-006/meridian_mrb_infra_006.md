# Meridian Bank — Cloud Infrastructure Training Series
## Multi-Tier Design Part 1 — Web Tier + App Tier with VNet Integration
**Project Code:** `MRB-INFRA-006` | **Level:** Beginner++ | **Frequency:** Universal architecture pattern
**Environment:** Windows + VS Code + PowerShell | Fully self-contained

---

> **From your Team Lead:** Every project so far has been one
> resource type at a time. This ticket is different — it's your
> first architecture exercise. A proper application separates
> concerns: the Web Tier faces the internet, the App Tier does
> not. The App Tier should be completely unreachable from outside
> the VNet. This is the pattern behind almost every real
> production system you'll ever touch. — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | No dependencies — standalone

---

## 1. Overview

**Two App Services — Web Tier (public) and App Tier (private) —
connected through VNet Integration, with an NSG ensuring the App
Tier only accepts traffic from the Web Tier's subnet.**

```
Internet
   │
   ▼
┌─────────────────────────────────────────┐
│  Web Tier — App Service (public)         │
│  mrb-dev-006-web-jd                       │
│  VNet Integrated → web-subnet             │
└───────────────────┬───────────────────────┘
                    │ private call over VNet
                    ▼
┌─────────────────────────────────────────┐
│  App Tier — App Service (NOT public)     │
│  mrb-dev-006-app-jd                       │
│  VNet Integrated → app-subnet             │
│  NSG: only allow inbound from web-subnet  │
└─────────────────────────────────────────┘
```

### The New Concept — VNet Integration

Everything you've networked so far (NCT-002, MRB-004) has been
VMs — resources that live natively inside a VNet. App Services
are different: by default they live OUTSIDE any VNet, in Azure's
shared multi-tenant network. VNet Integration is how you give an
App Service a leg into your private network.

```
Without VNet Integration:
  App Service ←→ Azure's public network ←→ anything it calls

With VNet Integration:
  App Service ←→ YOUR VNet (private) ←→ other resources in that VNet
```

**Important distinction:** VNet Integration is OUTBOUND only.
It lets the App Service REACH INTO the VNet to call other things
privately. It does NOT make the App Service itself unreachable
from the internet — the Web Tier is still publicly accessible
by design. For the App Tier to actually become unreachable from
outside, you also need `public_network_access_enabled = false`
plus the NSG rule — VNet Integration alone is not enough.

### New Terraform Resource

| Resource | Purpose |
|---|---|
| `azurerm_app_service_virtual_network_swift_connection` | Connects an App Service to a VNet subnet |

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network`, `azurerm_subnet`
(× 2 — you know multi-subnet patterns from NCT-002/MRB-004),
`azurerm_network_security_group`, `azurerm_service_plan`,
`azurerm_linux_web_app`, `locals` tags.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-006-rg` |
| VNet | `mrb-dev-006-vnet` |
| Web Subnet | `mrb-dev-006-web-subnet` (10.0.1.0/24) |
| App Subnet | `mrb-dev-006-app-subnet` (10.0.2.0/24) |
| App Tier NSG | `mrb-dev-006-app-nsg` |
| App Service Plan | `mrb-dev-006-plan` |
| Web Tier App Service | `mrb-dev-006-web-jd` |
| App Tier App Service | `mrb-dev-006-app-jd` |

Same 8 MRB tags. `DataClassification = "internal"`.

```hcl
# terraform.tfvars
org_prefix           = "mrb"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "mrb-dev-006-rg"
owner_name           = "alex-morgan"
cost_centre          = "CC-CLOUD-001"
data_classification  = "internal"
compliance_scope     = "internal-audit"
```

> **Note on tier:** VNet Integration requires `B1` tier minimum —
> `F1` (Free) does not support it. This is the first Meridian
> project where you pay a small, real hourly rate. Destroy
> promptly after your lab session.

---

## 3. Core Components

### Component 1 — Networking: Two Subnets

Build a VNet with TWO subnets (not one, like previous projects):

```hcl
resource "azurerm_subnet" "web_subnet" {
  name                 = "mrb-dev-006-web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "web-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "mrb-dev-006-app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "app-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
```

> **The `delegation` block is mandatory and new.** A subnet used
> for App Service VNet Integration must be "delegated" to
> `Microsoft.Web/serverFarms` — this tells Azure the subnet is
> reserved for App Service use specifically. Without this block,
> the VNet Integration connection will fail to apply.

### Component 2 — App Tier NSG (Web Subnet Only)

```hcl
resource "azurerm_network_security_group" "app_nsg" {
  name                = "mrb-dev-006-app-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-From-Web-Subnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.1.0/24"   # web subnet only
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Other-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}
```

> **Rule ordering matters.** Priority 100 (allow from web subnet)
> is evaluated before priority 200 (deny everything else). Azure
> NSGs process rules in priority order, lowest number first, and
> stop at the first match. If you reversed the priorities, the
> deny rule would block everything before the allow rule ever
> got a chance to run.

### Component 3 — App Service Plan + Both App Services

```hcl
resource "azurerm_service_plan" "plan" {
  name                = "mrb-dev-006-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"    # NOT F1 — VNet integration requires this
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "web_tier" {
  name                = "mrb-dev-006-web-jd"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }
  tags = local.common_tags
}

resource "azurerm_linux_web_app" "app_tier" {
  name                          = "mrb-dev-006-app-jd"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  service_plan_id                = azurerm_service_plan.plan.id
  public_network_access_enabled = false   # NEW — App Tier truly locked down

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }
  tags = local.common_tags
}
```

> `public_network_access_enabled = false` on the App Tier is what
> actually removes its public internet exposure. VNet Integration
> alone does not do this — the two settings work together.

### Component 4 — VNet Integration Connections

```hcl
resource "azurerm_app_service_virtual_network_swift_connection" "web_vnet" {
  app_service_id = azurerm_linux_web_app.web_tier.id
  subnet_id      = azurerm_subnet.web_subnet.id
}

resource "azurerm_app_service_virtual_network_swift_connection" "app_vnet" {
  app_service_id = azurerm_linux_web_app.app_tier.id
  subnet_id      = azurerm_subnet.app_subnet.id
}
```

> Each App Service gets its OWN swift connection to its OWN
> subnet. This is the resource that actually performs the "give
> the App Service a leg into the VNet" action described in the
> concept overview.

### Component 5 — Variables + Outputs

Outputs:
```
web_tier_url               ← public URL of the Web Tier
app_tier_default_hostname  ← App Tier's hostname (not publicly reachable, but useful for reference)
resource_group_name
web_subnet_id
app_subnet_id
```

---

## 4. Hints

**Hint 1 — Forgetting the `delegation` block is the #1 failure
mode:** without it, `terraform apply` fails at the VNet Integration
step with an error about the subnet not being properly delegated.
Both subnets need it, even the Web Tier's — every subnet used for
App Service integration needs delegation, regardless of whether
that tier is public or private.

**Hint 2 — `public_network_access_enabled = false` will make even
YOU unable to browse to the App Tier's URL:** this is correct
behavior, not a bug. Verification for the App Tier happens via
Azure CLI, not by opening it in a browser — same pattern as
MRB-004's VMs with no public IP.

**Hint 3 — B1 tier means real, ongoing cost:** unlike every F1
project before this, `B1` has an hourly charge (~$0.018/hr for
Linux B1, roughly $13/month if left running continuously). For a
few hours of lab time this is pennies — but don't forget to
`terraform destroy` when you're done. This is not a "leave it
running overnight by accident" tier.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\mrb-infra-006
terraform init; terraform validate; terraform fmt; terraform plan
terraform apply    # type: yes — takes a few minutes longer due to VNet integration

terraform output web_tier_url
Start-Process (terraform output -raw web_tier_url)
# Should open successfully — default Azure placeholder page

# Confirm App Tier is NOT publicly reachable
$appHost = terraform output -raw app_tier_default_hostname
Invoke-WebRequest "https://$appHost" -TimeoutSec 5
# Expected: this should FAIL or timeout — proving it's locked down

# Confirm VNet integration is active
az webapp vnet-integration list `
  --name mrb-dev-006-web-jd `
  --resource-group mrb-dev-006-rg `
  --output table

az webapp vnet-integration list `
  --name mrb-dev-006-app-jd `
  --resource-group mrb-dev-006-rg `
  --output table

terraform destroy    # type: yes — do this promptly, B1 has real hourly cost
```

---

## 6. Checklist

```
[ ] Both subnets have the delegation block for Microsoft.Web/serverFarms
[ ] App Service Plan sku_name = "B1" (not F1)
[ ] App Tier has public_network_access_enabled = false
[ ] App Tier NSG: allow from web subnet (priority 100), deny all else (priority 200)
[ ] Rule priorities correct — allow rule has LOWER number than deny rule
[ ] Two separate azurerm_app_service_virtual_network_swift_connection resources
[ ] Web Tier URL opens successfully in browser
[ ] App Tier request times out / fails when tested directly
[ ] terraform destroy run promptly after lab (B1 has real cost)
```

---

## 7. Cost
`B1` App Service Plan: ~$0.018/hr × 1 plan (shared by both apps)
= roughly **$0.05-0.10 for a 3-4 hour lab session.** Destroy
promptly — this is your first project with genuine ongoing cost
if left running.

## Next: MRB-INFRA-007 — Add Data Tier via Private Endpoint

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
