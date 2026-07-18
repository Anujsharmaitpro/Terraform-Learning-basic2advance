# Meridian Bank — Cloud Infrastructure Training Series
## Application Gateway + WAF
**Project Code:** `MRB-INFRA-009` | **Level:** Intermediate+ | **Frequency:** Common in enterprise/regulated orgs
**Environment:** Windows + VS Code + PowerShell | Fully self-contained

---

> ## ⚠️ COST WARNING — READ BEFORE STARTING
>
> Application Gateway (Standard_v2) costs approximately **$0.36/hour
> the moment it exists** — even completely idle, even with zero
> traffic. This is a FIXED cost, unlike everything else in this
> series.
>
> ```
> 1 hour running   → ~$0.36
> 4 hour lab        → ~$1.44
> Full day (24hr)   → ~$8.60
> Left a full month → ~$260
> ```
>
> **This is the ONE project across both the NexaCore and Meridian
> series where the resource itself is genuinely expensive.**
> Your $5-10/month budget comfortably covers a single 1-2 hour
> focused session — it does NOT cover forgetting to destroy this
> overnight.
>
> **Plan to:** apply → verify → take notes → destroy, all in one sitting.
> Set a phone timer if that helps. Do not leave this running
> "to check later."

---

> **From your Team Lead:** Everything you've built so far handles
> traffic at the network layer (Load Balancer) or DNS layer
> (Traffic Manager). Application Gateway operates one layer up —
> it understands HTTP itself. It can route based on URL path,
> terminate SSL, and inspect requests for common web attacks
> before they ever reach your app. This is genuinely the most
> expensive lesson in the series — treat the lab time with
> respect. — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | Fully standalone

---

## 1. Overview

**An Application Gateway with WAF (Web Application Firewall)
enabled in Detection mode, routing traffic to a backend App
Service — proving Layer 7 routing and basic attack inspection.**

```
Internet
   │
   ▼
Application Gateway (mrb-dev-009-agw)
   WAF: Detection mode (logs attacks, doesn't block — safer for learning)
   Listener: HTTP, port 80
   │
   ▼
Backend Pool → App Service (mrb-dev-009-web-jd)
```

### The New Concept — Layer 7 vs Layer 4

**MRB-004's Load Balancer** operates at Layer 4 (transport layer)
— it sees IP addresses and ports, nothing about the content of
the HTTP request itself.

**Application Gateway** operates at Layer 7 (application layer)
— it can read the actual HTTP request: the URL path, headers,
cookies, and the request body. This is what makes path-based
routing and WAF inspection possible.

```
Layer 4 (Load Balancer)  → "This is TCP traffic on port 80"
Layer 7 (App Gateway)     → "This is a GET request to /api/users
                              with a suspicious SQL string in
                              the query parameter"
```

### New Terraform Resources

| Resource | Purpose |
|---|---|
| `azurerm_application_gateway` | The gateway itself — listeners, rules, backend pools, WAF |
| WAF configuration (nested block) | Attack detection rules (OWASP ruleset) |

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network` + subnet
(App Gateway needs its own dedicated subnet), `azurerm_public_ip`,
`azurerm_service_plan` + `azurerm_linux_web_app` (the backend).

---

## 2. Best Practices Applied

### `.gitignore` — same as previous projects, no changes needed.

### README.md Template

```markdown
# MRB-INFRA-009 — Application Gateway + WAF

## ⚠️ COST WARNING
~$0.36/hour fixed cost while running. Single-session lab only.

## What This Provisions
Application Gateway (Standard_v2) with WAF in Detection mode,
routing to a backend App Service.

## Prerequisites
- Azure CLI logged in
- Terraform v1.6+
- A clear 1-2 hour block of time — do not start this and walk away

## How to Run
​```powershell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
​```

## How to Destroy — DO THIS PROMPTLY
​```powershell
terraform destroy
​```

## Estimated Cost
~$0.36/hr minimum. A 2-hour session: ~$0.72.
```

---

## 3. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-009-rg` |
| VNet | `mrb-dev-009-vnet` |
| App Gateway Subnet | `mrb-dev-009-agw-subnet` (10.0.1.0/24) |
| Public IP | `mrb-dev-009-agw-pip` |
| Application Gateway | `mrb-dev-009-agw` |
| App Service Plan / Service | `mrb-dev-009-plan` / `mrb-dev-009-web-jd` |

Same 8 MRB tags. `DataClassification = "internal"`.

```hcl
# terraform.tfvars
org_prefix           = "mrb"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "mrb-dev-009-rg"
app_service_name     = "mrb-dev-009-web-jd"
owner_name           = "alex-morgan"
cost_centre          = "CC-CLOUD-001"
data_classification  = "internal"
compliance_scope     = "internal-audit"
```

---

## 4. Core Components

### Component 1 — Networking: Dedicated App Gateway Subnet

```hcl
resource "azurerm_subnet" "agw_subnet" {
  name                 = "mrb-dev-009-agw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "agw_pip" {
  name                = "mrb-dev-009-agw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}
```

> Application Gateway requires its OWN dedicated subnet — it
> cannot share a subnet with VMs, App Services, or any other
> resource type. This is an Azure hard requirement, not a
> Meridian policy choice.

### Component 2 — Backend App Service

Standard `azurerm_service_plan` (`F1`) + `azurerm_linux_web_app` —
you know this pattern completely. Build from memory.

### Component 3 — Application Gateway

This resource has more nested blocks than anything you've built
so far. Read each piece slowly — do not rush this one.

```hcl
resource "azurerm_application_gateway" "agw" {
  name                = "mrb-dev-009-agw"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1              # minimum — keeps cost as low as possible
  }

  gateway_ip_configuration {
    name      = "agw-ip-config"
    subnet_id = azurerm_subnet.agw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "agw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.agw_pip.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  backend_address_pool {
    name  = "backend-pool"
    fqdns = [azurerm_linux_web_app.app.default_hostname]
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "agw-frontend-ip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"   # NOT "Prevention" — logs only, doesn't block
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  tags = local.common_tags
}
```

**Break down the nested blocks — each answers one question:**

```
sku                          → HOW big/capable is this gateway?
gateway_ip_configuration     → WHERE does the gateway itself live? (its own subnet)
frontend_ip_configuration    → WHAT public IP does it listen on?
frontend_port                → WHAT port does it listen on?
backend_address_pool         → WHERE does traffic get sent?
backend_http_settings        → HOW does it talk to the backend? (port, protocol, timeout)
http_listener                → COMBINES frontend IP + port + protocol into one listening endpoint
request_routing_rule         → CONNECTS a listener to a backend pool via settings
waf_configuration            → WHAT attack patterns does it watch for?
```

> **`firewall_mode = "Detection"` is a deliberate, important
> choice for this learning project.** Detection mode LOGS
> suspicious requests without blocking them — safer for a lab
> environment where you don't want to accidentally lock yourself
> out while testing. Production environments typically use
> `"Prevention"`, which actively blocks detected attacks. Never
> use `"Prevention"` mode without first observing Detection mode
> logs for a while — Prevention can block legitimate traffic if
> your WAF rules are miscalibrated.

> **`capacity = 1`** is the minimum WAF-enabled Standard_v2
> instance count. Keeping this at 1 (rather than allowing
> autoscaling) is the deliberate cost-control choice for this lab.

### Component 4 — Variables + Outputs

Outputs:
```
agw_public_ip         ← azurerm_public_ip.agw_pip.ip_address
agw_name
backend_app_url
resource_group_name
```

---

## 5. Hints

**Hint 1 — Application Gateway takes 15-20 minutes to provision:**
this is by far the longest `terraform apply` in the entire series.
Do not cancel it. Do not assume it's frozen. Budget extra time
in your single-session plan for this specifically.

**Hint 2 — `backend_address_pool` uses `fqdns`, not an IP or a
resource ID:** unlike the Load Balancer in MRB-004, which pooled
VMs by their NIC associations, Application Gateway's backend pool
for an App Service uses its DNS hostname
(`azurerm_linux_web_app.app.default_hostname`) directly as a
string in a list. This is a different pooling mechanism entirely
— don't try to reuse the MRB-004 NIC association pattern here,
it doesn't apply to App Gateway.

**Hint 3 — Every named nested block must match exactly across
references:** `frontend_ip_configuration_name = "agw-frontend-ip"`
in the listener MUST exactly match the `name` you gave the
`frontend_ip_configuration` block earlier. These are string
references, not object references — a typo here doesn't error
at `terraform validate`, it fails later at `apply` with a
"referenced resource not found" style error. Triple check every
`_name` argument against its matching block's `name`.

---

## 6. Workflow (PowerShell — Single Session, Timed)

```powershell
# START YOUR TIMER NOW
cd C:\Projects\mrb-infra-009

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
# Takes 15-20 minutes — this is expected, do not interrupt

terraform output agw_public_ip

# Verify the gateway is running
az network application-gateway show `
  --name mrb-dev-009-agw `
  --resource-group mrb-dev-009-rg `
  --query "{Name:name, State:operationalState, Sku:sku.name}" `
  --output table
# Expected: State = Running

# Test it — open the public IP in a browser
Start-Process "http://$(terraform output -raw agw_public_ip)"
# Should route through the gateway to your backend App Service

# Check WAF detection logs (may take a few minutes to populate)
az network application-gateway waf-policy list `
  --resource-group mrb-dev-009-rg `
  --output table

# ── DESTROY IMMEDIATELY AFTER VERIFICATION ──────────────────
terraform destroy
# Type: yes — do not delay this step
```

---

## 7. Checklist

```
[ ] Dedicated subnet used ONLY for the Application Gateway
[ ] sku.capacity = 1 (cost control — no autoscaling for this lab)
[ ] waf_configuration.firewall_mode = "Detection" (NOT "Prevention")
[ ] backend_address_pool uses fqdns, not NIC associations
[ ] Every _name reference matches its corresponding block's name exactly
[ ] terraform apply allowed to run uninterrupted for 15-20 minutes
[ ] Public IP opens successfully and routes to backend App Service
[ ] terraform destroy run IMMEDIATELY after verification — no delay
[ ] Total session time under 2 hours
```

---

## 8. Cost — The One Exception in This Series

```
Standard_v2 App Gateway    ~$0.36/hr (fixed, regardless of traffic)
Standard Public IP         ~$0.005/hr
────────────────────────────────────────────
2-hour focused session:     ~$0.73
```

**This is still well inside your $5-10/month budget** — but only
if you destroy promptly. This is the one project in the entire
series where "I'll get to it later" turns pennies into dollars
quickly.

## Series Status
```
MRB-001 to 008   ✅  Foundations through Azure Policy
MRB-009          ✅  Application Gateway + WAF  ← THIS PROJECT (destroy promptly!)
MRB-010          📋  Full Capstone
```

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
