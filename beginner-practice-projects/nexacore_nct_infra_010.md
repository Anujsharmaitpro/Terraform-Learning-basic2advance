# NexaCore Technologies — Internal DevOps Training Project
## Full Stack Capstone — Everything Together
**Project Code:** `NCT-INFRA-010` | **Track:** Junior DevOps Engineer | **Level:** Capstone
**Environment:** Windows + VS Code + PowerShell
**Status:** Final project in the NexaCore series — fully self-contained

---

> **A message from your Tech Lead:**
> Nine tickets. Nine different pieces of Azure. You have built
> networking, compute, storage, secrets management, serverless,
> databases, container registries, and monitoring — one piece
> at a time.
>
> This last ticket does not teach you anything new. Its entire
> purpose is proving you can bring it all together into one
> coherent, working system — the way it actually looks in a
> real company. A module for the reusable part. A database.
> An app tier. Secrets handled properly. Monitoring watching
> all of it. Tags compliant throughout.
>
> This is the project you show in an interview. Build it clean.
> — *Priya Menon, Lead DevOps, NexaCore Technologies*

---

## Org Context

| Field | Detail |
|---|---|
| **Organisation** | NexaCore Technologies Pvt. Ltd. |
| **Department** | Platform Engineering |
| **Team** | DevOps – Infrastructure |
| **Your Role** | Junior DevOps Engineer (Trainee) |
| **Reporting To** | Priya Menon (Lead DevOps) |
| **Ticket ID** | `NCT-INFRA-010` |
| **Depends On** | Nothing — fully standalone, all resources created fresh |
| **Environment** | `dev` only |
| **Cloud** | Microsoft Azure |
| **IaC Tool** | Terraform `v1.6+` |
| **Azure Region** | `East US` |
| **Cost Centre** | `CC-DEVOPS-007` |
| **Terminal** | PowerShell (Windows + VS Code) |

---

## 1. Project Overview

### What You Are Building

**A complete, self-contained application stack** — a reusable
module for the compute layer, a database, secrets managed
properly through Key Vault, and full observability — all in
one project, applied and destroyed as a single unit.

```
┌───────────────────────────────────────────────────────────────┐
│  Key Vault  (nct-dev-010-kv)                                  │
│  ├── secret: sql-admin-username                                │
│  ├── secret: sql-admin-password                                │
│  └── secret: app-secret-key                                    │
└───────────────────────┬───────────────────────────────────────┘
                        │ data sources read secrets
                        ▼
┌───────────────────────────────────────────────────────────────┐
│  Azure SQL Server + Database  (nct-dev-010-sql-srv)            │
│  Firewall rules created with for_each (map)                    │
└───────────────────────┬───────────────────────────────────────┘
                        │ connection string
                        ▼
┌───────────────────────────────────────────────────────────────┐
│  MODULE: nct_app_service                                       │
│  Called TWICE — once for "web" workload, once for "api"        │
│  Each call creates its own Plan + App Service                  │
└───────────────────────┬───────────────────────────────────────┘
                        │ diagnostic settings
                        ▼
┌───────────────────────────────────────────────────────────────┐
│  Log Analytics Workspace  (nct-dev-010-law)                   │
│  Monitor Action Group — dynamic email_receiver blocks          │
│  Metric Alerts — for_each on map(object), one per App Service  │
└───────────────────────────────────────────────────────────────┘
```

### Every Concept You Have Learned, Used Here

| Concept | From Project | Used In This Capstone For |
|---|---|---|
| Resource Group, tags, providers | NCT-001 | Foundation of every resource |
| Networking basics | NCT-002 | Not repeated here — kept focused on app/data/monitoring |
| Terraform Modules | NCT-003 | `nct_app_service` module, called twice |
| `locals {}` | NCT-003 | Common tags map |
| Key Vault + data sources | NCT-004 | SQL credentials, app secret |
| `depends_on` | NCT-004 | Data sources reading secrets |
| App Service + `app_settings` | NCT-005 | Web and API tier |
| `lifecycle` block | NCT-005 | Inside the module |
| SQL Server + Database | NCT-007 | The data tier |
| `for_each` with `map(string)` | NCT-007 | SQL firewall rules |
| `for_each` with `map(object)` | NCT-009 | Metric alerts |
| `dynamic` block | NCT-009 | Action group email receivers |
| Log Analytics + Alerts | NCT-009 | Full observability stack |

**Nothing new. This is entirely a synthesis project.**

### Why Two App Services from One Module

Real applications are rarely a single App Service. A common
pattern is a **web** tier (serves the frontend) and an **api**
tier (serves backend logic) — separate scaling, separate
concerns, same underlying resource type. This is the perfect
demonstration of why modules exist: write the App Service
logic once, call it twice with different inputs.

```hcl
module "web_app" {
  source   = "./modules/nct_app_service"
  workload = "web"
  # ...
}

module "api_app" {
  source   = "./modules/nct_app_service"
  workload = "api"
  # ...
}
```

### Scope Boundaries

- No networking layer this time (VNet/NSG) — keeps focus on
  app + data + monitoring integration, which is the actual
  lesson of this capstone
- No remote state chaining — single project, single state file
- `dev` environment only
- Module is local, called twice within the same project

---

## 2. Naming Conventions

### Full Resource Naming

| Resource | Name |
|---|---|
| Resource Group | `nct-dev-010-rg` |
| Key Vault | `nct-dev-010-kv` |
| SQL Server | `nct-dev-010-sql-srv-{initials}` |
| SQL Database | `nct-dev-010-app-db` |
| SQL Firewall Rules | via `for_each` map keys |
| App Service Plan (web) | `nct-dev-010-web-plan` |
| App Service (web) | `nct-dev-010-web-{initials}` |
| App Service Plan (api) | `nct-dev-010-api-plan` |
| App Service (api) | `nct-dev-010-api-{initials}` |
| Log Analytics Workspace | `nct-dev-010-law` |
| Monitor Action Group | `nct-dev-010-ag` |

### File Structure

```
nct-infra-010/
├── modules/
│   └── nct_app_service/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── providers.tf
├── backend.tf
├── data.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

> This is a hybrid of the flat structure (NCT-004 onward) and
> the modules pattern (NCT-003) — one root config that calls a
> local module twice. This is simpler than NCT-003's multi-folder
> environments setup because there is only one environment here.

### Remote State Key

```
nct-infra-010/dev/terraform.tfstate
```

### NexaCore Mandatory Tags

| Tag Key | Value |
|---|---|
| `Project` | `NCT-INFRA-010` |
| `Environment` | `dev` |
| `Owner` | `jane-doe` |
| `ManagedBy` | `terraform` |
| `CostCentre` | `CC-DEVOPS-007` |
| `Team` | `platform-engineering` |

---

## 3. Sample Data

```hcl
# terraform.tfvars

org_prefix           = "nct"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "nct-dev-010-rg"
key_vault_name       = "nct-dev-010-kv"
sql_server_name      = "nct-dev-010-sql-srv-jd"
sql_database_name    = "nct-dev-010-app-db"
owner_name           = "jane-doe"
cost_centre          = "CC-DEVOPS-007"
law_retention_days   = 30

sql_firewall_rules = {
  "devlaptop" = "YOUR_PUBLIC_IP"
  "cicdagent" = "20.30.40.50"
}

alert_email_receivers = {
  "tech-lead"     = "priya.menon@nexacore.com"
  "junior-devops" = "jane.doe@nexacore.com"
}

metric_alerts = {
  "web-cpu-high" = {
    description = "Web App CPU exceeded 80 percent"
    severity    = 2
    metric_name = "CpuPercentage"
    operator    = "GreaterThan"
    threshold   = 80
    aggregation = "Average"
  }
  "api-cpu-high" = {
    description = "API App CPU exceeded 80 percent"
    severity    = 2
    metric_name = "CpuPercentage"
    operator    = "GreaterThan"
    threshold   = 80
    aggregation = "Average"
  }
}
```

### Key Vault Secrets to Store

```
sql-admin-username → "nctdbadmin"
sql-admin-password → "NctCapstone@2024!"
app-secret-key     → "nct-capstone-secret-key"
```

---

## 4. Core Components to Build

### Component 1 — Resource Group, Key Vault, Secrets, Data Sources

**Files:** `main.tf` and `data.tf`

You have built this exact pattern four times now (NCT-004, 005,
007, 009). Build it entirely from memory:

- `azurerm_resource_group`
- `data "azurerm_client_config" "current"`
- `azurerm_key_vault` (with access policy for your identity)
- `azurerm_key_vault_secret` × 3
- `data "azurerm_key_vault_secret"` × 3, each with `depends_on`

No further guidance given for this component.

---

### Component 2 — SQL Server, Database, Firewall Rules

**File:** `main.tf`

Same pattern as NCT-INFRA-007. Build from memory:

- `azurerm_mssql_server` — credentials from Key Vault data sources
- `azurerm_mssql_database` — `sku_name = "Basic"`, `max_size_gb = 2`
- `azurerm_mssql_firewall_rule` with `for_each = var.sql_firewall_rules`

No further guidance given for this component.

---

### Component 3 — Build the Reusable Module: `nct_app_service`

**Folder:** `modules/nct_app_service/`

This is the one part of the capstone that requires fresh thinking
— you are designing the module's interface (its variables) so it
can serve BOTH the web tier and the api tier cleanly.

**`modules/nct_app_service/variables.tf` — you must define:**

```
org_prefix       string
environment      string
azure_location   string
workload         string    # "web" or "api" — used in naming
resource_group_name  string
resource_group_location string
sql_connection_string   string   # passed in, sensitive
app_secret_key           string   # passed in, sensitive
tags             map(string)
```

**`modules/nct_app_service/main.tf` — you must define:**

- `azurerm_service_plan`
  - `name` built using `var.workload` → e.g. `"nct-dev-010-web-plan"`
  - `sku_name = "F1"`
- `azurerm_linux_web_app`
  - `name` built using `var.workload` → e.g. `"nct-dev-010-web-jd"`
  - `app_settings` includes `DATABASE_URL = var.sql_connection_string`
    and `APP_SECRET_KEY = var.app_secret_key`
  - `site_config` with `always_on = false`, Python 3.11
  - `lifecycle { ignore_changes = [app_settings["WEBSITE_RUN_FROM_PACKAGE"]] }`

**`modules/nct_app_service/outputs.tf` — you must define:**

```
app_service_id      ← the resource ID
app_service_name    ← the actual name
app_service_url     ← https:// url
```

> Remember: the module has NO provider block, NO terraform block.
> It inherits everything from the root config that calls it.

---

### Component 4 — Call the Module Twice

**File:** `main.tf` (root)

```hcl
module "web_app" {
  source = "./modules/nct_app_service"

  org_prefix              = var.org_prefix
  environment             = var.environment
  azure_location          = var.azure_location
  workload                = "web"
  resource_group_name     = azurerm_resource_group.rg.name
  resource_group_location = azurerm_resource_group.rg.location
  sql_connection_string   = local.sql_connection_string
  app_secret_key          = data.azurerm_key_vault_secret.app_secret_key.value
  tags                    = local.common_tags
}

module "api_app" {
  source = "./modules/nct_app_service"

  org_prefix              = var.org_prefix
  environment             = var.environment
  azure_location          = var.azure_location
  workload                = "api"
  resource_group_name     = azurerm_resource_group.rg.name
  resource_group_location = azurerm_resource_group.rg.location
  sql_connection_string   = local.sql_connection_string
  app_secret_key          = data.azurerm_key_vault_secret.app_secret_key.value
  tags                    = local.common_tags
}
```

**Build the `sql_connection_string` local yourself** using the
same `format()` pattern from NCT-INFRA-007 — combining the SQL
Server's `fully_qualified_domain_name`, the database name, and
the Key Vault credentials.

---

### Component 5 — Log Analytics, Action Group, Diagnostic Settings, Alerts

**File:** `main.tf`

Same pattern as your rewritten NCT-INFRA-009 — fully self-contained,
no data sources needed since everything is in this same config.

**You must define:**

- `azurerm_log_analytics_workspace`
- `azurerm_monitor_action_group` with `dynamic "email_receiver"`
  using `var.alert_email_receivers`
- `azurerm_monitor_diagnostic_setting` × 2 — one targeting
  `module.web_app.app_service_id`, one targeting
  `module.api_app.app_service_id`
- `azurerm_monitor_metric_alert` with `for_each = var.metric_alerts`
  — `scopes` should include BOTH `module.web_app.app_service_id`
  and `module.api_app.app_service_id` in the same alert (an alert
  can watch multiple resources at once if they are the same
  resource type)

> This last point is new in application, though not in concept:
> the `scopes` argument accepts a LIST. You have only ever put
> one resource ID in it before. Here you put two:
> ```hcl
> scopes = [
>   module.web_app.app_service_id,
>   module.api_app.app_service_id
> ]
> ```
> One alert rule, watching two App Services simultaneously.

---

### Component 6 — Root Variables and Outputs

**Files:** `variables.tf` and `outputs.tf`

**Variables** — same list as NCT-INFRA-009 plus SQL-related ones
from NCT-INFRA-007. Combine what you already know. No new syntax.

**Outputs to expose:**

```
web_app_url            ← module.web_app.app_service_url
api_app_url            ← module.api_app.app_service_url
sql_server_fqdn        ← the SQL server's FQDN
workspace_name          ← Log Analytics workspace name
alerts_created          ← keys() of the metric alerts
resource_group_name    ← the RG name
```

---

## 5. Hints & Pitfalls

### Hint 1 — Passing Sensitive Values Into a Module

When you pass `sql_connection_string` and `app_secret_key` into
the module, Terraform will mark the module's inputs as sensitive
automatically because they trace back to sensitive data sources.
This means `terraform plan` output for the module call will show
`(sensitive value)` for those lines — this is expected and correct,
not an error.

---

### Hint 2 — A Module Called Twice Needs Genuinely Different Names

If both module calls produce the exact same resource name (because
you forgot to use `var.workload` in the naming logic inside the
module), the second `terraform apply` will fail with a naming
conflict — Azure won't let you create two App Services with the
identical name in the same resource group.

Double check inside `modules/nct_app_service/main.tf` that every
name construction actually includes `var.workload`:

```hcl
name = "${var.org_prefix}-${var.environment}-010-${var.workload}"
# NOT:
name = "${var.org_prefix}-${var.environment}-010"    # ← missing workload, will collide
```

---

### Hint 3 — One Metric Alert Watching Two Resources Needs Matching Metric Names

The `scopes` list lets one alert watch multiple resources, but
only if they are the SAME resource type with the SAME available
metrics. Both `web_app` and `api_app` are `azurerm_linux_web_app`
resources, so `CpuPercentage` is valid for both. If you tried to
mix an App Service and a SQL Database in the same `scopes` list,
the metric names wouldn't line up and the alert would fail to
apply.

---

## 6. Workflow (PowerShell — Windows + VS Code)

```powershell
cd C:\Projects\nct-infra-010

terraform init
terraform validate
terraform fmt
terraform plan
# Expected — a large plan. Read it in sections:
# - RG, Key Vault, 3 secrets, 3 data sources
# - SQL Server, Database, 2 firewall rules
# - module.web_app: plan (service plan + web app)
# - module.api_app: plan (service plan + web app)
# - Log Analytics Workspace
# - Action Group with 2 email_receiver blocks
# - 2 diagnostic settings
# - 2 metric alerts (each watching BOTH app services)

terraform apply
# Type: yes
# This is your longest apply yet — 6-10 minutes. Be patient.

# Verify both app URLs
terraform output web_app_url
terraform output api_app_url

# Verify SQL
terraform output sql_server_fqdn
az sql server firewall-rule list `
  --server nct-dev-010-sql-srv-jd `
  --resource-group nct-dev-010-rg `
  --output table

# Verify monitoring
terraform output alerts_created
az monitor metrics alert list `
  --resource-group nct-dev-010-rg `
  --output table

# Verify the module was called twice correctly
az webapp list `
  --resource-group nct-dev-010-rg `
  --query "[].{Name:name}" `
  --output table
# Expected: two App Services listed — one "web", one "api"

# Destroy when done
terraform destroy
# Type: yes

# Purge Key Vault
az keyvault purge `
  --name nct-dev-010-kv `
  --location "East US"
```

---

## 7. NexaCore Code Review Checklist

```
[ ] Key Vault + 3 secrets + 3 data sources — built from memory, no reference needed
[ ] SQL Server + Database + firewall rules via for_each — built from memory
[ ] modules/nct_app_service/ has NO provider block, NO terraform block
[ ] Module naming logic includes var.workload — web and api get distinct names
[ ] Module called twice in root main.tf with different workload values
[ ] sql_connection_string and app_secret_key passed into both module calls
[ ] Log Analytics Workspace, Action Group, dynamic email_receiver — self-contained
[ ] 2 diagnostic settings, one per App Service, using module outputs directly
[ ] Metric alerts use scopes = [module.web_app.id, module.api_app.id]
[ ] All resources tagged with all six org tags
[ ] terraform plan shows 2 distinct App Services under separate module calls
[ ] Both web_app_url and api_app_url resolve to different working URLs
[ ] terraform destroy removes everything cleanly
[ ] Key Vault purged after destroy
```

---

## 8. What You Have Achieved

```
NCT-INFRA-001   Storage, provider, basic resources
NCT-INFRA-002   Networking, NSG, VM, dependency chains
NCT-INFRA-003   Modules, remote state, multi-environment
NCT-INFRA-004   Key Vault, data sources, sensitive values
NCT-INFRA-005   App Service, app_settings, lifecycle
NCT-INFRA-006   Container Registry, remote state chaining
NCT-INFRA-007   SQL Database, for_each (map)
NCT-INFRA-008   Function App, Storage Queue, for_each (set)
NCT-INFRA-009   Monitor, Log Analytics, dynamic blocks
NCT-INFRA-010   Full synthesis — modules + data + compute + observability
                ↑ YOU ARE HERE — Series Complete
```

You started this series 25+ days ago building a single Storage
Account. You just built a two-tier application with its own
reusable module, a managed database, properly handled secrets,
and full observability — in one coherent project.

That is not a beginner portfolio anymore.

---

*NexaCore Technologies — Platform Engineering | Internal Training Material*
*NCT-INFRA-010 | Capstone | Windows + VS Code + PowerShell*
*Series Complete — Do not distribute outside the DevOps team*
