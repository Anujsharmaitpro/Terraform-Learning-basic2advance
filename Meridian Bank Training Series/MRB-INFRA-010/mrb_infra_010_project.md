# Meridian Bank — Cloud Infrastructure Training Series
## Capstone — Complete Bank-Grade Architecture
**Project Code:** `MRB-INFRA-010` | **Level:** Capstone | **Series Complete**
**Environment:** Windows + VS Code + PowerShell | Fully self-contained

---

> ## ⚠️ COST WARNING — Same as MRB-009
> Includes an Application Gateway (~$0.36/hr fixed). Single 2-3
> hour session. Apply → verify → destroy. Do not leave running.

---

> **From your Team Lead:** Every piece of this ticket is something
> you've already built individually. Nothing here is new syntax —
> the skill being tested is assembly. One thing to get exactly
> right: real App-to-App privacy on Azure requires TWO mechanisms
> together, not one — VNet Integration handles outbound, a
> Private Endpoint handles inbound. Miss either half and the App
> Tier ends up either fully public or fully unreachable, never
> actually private. — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | Fully standalone

---

## 1. Overview — The Complete Architecture

```
Internet
   │
   ▼
Application Gateway + WAF (mrb-dev-010-agw)          [from MRB-009]
   │
   ▼
Web Tier — App Service (public, VNet-integrated)      [from MRB-006]
   │
   ▼
App Tier — App Service
   OUTBOUND: VNet Integration into app-subnet          [from MRB-006]
   INBOUND:  Private Endpoint into data-subnet          [NEW — see below]
   public_network_access_enabled = false
   System-Assigned Managed Identity                    [from MRB-002]
   │
   ▼
Data Tier — Azure SQL via Private Endpoint              [from MRB-007]
   │
   ▲
Azure Policy — enforces DataClassification tag           [from MRB-008]
   on every resource in this Resource Group
```

### The One Concept to Understand Before Building

Azure App Service networking splits inbound and outbound traffic
into two completely separate mechanisms — this trips up most
people building multi-tier apps for the first time, so read this
carefully before writing any code:

```
VNet Integration (swift_connection)
  → OUTBOUND only. Lets the App Service reach INTO the VNet.
  → Does NOT make the App Service reachable FROM the VNet.

Private Endpoint
  → INBOUND only. Gives the App Service a private IP inside
    the VNet, reachable from other things in that VNet.
  → Does NOT let the App Service reach OUT anywhere new.
```

The App Tier needs BOTH: VNet Integration so it can reach the
database, and a Private Endpoint so the Web Tier can reach it.
Azure SQL is simpler than App Service here — it has one access
mode (public on/off) and no separate outbound concept, so a
Private Endpoint alone was always sufficient for it.

### Every Concept You Have Learned, Used Here

| Concept | From Project | Used In This Capstone For |
|---|---|---|
| Resource Group, tags, providers | MRB-001 | Foundation of every resource |
| Key Vault + RBAC | MRB-002/003 | SQL credential storage |
| Managed Identity | MRB-002 | App Tier's own Azure AD identity |
| VNet Integration + delegation | MRB-006 | Web + App Tier outbound networking |
| Private Endpoint + DNS chain | MRB-007 | SQL Server's inbound access, AND (new use) App Tier's inbound access |
| Azure Policy | MRB-008 | Tag enforcement across the whole RG |
| Application Gateway + WAF | MRB-009 | Public entry point |

**Nothing new. This is entirely a synthesis project — with one
piece (App Tier's Private Endpoint) applying a pattern you already
know from MRB-007's SQL work to a second resource type.**

### Scope Boundaries

- Single `dev` environment
- No remote state chaining — one project, one state file

---

## 2. Naming Conventions

### Full Resource Naming

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-010-rg` |
| VNet | `mrb-dev-010-vnet` |
| Subnets | `agw-subnet` (10.0.1.0/24), `web-subnet` (10.0.2.0/24), `app-subnet` (10.0.3.0/24), `data-subnet` (10.0.4.0/24) |
| Application Gateway | `mrb-dev-010-agw` |
| Key Vault | `mrb-dev-010-kv` |
| SQL Server / DB | `mrb-dev-010-sql-jd` / `mrb-dev-010-app-db` |
| App Service Plan | `mrb-dev-010-plan` |
| Web / App Tier | `mrb-dev-010-web-jd` / `mrb-dev-010-app-jd` |
| SQL Private Endpoint | `mrb-dev-010-sql-pe` |
| App Tier Private Endpoint | `mrb-dev-010-app-pe` (NEW) |

All 8 MRB tags. `DataClassification = "confidential"`.

### Sample Data

```hcl
# terraform.tfvars
org_prefix           = "mrb"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "mrb-dev-010-rg"
owner_name           = "alex-morgan"
cost_centre          = "CC-CLOUD-001"
data_classification  = "confidential"
compliance_scope     = "internal-audit"
```

---

## 3. Build Order

```
1. Resource Group + Policy Definition + Assignment   [MRB-008 pattern]
2. VNet + 4 subnets (agw, web, app, data)             [MRB-006/007/009 pattern]
3. Key Vault (RBAC) + SQL secrets                     [MRB-002/003 pattern]
4. SQL Server (public access disabled) + Database     [MRB-007 pattern]
5. SQL Private Endpoint + Private DNS Zone + A Record [MRB-007 pattern]
6. App Service Plan (B1) + Web/App Tiers + VNet Integration [MRB-006 pattern]
7. App Tier: System-Assigned Managed Identity + role assignment [MRB-002/003]
8. NEW → App Tier Private Endpoint + Private DNS Zone + A Record
9. Application code (Web Tier calls App Tier, App Tier queries SQL)
10. Application Gateway + WAF, backend pool → Web Tier [MRB-009 pattern]
```

---

## 4. Core Components — Assembly Instructions

### Component 1 — Policy (from MRB-008)
Build the `azurerm_policy_definition` and
`azurerm_resource_group_policy_assignment` exactly as in MRB-008,
scoped to this project's Resource Group. No new guidance.

### Component 2 — Networking (from MRB-006/007/009)
Four subnets this time:
- `agw-subnet` — no delegation
- `web-subnet` — delegation block for `Microsoft.Web/serverFarms`
- `app-subnet` — delegation block + NSG allowing only from web-subnet
- `data-subnet` — `private_endpoint_network_policies_enabled = false`

> **Note the change from your original attempt:** `data-subnet`
> will now host TWO Private Endpoints (SQL's, and the App Tier's) —
> a subnet can host multiple Private Endpoints for different
> resource types, so no additional subnet is needed for this fix.

### Component 3 — Key Vault + Secrets (from MRB-002/003)
RBAC authorization model. Two secrets: `sql-admin-username`,
`sql-admin-password`. Grant yourself `"Key Vault Secrets Officer"`.

### Component 4 — SQL + Private Endpoint (from MRB-007)
`public_network_access_enabled = false` on the SQL Server. No
firewall rules. Private Endpoint targeting `data-subnet`,
`subresource_names = ["sqlServer"]`. Private DNS Zone
(`privatelink.database.windows.net`) + VNet Link + A Record.

### Component 5 — Web + App Tier (from MRB-006)
`B1` App Service Plan (shared by both). Web Tier: standard, public,
VNet-integrated into `web-subnet`. App Tier:
`public_network_access_enabled = false`,
`identity { type = "SystemAssigned" }`, VNet-integrated into
`app-subnet`.

### Component 6 — Managed Identity → Key Vault (from MRB-002/003)

```hcl
resource "azurerm_role_assignment" "app_tier_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id           = azurerm_linux_web_app.app_tier.identity[0].principal_id
}
```

### Component 7 — App Tier Private Endpoint (NEW — This Is the Fix)

This is the piece that was missing from the original build, and
it's what actually makes the App Tier reachable from the Web Tier.
Without it, `public_network_access_enabled = false` combined with
VNet Integration alone leaves the App Tier with no reachable path
at all — not private, just unreachable.

**You must define, following the exact pattern from Component 4's
SQL Private Endpoint, but targeting the App Tier instead:**

```
azurerm_private_endpoint
  - subnet_id = data-subnet (reuse the same subnet as SQL's PE)
  - private_service_connection targeting azurerm_linux_web_app.app_tier.id
  - subresource_names = ["sites"]    ← App Service's PE subresource
                                        name (SQL used "sqlServer")

azurerm_private_dns_zone
  - name = "privatelink.azurewebsites.net"    ← fixed, Azure-mandated
                                                  name, different from
                                                  SQL's zone name

azurerm_private_dns_zone_virtual_network_link
  - links the new zone to the same VNet

azurerm_private_dns_a_record
  - name = the App Tier's own name
  - records = [the Private Endpoint's private_ip_address]
```

> Notice this is the SAME four-piece pattern (endpoint, zone,
> link, record) you already built for SQL in MRB-007 — only the
> target resource, the subresource name, and the DNS zone name
> change. If you can build SQL's Private Endpoint from memory,
> you can build this one the same way.

### Component 8 — Application Gateway (from MRB-009)
Exactly as MRB-009. Dedicated `agw-subnet`, `Standard_v2` SKU,
capacity 1, backend pool using
`fqdns = [azurerm_linux_web_app.web_tier.default_hostname]`,
`waf_configuration.firewall_mode = "Detection"`.

### Component 9 — Application Code (New Guidance)

**App Tier** (`app-tier/app.py`) — a Flask app that connects to
SQL using `pyodbc` and returns a JSON response with the query
result. Same connection string pattern from MRB-007/NCT-007's
`format()` approach, reused here as an f-string.

**Web Tier** (`web-tier/app.py`) — a Flask app that calls the App
Tier's URL (from `app_settings.APP_TIER_URL`) and returns its own
JSON, nesting the App Tier's response inside it.

Deploy both after `terraform apply` completes:
```powershell
az webapp deploy --resource-group mrb-dev-010-rg --name mrb-dev-010-app-jd --src-path app-tier.zip --type zip
az webapp deploy --resource-group mrb-dev-010-rg --name mrb-dev-010-web-jd --src-path web-tier.zip --type zip
```

---

## 5. Hints

**Hint 1 — Two Private Endpoints on one subnet is correct, not a
mistake:** `data-subnet` now hosts both SQL's and the App Tier's
Private Endpoints. This is standard practice — a subnet isn't
"used up" by one Private Endpoint.

**Hint 2 — `subresource_names` differs by resource type, always
check which one you need:** SQL uses `["sqlServer"]`, App Service
uses `["sites"]`. Get this wrong and the Private Endpoint will
apply but connect to the wrong capability of the resource.

**Hint 3 — This is the longest apply in the series, 20-25+
minutes:** App Gateway alone takes 15-20 minutes; two Private
Endpoints with their DNS chains add more. Budget accordingly.

**Hint 4 — Test the negative case, not just the positive one:**
after deploying, confirm your OWN laptop cannot reach
`https://mrb-dev-010-app-jd.azurewebsites.net` directly. If it
can, the Private Endpoint or `public_network_access_enabled`
setting isn't actually taking effect yet — don't skip this check,
it's the one that would have caught the original architecture gap.

---

## 6. Workflow (PowerShell)

```powershell
cd C:\Projects\mrb-infra-010

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
# 20-25+ minutes

terraform state list

# Deploy application code
Compress-Archive -Path .\app-tier\* -DestinationPath app-tier.zip -Force
Compress-Archive -Path .\web-tier\* -DestinationPath web-tier.zip -Force
az webapp deploy --resource-group mrb-dev-010-rg --name mrb-dev-010-app-jd --src-path app-tier.zip --type zip
az webapp deploy --resource-group mrb-dev-010-rg --name mrb-dev-010-web-jd --src-path web-tier.zip --type zip

# Prove the App Tier is genuinely private, not just broken
Invoke-WebRequest "https://mrb-dev-010-app-jd.azurewebsites.net" -TimeoutSec 5
# Expected: FAILS from your laptop

# Verify SQL has no public access
az sql server show --name mrb-dev-010-sql-jd --resource-group mrb-dev-010-rg `
  --query "publicNetworkAccess" --output tsv
# Expected: Disabled

# Verify Managed Identity role assignment
az role assignment list --assignee (terraform output -raw app_tier_managed_identity_id) --output table

# Verify policy compliance
az policy state list --resource-group mrb-dev-010-rg `
  --query "[].{Resource:resourceId, Compliance:complianceState}" --output table

# THE ACTUAL TEST — through the Application Gateway
$agwIp = terraform output -raw agw_public_ip
Start-Process "http://$agwIp"
# Expected: Web Tier's JSON, with App Tier's nested reply including
# real database content — the full chain, working, genuinely private

# ── DESTROY PROMPTLY ──────────────────────────
terraform destroy
az keyvault purge --name mrb-dev-010-kv --location "East US"
```

---

## 7. Final Checklist

```
[ ] Policy definition + assignment active on the Resource Group
[ ] Four subnets, correct non-overlapping CIDR ranges
[ ] Key Vault: RBAC model, no access_policy blocks anywhere
[ ] SQL: public_network_access_enabled = false, NO firewall rules
[ ] SQL Private Endpoint + DNS Zone + Link + A Record present
[ ] Web Tier: public, VNet-integrated
[ ] App Tier: VNet Integration (outbound) AND Private Endpoint (inbound) BOTH present
[ ] App Tier: public_network_access_enabled = false, System-Assigned identity
[ ] App Tier Private DNS Zone (privatelink.azurewebsites.net) + Link + A Record present
[ ] Role assignment grants App Tier's identity "Key Vault Secrets User"
[ ] App Gateway: WAF Detection mode, backend pool → Web Tier's hostname
[ ] terraform state list shows all resources present
[ ] Direct request to App Tier's public hostname FAILS from your laptop
[ ] Public URL through App Gateway shows the full working chain
[ ] Policy compliance confirmed via CLI
[ ] terraform destroy + Key Vault purge completed PROMPTLY
```

---

## 8. Cost

```
Standard_v2 App Gateway    ~$0.36/hr
2x Private Endpoints         ~$0.02/hr combined
B1 App Service Plan            ~$0.018/hr
SQL Basic                        ~$5/month if left running
──────────────────────────────────────────────
2-3 hour focused session:        ~$1.20-1.35
```

---

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
*MRB-INFRA-010 | Series Complete | Corrected*
