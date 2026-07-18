# Meridian Bank — Cloud Infrastructure Training Series
## Full Capstone — Complete Bank-Grade Architecture
**Project Code:** `MRB-INFRA-010` | **Level:** Capstone | **Series Complete**
**Environment:** Windows + VS Code + PowerShell | Fully self-contained

---

> ## ⚠️ COST WARNING — SAME AS MRB-009
> This capstone includes an Application Gateway (~$0.36/hr fixed).
> Single 2-3 hour session. Apply → verify → destroy. Do not leave running.

---

> **From your Team Lead:** This is it — the project you put in a
> portfolio. Every piece is something you've already built
> individually across nine tickets. Nothing here is new syntax.
> The only new skill is assembling all of it correctly, in the
> right order, with nothing missed. That is, genuinely, most of
> what real infrastructure work actually is. — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | Fully standalone — nothing
external required

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
App Tier — App Service (private, VNet-integrated,      [from MRB-006]
           public_network_access_enabled = false)
   │
   ▼
Data Tier — Azure SQL via Private Endpoint             [from MRB-007]
           (no public access, Private DNS resolution)
   │
   ▲
Azure Policy — enforces DataClassification tag         [from MRB-008]
   on every resource in this Resource Group,
   including everything above
   │
   ▲
Managed Identity — App Tier reads SQL credentials       [from MRB-002/003]
   from Key Vault using its own Azure AD identity,
   zero stored passwords
```

**Every arrow in this diagram is a project you've already
completed individually.** This ticket is pure synthesis — no new
Terraform resource types, no new concepts. The skill being tested
is assembly and correctness under complexity.

### What's Explicitly NOT Included (Scope Discipline)

- No Load Balancer (MRB-004) or Traffic Manager (MRB-005) — App
  Gateway already handles traffic distribution at Layer 7, adding
  either would be redundant for this architecture
- No multiple environments (dev/staging) — single `dev` environment,
  consistent with the whole series

---

## 2. Best Practices Applied (Full Set)

```
.gitignore          → same standard set, no changes
README.md           → template below
validation blocks   → on environment and data_classification
locals.name_prefix  → computed once, used for every resource name
plan -out=tfplan     → workflow uses saved-plan pattern throughout
terraform state list → included as a verification step
```

### README.md Template

```markdown
# MRB-INFRA-010 — Full Capstone

## ⚠️ COST WARNING
Includes Application Gateway (~$0.36/hr). Single-session lab.

## What This Provisions
Complete 3-tier bank-grade architecture: App Gateway + WAF → Web
Tier → App Tier (private) → SQL via Private Endpoint. Managed
Identity throughout, no stored credentials. Azure Policy enforces
tag compliance on the entire Resource Group.

## Prerequisites
- Azure CLI logged in
- Terraform v1.6+
- 2-3 hour uninterrupted session

## How to Run
​```powershell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
​```
Expect 20-25 minutes total apply time (App Gateway alone is 15-20 min).

## How to Destroy — PROMPTLY
​```powershell
terraform destroy
​```

## Architecture Decisions
- WAF in Detection mode (not Prevention) — safe for learning
- App Tier has NO public access — proven via failed direct request test
- SQL has NO public access — Private Endpoint + Private DNS only
- All identity flows use Managed Identity — zero passwords in config

## Estimated Cost
~$0.40-0.45/hr running. 3-hour session: ~$1.30.
```

---

## 3. Naming + Tags

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
| Policy Definition | `mrb-require-data-classification` |

All 8 MRB tags. `DataClassification = "confidential"` (this
architecture handles application data end-to-end — the highest
classification used in the series so far, aside from `restricted`
which is intentionally never used in these labs).

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

## 4. Build Order (This Matters More Than Any Previous Project)

Unlike earlier projects where attribute references handled
ordering invisibly, a project this size benefits from you
understanding the LOGICAL build order, even though Terraform
still resolves it automatically:

```
1. Resource Group + Policy Definition + Assignment   (MRB-008 pattern)
2. VNet + 4 subnets (agw, web, app, data)             (MRB-006/007/009 pattern)
3. Key Vault (RBAC) + SQL secrets                     (MRB-002/003 pattern)
4. SQL Server (public access disabled) + Database     (MRB-007 pattern)
5. Private Endpoint + Private DNS Zone + A Record      (MRB-007 pattern)
6. App Service Plan (B1 — VNet integration requires it)
7. Web Tier App Service + VNet Integration             (MRB-006 pattern)
8. App Tier App Service + VNet Integration              (MRB-006 pattern)
   + System-Assigned Managed Identity                  (MRB-002 pattern)
9. Role Assignment: App Tier identity → Key Vault reader (MRB-002/003 pattern)
10. App Gateway + WAF, backend pool → Web Tier          (MRB-009 pattern)
```

Build the `.tf` files in roughly this order — it will make
debugging far easier than jumping around, even though Terraform
doesn't strictly require this sequence at apply time.

---

## 5. Core Components — Assembly Instructions Only

Every piece below is something you've built at least once already.
Guidance here is deliberately light — pointing you to which
previous project to reference, not re-explaining the resource.

### Component 1 — Policy (from MRB-008)
Build the `azurerm_policy_definition` and
`azurerm_resource_group_policy_assignment` exactly as in MRB-008,
scoped to this project's Resource Group.

### Component 2 — Networking (from MRB-006/007/009)
One VNet, FOUR subnets this time:
- `agw-subnet` — no delegation, App Gateway needs its own dedicated subnet
- `web-subnet` — delegation block for `Microsoft.Web/serverFarms`
- `app-subnet` — delegation block + NSG allowing only from web-subnet
- `data-subnet` — `private_endpoint_network_policies_enabled = false`

### Component 3 — Key Vault + Secrets (from MRB-002/003)
RBAC authorization model. Two secrets: `sql-admin-username`,
`sql-admin-password`. Grant yourself `"Key Vault Secrets Officer"`.

### Component 4 — SQL + Private Endpoint (from MRB-007)
`public_network_access_enabled = false` on the SQL Server. No
firewall rules. Private Endpoint targeting `data-subnet`. Private
DNS Zone (`privatelink.database.windows.net`) + VNet Link + A Record.

### Component 5 — Web + App Tier (from MRB-006)
`B1` App Service Plan (shared by both). Web Tier: standard, public.
App Tier: `public_network_access_enabled = false`,
`identity { type = "SystemAssigned" }`. Both VNet-integrated into
their respective subnets.

### Component 6 — Managed Identity → Key Vault (from MRB-002/003)

```hcl
resource "azurerm_role_assignment" "app_tier_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id          = azurerm_linux_web_app.app_tier.identity[0].principal_id
}
```

The App Tier's `app_settings` should include the SQL connection
string built with `format()`, using the SQL Server's
`fully_qualified_domain_name` (which resolves privately thanks to
the DNS setup in Component 4) — no Key Vault data source needed
for the connection string itself in this design, since the App
Tier's own identity is what ultimately matters for the access
pattern being demonstrated.

### Component 7 — Application Gateway (from MRB-009)
Exactly as MRB-009, with one difference: `backend_address_pool`
`fqdns` now points to `azurerm_linux_web_app.web_tier.default_hostname`
(the Web Tier from THIS project, not a standalone test app).
`waf_configuration.firewall_mode = "Detection"`.

---

## 6. Hints — Capstone-Specific

**Hint 1 — Four subnets means four sets of address space to keep
straight:** write them down before you start coding:
```
agw-subnet:  10.0.1.0/24
web-subnet:  10.0.2.0/24
app-subnet:  10.0.3.0/24
data-subnet: 10.0.4.0/24
```
A single overlapping CIDR range breaks the whole VNet — Terraform
will reject it at apply time with a clear address-space conflict
error, but it's easier to just get it right the first time.

**Hint 2 — This is the longest apply in the entire series, by far:**
20-25 minutes total, dominated by the App Gateway (15-20 min alone).
Budget your session time accordingly. This is not a project to
start with 30 minutes before a meeting.

**Hint 3 — If something fails partway through a 20-minute apply,
DON'T immediately re-run `terraform apply` blindly:** run
`terraform plan` first to see exactly what's left to reconcile.
Complex multi-resource applies sometimes have partial failures
(usually propagation-delay related, per Hint 2 in MRB-002/008) —
`terraform plan` shows you precisely what state you're actually in
before you commit to another long apply.

---

## 7. Workflow (PowerShell — Full Session)

```powershell
cd C:\Projects\mrb-infra-010

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan       # this will be a LONG plan — read it in sections
terraform apply tfplan
# 20-25 minutes — do not interrupt

terraform state list
# Should show ~20+ resources — this is your biggest state file yet

# Verify the full chain end to end
$agwIp = terraform output -raw agw_public_ip
Start-Process "http://$agwIp"
# Should route: Internet → App Gateway → Web Tier

# Verify App Tier is NOT directly reachable
$appHost = terraform output -raw app_tier_hostname
Invoke-WebRequest "https://$appHost" -TimeoutSec 5
# Expected: fails/times out

# Verify SQL has no public access
az sql server show --name mrb-dev-010-sql-jd --resource-group mrb-dev-010-rg `
  --query "publicNetworkAccess" --output tsv
# Expected: Disabled

# Verify Managed Identity role assignment
az role assignment list `
  --assignee (terraform output -raw app_tier_managed_identity_id) `
  --output table
# Expected: "Key Vault Secrets User"

# Verify policy compliance across everything
az policy state list --resource-group mrb-dev-010-rg `
  --query "[].{Resource:resourceId, Compliance:complianceState}" `
  --output table
# Expected: all Compliant

# ── DESTROY PROMPTLY ──────────────────────────
terraform destroy
az keyvault purge --name mrb-dev-010-kv --location "East US"
```

---

## 8. Final Checklist — The Whole Series, In One Project

```
[ ] Policy definition + assignment active on the Resource Group
[ ] Four subnets, correct non-overlapping CIDR ranges
[ ] Key Vault: RBAC model, no access_policy blocks anywhere
[ ] SQL: public_network_access_enabled = false, NO firewall rules
[ ] Private Endpoint + DNS Zone + VNet Link + A Record all present
[ ] Web Tier: public, VNet-integrated
[ ] App Tier: public_network_access_enabled = false, System-Assigned identity
[ ] Role assignment grants App Tier's identity "Key Vault Secrets User"
[ ] App Gateway: WAF Detection mode, backend pool → Web Tier's hostname
[ ] terraform state list shows all ~20+ resources present
[ ] Public URL through App Gateway works
[ ] Direct App Tier request fails (proves isolation)
[ ] SQL confirmed publicly inaccessible via CLI
[ ] Policy compliance confirmed via CLI
[ ] terraform destroy + Key Vault purge completed PROMPTLY
```

---

## 9. What You Have Built — Full Series Retrospective

```
MRB-001   Secure Storage + Compliance Baseline
MRB-002   Azure AD + Managed Identity (VM)
MRB-003   Managed Identity (App Service) + Key Vault references
MRB-004   Private Networking + Standard Load Balancer
MRB-005   Traffic Manager + Routing Concepts
MRB-006   Multi-Tier Part 1 — Web + App Tier, VNet Integration
MRB-007   Multi-Tier Part 2 — Data Tier via Private Endpoint
MRB-008   Azure Policy — Automated Compliance Enforcement
MRB-009   Application Gateway + WAF
MRB-010   Full Capstone — Everything, Assembled Correctly
```

Combined with the ten-project NexaCore series before it, you have
now built and destroyed **20 complete Terraform projects** —
covering compute, storage, networking, identity, secrets, policy,
monitoring, serverless, and multi-tier architecture — entirely
self-funded, entirely self-contained, no project ever depending
on another being alive.

That is not a beginner's body of work. That is a portfolio.

---

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
*MRB-INFRA-010 | Series Complete*
