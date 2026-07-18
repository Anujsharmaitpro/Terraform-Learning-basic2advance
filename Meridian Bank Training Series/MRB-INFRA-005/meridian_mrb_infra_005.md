# Meridian Bank — Cloud Infrastructure Training Series
## Traffic Manager + Routing Concepts
**Project Code:** `MRB-INFRA-005` | **Level:** Beginner+ | **Frequency:** Used everywhere with multi-region needs
**Environment:** Windows + VS Code + PowerShell | Fully self-contained

---

> **From your Team Lead:** MRB-004's Load Balancer works within one
> region. If East US goes down entirely, the Load Balancer goes
> down with it. Traffic Manager works at the DNS level, across
> regions — it can send users to whichever region is actually
> healthy. This ticket simulates that using two simple endpoints,
> no need to actually deploy to two regions. — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | No dependencies — standalone

---

## 1. Overview

**A Traffic Manager profile routing between two App Services —
one acting as "primary," one as "failover" — using Priority
routing, the simplest and most common method.**

```
                     User requests: mrb-dev-005.trafficmanager.net
                                  │
                                  ▼
                    Traffic Manager Profile (mrb-dev-005-tm)
                    Routing method: Priority
                          │                    │
                    Priority 1                Priority 2
                    (Primary)                 (Failover)
                          ▼                    ▼
              App Service: web-primary   App Service: web-secondary
              (mrb-dev-005-primary-jd)   (mrb-dev-005-secondary-jd)
```

### The Core Concept — DNS-Level Routing, Not Traffic Splitting

This is genuinely different from the Load Balancer in MRB-004.
A Load Balancer sits IN the traffic path — every packet passes
through it. Traffic Manager works purely at the **DNS level** —
it tells the user's browser WHICH address to connect to, then
gets out of the way entirely. The actual traffic never passes
through Traffic Manager itself.

```
Load Balancer  → traffic physically flows through it
Traffic Manager → only answers "which address should you use?"
                   then steps aside completely
```

### Routing Methods (You Will Use `Priority`)

| Method | What It Does |
|---|---|
| **Priority** | Always send to #1 unless it's unhealthy, then fall to #2 |
| Weighted | Split traffic by percentage across endpoints |
| Performance | Send users to whichever endpoint is geographically closest |
| Geographic | Route based on the user's actual location |

Priority is the simplest and most common starting point — this
is exactly the "primary/failover" pattern most orgs reach for first.

### New Concepts
| Concept | What It Does |
|---|---|
| `azurerm_traffic_manager_profile` | The routing policy container |
| `azurerm_traffic_manager_azure_endpoint` | One destination Traffic Manager can route to |
| `monitor_config` block | Health check Traffic Manager uses to judge endpoint health |

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_service_plan`, `azurerm_linux_web_app`
(× 2, via `for_each`), `locals` tags.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-005-rg` |
| Traffic Manager Profile | `mrb-dev-005-tm` |
| App Service Plan | `mrb-dev-005-plan` |
| App Services | `mrb-dev-005-primary-jd`, `mrb-dev-005-secondary-jd` |

Same 8 MRB tags. `DataClassification = "internal"`.

```hcl
# terraform.tfvars
org_prefix           = "mrb"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "mrb-dev-005-rg"
owner_name           = "alex-morgan"
cost_centre          = "CC-CLOUD-001"
data_classification  = "internal"
compliance_scope     = "internal-audit"

app_endpoints = {
  "primary" = {
    name     = "mrb-dev-005-primary-jd"
    priority = 1
  }
  "secondary" = {
    name     = "mrb-dev-005-secondary-jd"
    priority = 2
  }
}
```

> Notice: `app_endpoints` is a `map(object({...}))` — same pattern
> family as `metric_alerts` from NCT-009. Each entry needs a name
> AND a priority, so a simple map or set isn't enough.

---

## 3. Core Components

### Component 1 — Resource Group + Two App Services via `for_each`

```hcl
resource "azurerm_service_plan" "plan" {
  name                = "mrb-dev-005-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "F1"
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "app" {
  for_each            = var.app_endpoints
  name                = each.value.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    always_on = false
    application_stack {
      python_version = "3.11"
    }
  }
  tags = local.common_tags
}
```

> Build the rest (RG, tags locals) from memory — you know this.

### Component 2 — Traffic Manager Profile

```hcl
resource "azurerm_traffic_manager_profile" "tm" {
  name                   = "mrb-dev-005-tm"
  resource_group_name    = azurerm_resource_group.rg.name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "mrb-dev-005"    # becomes mrb-dev-005.trafficmanager.net
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = local.common_tags
}
```

> `dns_config.relative_name` must be **globally unique** across
> all of Azure — add your initials if `mrb-dev-005` is taken.
>
> `monitor_config` is how Traffic Manager decides an endpoint is
> "unhealthy" — it polls the path you specify, on the interval you
> specify. If an endpoint fails `tolerated_number_of_failures`
> checks in a row, Traffic Manager stops routing to it.

### Component 3 — Endpoints with `for_each`

```hcl
resource "azurerm_traffic_manager_azure_endpoint" "endpoints" {
  for_each           = var.app_endpoints
  name               = "${each.key}-endpoint"
  profile_id         = azurerm_traffic_manager_profile.tm.id
  target_resource_id = azurerm_linux_web_app.app[each.key].id
  priority           = each.value.priority
}
```

> `azurerm_linux_web_app.app[each.key]` — this is worth pausing
> on. Because BOTH the App Services (Component 1) and the
> endpoints (Component 3) use the SAME `for_each` map
> (`var.app_endpoints`), you can use `each.key` to look up the
> matching App Service directly by its map key. This is how you
> connect two separate `for_each` resource sets that share the
> same keys.

> **Note:** `azurerm_traffic_manager_azure_endpoint` does NOT
> support `tags` — Azure API limitation, same category as subnets
> and LB backend pools.

### Component 4 — Variables + Outputs

Variable `app_endpoints` declared as:
```hcl
variable "app_endpoints" {
  type = map(object({
    name     = string
    priority = number
  }))
}
```

Outputs:
```
traffic_manager_fqdn     ← azurerm_traffic_manager_profile.tm.fqdn
endpoints_created        ← keys(azurerm_traffic_manager_azure_endpoint.endpoints)
resource_group_name
```

---

## 4. Hints

**Hint 1 — Linking two `for_each` blocks by shared keys is the core
skill here:** `azurerm_linux_web_app.app[each.key]` only works
because Component 1 and Component 3 both iterate over the exact
same `var.app_endpoints` map. If they used different maps with
different keys, this lookup would fail with a "key not found" error.

**Hint 2 — `monitor_config` needs a real, reachable path:** Free
tier (F1) App Services serve a default Azure placeholder page at
`/`, which returns `200 OK` — so `path = "/"` works fine for this
exercise without deploying any real app code.

**Hint 3 — Priority routing only fails over when the primary is
UNHEALTHY, not merely slow:** Traffic Manager will keep sending
100% of traffic to the priority-1 endpoint as long as it passes
health checks — even if it's technically slower than the
secondary. This is different from load balancing; it is pure
failover, not performance optimization.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\mrb-infra-005
terraform init; terraform validate; terraform fmt; terraform plan
terraform apply    # type: yes

terraform output traffic_manager_fqdn
# e.g. mrb-dev-005.trafficmanager.net

az network traffic-manager endpoint list `
  --profile-name mrb-dev-005-tm `
  --resource-group mrb-dev-005-rg `
  --output table
# Expected: both endpoints listed, primary shows priority 1

# Check current health status
az network traffic-manager profile show `
  --name mrb-dev-005-tm `
  --resource-group mrb-dev-005-rg `
  --query "monitorConfig.profileMonitorStatus" `
  --output tsv
# Expected: "Online" (may take a few minutes after apply to report)

terraform destroy    # type: yes
```

---

## 6. Checklist

```
[ ] dns_config.relative_name is globally unique
[ ] traffic_routing_method = "Priority"
[ ] monitor_config protocol/port/path set correctly (HTTPS, 443, "/")
[ ] Both App Services and endpoints use the SAME for_each map
[ ] azurerm_linux_web_app.app[each.key] used to link endpoint to app
[ ] priority = 1 for primary, priority = 2 for secondary
[ ] azurerm_traffic_manager_azure_endpoint has NO tags argument
[ ] endpoints_created output shows both endpoint names
[ ] terraform destroy completed
```

---

## 7. Cost
Traffic Manager: pay per DNS query, ~$0.54 per million queries —
for lab-scale testing, fractions of a cent. Two F1 App Services:
free. **Total: near $0.00.**

## Series Status
```
MRB-001  ✅ Secure Storage + Compliance
MRB-002  ✅ Azure AD + Managed Identity (VM)
MRB-003  ✅ Managed Identity (App Service) + Key Vault refs
MRB-004  ✅ Private Networking + Load Balancer
MRB-005  ✅ Traffic Manager + Routing              ← THIS PROJECT
MRB-006  📋 Multi-Tier Design Part 1 — Web + App Tier
```

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
