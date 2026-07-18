# Meridian Bank — Cloud Infrastructure Training Series
## Managed Identity for App Service
**Project Code:** `MRB-INFRA-003` | **Level:** Beginner+ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained

---

> **From your Team Lead:** MRB-002 proved Managed Identity works on
> a VM. Most of our actual workloads are App Services, not VMs.
> This ticket proves the exact same pattern generalizes — same
> `identity {}` block, same RBAC role assignment logic, different
> resource type. If you understood MRB-002, this will feel familiar
> fast. — *Rohan Mehta*

---

## Org Context

| Field | Detail |
|---|---|
| **Ticket** | `MRB-INFRA-003` | **Depends On** | Nothing — standalone |
| **Environment** | `dev` | **Region** | `East US` | **Cost Centre** | `CC-CLOUD-001` |

---

## 1. Overview

**An App Service with a System-Assigned Managed Identity, granted
RBAC read access to a Key Vault secret — zero credentials in config.**

```
Key Vault (mrb-dev-003-kv)
  └── secret: storage-connection-string
         ▲ RBAC role: "Key Vault Secrets User"
         │
App Service (mrb-dev-003-web-{initials})
  identity { type = "SystemAssigned" }
  app_settings reference Key Vault directly via a special syntax —
  NO data source needed this time. This is new.
```

### The New Concept — Key Vault References in `app_settings`

In MRB-002, the VM's identity could read a secret only if you
wrote code on the VM to call Azure's API. App Service has a
shortcut: you can reference a Key Vault secret **directly inside
`app_settings`** using a special string syntax. Azure resolves it
automatically at runtime using the App Service's Managed Identity
— no application code required at all.

```hcl
app_settings = {
  "STORAGE_CONNECTION" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.storage_conn.versionless_id})"
}
```

Azure sees the `@Microsoft.KeyVault(...)` syntax, uses the App
Service's own Managed Identity to fetch the secret, and injects
the real value as the environment variable — completely invisible
to your Terraform state or your application code.

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_key_vault` (RBAC model, from
MRB-002), `azurerm_key_vault_secret`, `azurerm_service_plan`,
`azurerm_linux_web_app` base config, `locals` tags, `data
"azurerm_client_config"`.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-003-rg` |
| Key Vault | `mrb-dev-003-kv` |
| App Service Plan | `mrb-dev-003-plan` |
| App Service | `mrb-dev-003-web-{initials}` |

Same 8 MRB tags as MRB-001/002. `DataClassification = "confidential"`,
`ComplianceScope = "internal-audit"`.

```hcl
# terraform.tfvars
org_prefix           = "mrb"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "mrb-dev-003-rg"
key_vault_name       = "mrb-dev-003-kv"
app_service_name     = "mrb-dev-003-web-jd"
owner_name           = "alex-morgan"
cost_centre          = "CC-CLOUD-001"
data_classification  = "confidential"
compliance_scope     = "internal-audit"
```

Secret: `storage-connection-string` → `"DefaultEndpointsProtocol=https;AccountName=mrbdemo;AccountKey=placeholder;"`

---

## 3. Core Components

### Component 1 — Key Vault (RBAC) + Secret
Same exact pattern as MRB-002 Component 2. Build from memory:
`enable_rbac_authorization = true`, no `access_policy`, grant
yourself `"Key Vault Secrets Officer"`, then create the secret
with `depends_on` pointing at your role assignment.

### Component 2 — App Service Plan + App Service with Identity

**File:** `main.tf`

Standard `azurerm_service_plan` (`os_type = "Linux"`, `sku_name = "F1"`).

**`azurerm_linux_web_app` — new pieces only:**

```hcl
resource "azurerm_linux_web_app" "app" {
  # ... standard name, location, resource_group_name, service_plan_id ...

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "STORAGE_CONNECTION" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.storage_conn.versionless_id})"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }

  tags = local.common_tags
}
```

> `versionless_id` (not `id`) is used deliberately — it points to
> "always the latest version" of the secret rather than one
> specific version. If you rotate the secret later, the App
> Service picks up the new value automatically without a
> Terraform change.

### Component 3 — Grant the App Service's Identity Access

**File:** `main.tf`

```hcl
resource "azurerm_role_assignment" "app_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id          = azurerm_linux_web_app.app.identity[0].principal_id
}
```

Identical pattern to MRB-002 Component 4 — only the resource
providing `identity[0].principal_id` has changed, from a VM to
a Web App.

> **Critical ordering:** this role assignment must exist BEFORE
> the App Service can successfully resolve the `@Microsoft.KeyVault(...)`
> reference at runtime. Since `app_settings` references the secret
> directly by URI (not through this role assignment resource),
> Terraform does not automatically know to wait. Add an explicit
> `depends_on` on the App Service pointing to this role assignment
> if you see the app fail to start with a Key Vault reference error.

### Component 4 — Variables + Outputs

Variables: same list pattern as MRB-002 minus VM-specific ones,
plus `app_service_name`.

Outputs:
```
app_service_url
app_managed_identity_id   ← azurerm_linux_web_app.app.identity[0].principal_id
key_vault_uri
resource_group_name
```

---

## 4. Hints

**Hint 1 — `versionless_id` vs `id`:** using `.id` pins to one
exact secret version forever; `.versionless_id` always resolves
to latest. For app config that may rotate, always prefer
`versionless_id`.

**Hint 2 — Key Vault reference errors show up in App Service logs,
not in `terraform apply`:** Terraform will apply successfully even
if the role assignment is missing — the failure only appears when
the App Service actually tries to start and resolve the reference.
Check via:
```powershell
az webapp log tail --name mrb-dev-003-web-jd --resource-group mrb-dev-003-rg
```

**Hint 3 — Same principal_id mistake as MRB-002:** don't accidentally
reuse `data.azurerm_client_config.current.object_id` for the App
Service's role assignment. It needs its OWN identity's principal_id.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\mrb-infra-003
terraform init
terraform validate
terraform fmt
terraform plan
terraform apply    # type: yes

terraform output app_managed_identity_id
az role assignment list --assignee (terraform output -raw app_managed_identity_id) --output table

# Confirm the setting resolved (not just present)
az webapp config appsettings list `
  --name mrb-dev-003-web-jd `
  --resource-group mrb-dev-003-rg `
  --output table
# STORAGE_CONNECTION should show the resolved value, not the @Microsoft.KeyVault(...) string

terraform destroy    # type: yes
az keyvault purge --name mrb-dev-003-kv --location "East US"
```

---

## 6. Checklist

```
[ ] Key Vault: enable_rbac_authorization = true, no access_policy
[ ] App Service has identity { type = "SystemAssigned" }
[ ] app_settings uses @Microsoft.KeyVault(SecretUri=...versionless_id...)
[ ] Role assignment uses azurerm_linux_web_app.app.identity[0].principal_id
[ ] Role assignment is "Key Vault Secrets User" (read-only)
[ ] All 8 MRB tags present
[ ] appsettings list shows resolved value, not the raw reference string
[ ] terraform destroy + keyvault purge completed
```

---

## 7. Cost — Under $0.02 for a full session (F1 App Service + Key Vault, free tier)

## Next: MRB-INFRA-004 — Private Networking + Standard Load Balancer

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
