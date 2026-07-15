# NexaCore Technologies — Internal DevOps Training Project
## Deploy a Web Application with Azure App Service + Terraform
**Project Code:** `NCT-INFRA-005` | **Track:** Junior DevOps Engineer | **Level:** Intermediate
**Environment:** Windows + VS Code + PowerShell

---

> **A message from your Tech Lead:**
> Good work clearing the Key Vault ticket. I know data sources felt
> awkward at first — they always do. You will use them constantly
> from this point forward so that discomfort will fade quickly.
>
> This next ticket is a milestone. Up until now you have been
> provisioning infrastructure — networks, VMs, storage. That is the
> foundation layer. This ticket moves us up one layer: deploying an
> actual web application on Azure App Service.
>
> The NexaCore internal tools team has a small Python web app they
> want hosted in our dev environment. Your job is to provision the
> hosting platform using Terraform, wire in the environment variables
> the app needs, and pull the sensitive config from Key Vault.
> You will connect everything you have learned so far.
>
> Read the full spec. This one has more pieces than any previous ticket.
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
| **Ticket ID** | `NCT-INFRA-005` |
| **Depends On** | NCT-INFRA-004 (Key Vault + data sources must be understood) |
| **Environment** | `dev` only |
| **Cloud** | Microsoft Azure |
| **IaC Tool** | Terraform `v1.6+` |
| **Azure Region** | `East US` |
| **Cost Centre** | `CC-DEVOPS-007` |
| **Terminal** | PowerShell (Windows + VS Code) |

---

## 1. Project Overview

### What You're Building

**An Azure App Service hosting platform for NexaCore's internal Python
web application, with environment variables pulled securely from
Azure Key Vault — all provisioned with Terraform.**

```
┌──────────────────────────────────────────────────────────────┐
│  Azure Key Vault (nct-dev-app-kv)                            │
│                                                              │
│  Secret: app-secret-key   → "nct-super-secret-key-2024"     │
│  Secret: db-connection    → "Server=myserver;Db=mydb;..."   │
│  Secret: app-environment  → "development"                    │
└─────────────────────┬────────────────────────────────────────┘
                      │ data sources read secrets
                      ▼
┌──────────────────────────────────────────────────────────────┐
│  App Service Plan (nct-dev-app-plan)                         │
│  SKU: Free (F1) — no cost for learning                       │
│                                                              │
│  └── App Service (nct-dev-app-web)                           │
│       Runtime: Python 3.11                                   │
│       App Settings (env vars from Key Vault):                │
│         SECRET_KEY      = (from Key Vault)                   │
│         DATABASE_URL    = (from Key Vault)                   │
│         APP_ENV         = (from Key Vault)                   │
│         WEBSITE_RUN_FROM_PACKAGE = "1"                       │
└──────────────────────────────────────────────────────────────┘
```

### What Is New in This Project

| Concept | What You Will Learn |
|---|---|
| App Service Plan | The "server" that hosts one or many web apps |
| App Service | The actual web application resource |
| `app_settings` block | How environment variables are injected into a web app |
| `lifecycle` block | Controlling what Terraform does and does not manage |
| Referencing Key Vault secrets in app settings | Combining data sources with resource config |
| PowerShell-specific commands | Windows-compatible verification commands |

### How Everything Connects

```
NCT-INFRA-002  →  You learned: Networking, NSG, VM (compute layer)
NCT-INFRA-004  →  You learned: Key Vault, data sources, sensitive values
NCT-INFRA-005  →  You apply BOTH: Key Vault secrets feed into App Service config
```

This is the first project where you will feel previous projects
paying off. The Key Vault pattern from 004 is reused here directly.

### Scope Boundaries

- No custom domain, no SSL certificate
- No deployment slots (dev/prod swap) — that is NCT-INFRA-006
- No GitHub Actions or CI/CD pipeline
- Free tier App Service Plan (F1) — zero cost
- No VNet integration for the App Service
- Python 3.11 runtime only
- Flat folder structure — no modules

---

## 2. Naming Conventions

### App Service Naming — Global Uniqueness Required

App Service names must be **globally unique across all of Azure** —
just like Storage Account names. The app name becomes part of the
public URL:

```
https://{app-service-name}.azurewebsites.net
```

NexaCore naming pattern for App Services:

```
Pattern:  {org-prefix}-{env}-{workload}-web
Example:  nct-dev-app-web

But this may already be taken globally. Use:
nct-dev-app-web-{your-initials}
Example:  nct-dev-app-web-jd
```

### Full Resource Naming for This Project

| Resource | Name |
|---|---|
| Resource Group | `nct-dev-app-rg` |
| Key Vault | `nct-dev-app-kv` |
| App Service Plan | `nct-dev-app-plan` |
| App Service | `nct-dev-app-web-{initials}` |

### File Structure

```
nct-infra-005/
├── providers.tf      ← provider + terraform version
├── main.tf           ← all resource definitions
├── data.tf           ← data sources only (Key Vault + secrets)
├── variables.tf      ← variable declarations
├── outputs.tf        ← output declarations
└── terraform.tfvars  ← non-sensitive values only
```

### Secret Naming Inside Key Vault → `kebab-case`

```
app-secret-key       ← application secret key
db-connection        ← database connection string
app-environment      ← environment name (development/staging/production)
```

### NexaCore Mandatory Tags

| Tag Key | Value |
|---|---|
| `Project` | `NCT-INFRA-005` |
| `Environment` | `dev` |
| `Owner` | `jane-doe` |
| `ManagedBy` | `terraform` |
| `CostCentre` | `CC-DEVOPS-007` |
| `Team` | `platform-engineering` |

### Sample Data to Use

```hcl
# terraform.tfvars

org_prefix          = "nct"
environment         = "dev"
azure_location      = "East US"
app_service_name    = "nct-dev-app-web-jd"    # add your initials
key_vault_name      = "nct-dev-app-kv"
resource_group_name = "nct-dev-app-rg"
owner_name          = "jane-doe"
cost_centre         = "CC-DEVOPS-007"
```

---

## 3. Core Components to Build

### Component 1 — Resource Group + Client Config Data Source

**Files:** `data.tf` and `main.tf`

Same pattern as NCT-INFRA-004. You need the client config data source
for the Key Vault access policy, and a resource group for everything to
live in.

**In `data.tf`:**
```
data "azurerm_client_config" "current" { }
```

**In `main.tf`:**
- `azurerm_resource_group` with all six org tags

---

### Component 2 — Azure Key Vault + Three Secrets

**File:** `main.tf`

Same pattern as NCT-INFRA-004 but with different secret names and values.
This time the secrets represent real application configuration that a
Python web app would need.

**Key Vault resource** (`azurerm_key_vault`):
- Same settings as NCT-INFRA-004
- `name` = from variable `var.key_vault_name`
- `soft_delete_retention_days` = `7`
- `purge_protection_enabled` = `false`
- Access policy granting your identity full secret permissions

**Three secrets to create** (`azurerm_key_vault_secret`):

Secret 1:
```
name  = "app-secret-key"
value = "nct-super-secret-key-2024"
```

Secret 2:
```
name  = "db-connection"
value = "Server=nct-dev-sql;Database=nctapp;User=nctadmin;Password=Nct@2024!"
```

Secret 3:
```
name  = "app-environment"
value = "development"
```

---

### Component 3 — Data Sources to Read the Secrets

**File:** `data.tf`

Read back all three secrets using data sources.
Include `depends_on` pointing to each secret resource — same pattern
as NCT-INFRA-004. You have done this before. Apply what you learned.

**You must define:**

```
data "azurerm_key_vault_secret" "app_secret_key"  { }
data "azurerm_key_vault_secret" "db_connection"   { }
data "azurerm_key_vault_secret" "app_environment" { }
```

Each needs:
- `name` — the secret's kebab-case name in Key Vault
- `key_vault_id` — reference to the Key Vault resource
- `depends_on` — pointing to the matching secret resource

---

### Component 4 — App Service Plan

**File:** `main.tf`

An App Service Plan defines the compute resources (CPU, RAM, region)
that one or more App Services run on. Think of it as the server —
the App Service is the application running on that server.

**You must define `azurerm_service_plan`:**

- `name` = `"nct-dev-app-plan"`
- `location` and `resource_group_name` — from RG resource attributes
- `os_type` = `"Linux"` — Python runs on Linux at NexaCore
- `sku_name` = `"F1"` — Free tier, zero cost
- All six org tags

> `F1` (Free tier) has limits: no custom domains, no SSL,
> no always-on, 60 minutes CPU per day. Fine for learning.
> Production would use `"B1"` (Basic) or higher.

> **Note for Windows users:** Even though your laptop runs Windows,
> the App Service OS is Linux. This is normal — Azure manages the
> Linux container. Your PowerShell terminal is just the control plane.

---

### Component 5 — App Service with Environment Variables from Key Vault

**File:** `main.tf`

This is the core of the project. The App Service is where the application
runs. The `app_settings` block is how you inject environment variables
into it — and those variables come from Key Vault data sources.

**You must define `azurerm_linux_web_app`:**

- `name` = from `var.app_service_name`
- `location` and `resource_group_name` — from RG resource attributes
- `service_plan_id` = reference to the App Service Plan resource
- All six org tags

**`site_config` block** (required, controls runtime settings):
```
site_config {
  always_on         = false          # must be false on Free tier F1
  application_stack {
    python_version  = "3.11"
  }
}
```

**`app_settings` block** (environment variables for the app):
```hcl
app_settings = {
  "SECRET_KEY"                  = data.azurerm_key_vault_secret.app_secret_key.value
  "DATABASE_URL"                = data.azurerm_key_vault_secret.db_connection.value
  "APP_ENV"                     = data.azurerm_key_vault_secret.app_environment.value
  "WEBSITE_RUN_FROM_PACKAGE"    = "1"
  "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
}
```

> `WEBSITE_RUN_FROM_PACKAGE = "1"` tells Azure to run the app directly
> from a deployment package rather than copying files. This is the
> recommended deployment method for Azure App Service.

**`lifecycle` block** — this is new:
```hcl
lifecycle {
  ignore_changes = [
    app_settings["WEBSITE_RUN_FROM_PACKAGE"]
  ]
}
```

**Why `lifecycle`?** When you deploy application code to the App Service
later (via Azure CLI or VS Code extension), Azure may automatically update
certain app settings like `WEBSITE_RUN_FROM_PACKAGE`. Without `ignore_changes`,
the next `terraform plan` would detect this as "drift" and try to revert it —
overwriting your deployment. `ignore_changes` tells Terraform: "I know this
value may change outside of Terraform — leave it alone."

---

### Component 6 — Variables and Outputs

**Files:** `variables.tf` and `outputs.tf`

**Variables to declare:**

```
org_prefix
environment
azure_location
app_service_name
key_vault_name
resource_group_name
owner_name
cost_centre
```

**Outputs to expose:**

```
app_service_url         ← the public URL: https://{name}.azurewebsites.net
app_service_name        ← the actual app service name
key_vault_uri           ← the vault's URL
resource_group_name     ← confirms which RG was created
default_hostname        ← raw hostname without https:// prefix
```

> `app_service_url` should be formatted as a full URL using `format()`:
> ```hcl
> value = format("https://%s", azurerm_linux_web_app.app.default_hostname)
> ```

---

## 4. Hints & Pitfalls

### Hint 1 — `always_on = false` Is Not Optional on Free Tier

If you set `always_on = true` (which many tutorials suggest for production),
Terraform will throw this error on Free tier:

```
always_on cannot be set to true when using Free, F1, D1 or Shared SKU
```

Free tier (`F1`) apps go to sleep after 20 minutes of inactivity.
The first request after sleep takes 10–30 seconds to wake up.
This is expected behaviour for a learning environment — not a bug.

Always check the SKU limits when copying settings from tutorials written
for production environments.

---

### Hint 2 — App Service Name Taken? The Error Is Confusing

If your app service name is already taken globally, Azure returns:

```
Error: creating Linux Web App: (Site Name "nct-dev-app-web" / ...):
web.AppsClient#CreateOrUpdate: Failure sending request:
StatusCode=0 -- Original Error: autorest/azure: Service returned an
error. Status=<nil> Code="Conflict"
```

The word `Conflict` is Azure's way of saying the name is taken.
The fix is to add your initials or a short random suffix to the name
in your `terraform.tfvars`:

```hcl
app_service_name = "nct-dev-app-web-jd"     # jd = jane doe
```

Check name availability before applying:
```powershell
# PowerShell
az webapp list-runtimes --os-type linux
# This confirms the runtime is available, not the name — check name via:
az webapp show --name nct-dev-app-web-jd --resource-group nct-dev-app-rg
# If it returns "ResourceNotFound", the name is available
```

---

### Hint 3 — `lifecycle` Block Goes INSIDE the Resource Block

A very common mistake is placing the `lifecycle` block outside the
resource block or at the bottom of the file as a standalone block.

```hcl
# WRONG — lifecycle outside resource
resource "azurerm_linux_web_app" "app" {
  name = "..."
}

lifecycle {                          # ← This will cause a parse error
  ignore_changes = [...]
}

# CORRECT — lifecycle inside resource
resource "azurerm_linux_web_app" "app" {
  name = "..."

  lifecycle {                        # ← Inside the resource block
    ignore_changes = [...]
  }
}
```

The `lifecycle` block is always a child of the resource it applies to.
It is not a top-level block and cannot exist independently.

---

### Hint 4 — PowerShell String Formatting Differs from Bash

When using PowerShell in VS Code on Windows, some commands from
online tutorials written for Bash will not work directly.

**Common differences you will hit:**

```powershell
# Bash (does NOT work in PowerShell)
ssh nctadmin@$(terraform output -raw vm_public_ip)

# PowerShell equivalent
$ip = terraform output -raw vm_public_ip
ssh nctadmin@$ip
```

```powershell
# Bash (does NOT work in PowerShell)
curl -s https://api.ipify.org

# PowerShell equivalent
Invoke-RestMethod https://api.ipify.org
# or
(Invoke-WebRequest https://api.ipify.org).Content.Trim()
```

All commands in this project's Workflow section below are written
for PowerShell. Use them as-is.

---

## 5. Real Environment Requirements

### Tools (verify in PowerShell terminal inside VS Code)

```powershell
# Check Terraform
terraform version
# Expected: Terraform v1.6.x or higher

# Check Azure CLI
az version
# Expected: "azure-cli": "2.50.x" or higher

# Check you are logged in
az account show --output table

# Get your public IP (PowerShell way)
(Invoke-WebRequest https://api.ipify.org).Content.Trim()
```

### VS Code Extensions to Have Installed

```
HashiCorp Terraform     ← syntax highlighting, validation, hover docs
Azure Tools             ← Azure resource browsing inside VS Code
```

### Azure Free Tier Limits for App Service F1

```
CPU time per day:       60 minutes
RAM:                    1 GB
Storage:                1 GB
Custom domains:         Not supported
SSL certificates:       Not supported
Always On:              Not supported
Deployment slots:       Not supported
Scale out instances:    1 (no scaling)
```

---

## 6. Workflow (PowerShell — Windows + VS Code)

```powershell
# Open VS Code integrated terminal (Ctrl + ` )
# Make sure terminal shows: PS C:\...\nct-infra-005>

# ── Step 1: Navigate to project folder ───────────────────────────
cd C:\Projects\nct-infra-005     # adjust path to where you created the folder

# ── Step 2: Initialise ────────────────────────────────────────────
terraform init
# Expected: "Terraform has been successfully initialized!"

# ── Step 3: Validate ──────────────────────────────────────────────
terraform validate
# Expected: "Success! The configuration is valid."

# ── Step 4: Format ────────────────────────────────────────────────
terraform fmt
# Formats all .tf files in the current folder

# ── Step 5: Plan — read every line carefully ──────────────────────
terraform plan
# Count the resources: should be approximately 8-9 to add

# ── Step 6: Apply ─────────────────────────────────────────────────
terraform apply
# Type: yes when prompted
# Takes 2-4 minutes — App Service provisioning is slower than VM

# ── Step 7: Get the app URL ───────────────────────────────────────
terraform output app_service_url
# Example output: "https://nct-dev-app-web-jd.azurewebsites.net"

# ── Step 8: Open the app in browser ──────────────────────────────
$url = terraform output -raw app_service_url
Start-Process $url
# Opens your default browser to the App Service default page
# (shows Azure default page since no code is deployed — that is expected)

# ── Step 9: Verify Key Vault secrets ─────────────────────────────
az keyvault secret list `
  --vault-name nct-dev-app-kv `
  --output table
# Expected: app-secret-key, db-connection, app-environment

# ── Step 10: Verify app settings are applied ─────────────────────
az webapp config appsettings list `
  --name nct-dev-app-web-jd `
  --resource-group nct-dev-app-rg `
  --output table
# Expected: SECRET_KEY, DATABASE_URL, APP_ENV, WEBSITE_RUN_FROM_PACKAGE

# ── Step 11: Destroy when done ────────────────────────────────────
terraform destroy
# Type: yes when prompted

# ── Step 12: Purge the soft-deleted Key Vault ────────────────────
az keyvault purge `
  --name nct-dev-app-kv `
  --location "East US"
# Required because of soft_delete_retention_days = 7
```

> **PowerShell line continuation:** In PowerShell, the backtick ( ` ) at the
> end of a line continues the command on the next line. This is the
> PowerShell equivalent of `\` in Bash. All multi-line commands above
> use this correctly.

---

## 7. NexaCore Code Review Checklist

```
[ ] data.tf is separate — no data sources mixed into main.tf
[ ] azurerm_client_config.current declared in data.tf
[ ] All three secrets created with correct kebab-case names
[ ] All three data sources have depends_on pointing to their secret resource
[ ] app_settings references data source values — NOT hardcoded strings
[ ] always_on = false (Free tier requirement)
[ ] python_version = "3.11" inside application_stack block
[ ] lifecycle block is INSIDE the azurerm_linux_web_app resource block
[ ] App service name is globally unique (initials or suffix added)
[ ] No sensitive values in terraform.tfvars
[ ] terraform validate passes
[ ] terraform fmt run
[ ] terraform output app_service_url returns a valid URL
[ ] Browser opens the App Service default page successfully
[ ] terraform destroy + az keyvault purge run at end of session
```

---

## 8. What You Now Know After Completing This Ticket

```
NCT-INFRA-001   Storage, Provider config, basic resources
NCT-INFRA-002   Networking, NSG, Compute, dependency chains
NCT-INFRA-003   Modules, Remote State, multi-environment structure
NCT-INFRA-004   Key Vault, data sources, sensitive values, depends_on
NCT-INFRA-005   App Service, app_settings, lifecycle block, runtime config
                ↑ First time deploying an actual application platform
────────────────────────────────────────────────────────────────────────
NCT-INFRA-006   (Next) → Deployment Slots + Azure SQL Database
                          Two App Service slots (dev/staging swap),
                          a real database, and connection string management
                          This is the first fully production-like setup
```

### The Progression So Far — In One View

```
001  →  "I can provision a storage resource"
002  →  "I can build a full networking + compute stack"
003  →  "I can structure code for a real team"
004  →  "I understand how secrets are managed"
005  →  "I can provision a platform that runs a web application"
```

You are no longer a beginner writing single-resource configs.
You are writing infrastructure that resembles what real teams ship.

---

*NexaCore Technologies — Platform Engineering | Internal Training Material*
*NCT-INFRA-005 | Windows + VS Code + PowerShell edition*
*Do not distribute outside the DevOps team*
