# Meridian Bank — Cloud Infrastructure Training Series
## Secure Azure Storage + Access Controls
**Project Code:** `MRB-INFRA-001` | **Track:** Cloud Infrastructure Engineer (Trainee)
**Level:** Beginner+ | **Environment:** Windows + VS Code + PowerShell

---

> **A message from your Team Lead:**
> Welcome to the Meridian Bank Cloud Infrastructure team.
> Before you touch any production system you go through our
> internal training series. Every project follows our compliance
> standards — even in dev. That means strict naming, mandatory
> tags including data classification, and no resource left
> running when you are done.
>
> Your first ticket is deliberately simple in scope but strict
> in standards. You are provisioning secure blob storage for
> our internal audit log archival team. They need a storage
> account that is locked down — no public access, versioning
> enabled, soft delete enabled, and access logging turned on.
>
> Read the compliance requirements before you write a line.
> At Meridian, cutting corners on security config is not a
> learning mistake — it is a policy violation.
> — *Rohan Mehta, Lead Cloud Engineer, Meridian Bank*

---

## Org Context

| Field | Detail |
|---|---|
| **Organisation** | Meridian Bank Pvt. Ltd. |
| **Department** | Technology Infrastructure |
| **Team** | Cloud Platform Engineering |
| **Your Role** | Cloud Infrastructure Engineer (Trainee) |
| **Reporting To** | Rohan Mehta (Lead Cloud Engineer) |
| **Ticket ID** | `MRB-INFRA-001` |
| **Environment** | `dev` only |
| **Cloud** | Microsoft Azure |
| **IaC Tool** | Terraform `v1.6+` |
| **Azure Region** | `East US` (Meridian primary region) |
| **Cost Centre** | `CC-CLOUD-001` |
| **Terminal** | PowerShell (Windows + VS Code) |

---

## Meridian Bank — Compliance Standards (Read First)

This is new compared to NexaCore. Meridian has regulatory
requirements that affect every resource you provision.

### MRB Security Baseline for Storage

```
✓ No public blob access — ever
✓ HTTPS only — no HTTP traffic permitted
✓ Soft delete enabled — minimum 14 days (NexaCore used 7)
✓ Blob versioning enabled — recover any version of any file
✓ Access logging enabled — who accessed what and when
✓ Minimum TLS version: TLS 1.2
✓ Encryption: Azure-managed keys (default, no extra cost)
```

### MRB Mandatory Tags — Stricter Than NexaCore

Meridian has two additional mandatory tags that NexaCore did not:

| Tag Key | Description | Example Value |
|---|---|---|
| `Project` | Project code | `MRB-INFRA-001` |
| `Environment` | Deployment environment | `dev` |
| `Owner` | Engineer responsible | `alex-morgan` |
| `ManagedBy` | Provisioning tool | `terraform` |
| `CostCentre` | Billing code | `CC-CLOUD-001` |
| `Team` | Owning team | `cloud-platform` |
| `DataClassification` | **NEW** Sensitivity of data stored | `internal` |
| `ComplianceScope` | **NEW** Regulatory framework | `internal-audit` |

> `DataClassification` valid values at Meridian:
> `public` / `internal` / `confidential` / `restricted`
>
> `ComplianceScope` valid values:
> `none` / `internal-audit` / `pci-dss` / `gdpr`
>
> Audit logs are classified `internal` under `internal-audit` scope.

### MRB Naming Convention

```
Pattern: {org}-{env}-{workload}-{resource-type}

org      = mrb
env      = dev / stg / prod
workload = short description of what it does
type     = sa / rg / kv / vm / vnet / etc.
```

---

## 1. Project Overview

### What You Are Building

**A locked-down Azure Storage Account for internal audit log
archival — with versioning, soft delete, access logging, and
zero public access — all provisioned with Terraform.**

```
┌─────────────────────────────────────────────────────────────────┐
│  Resource Group  (mrb-dev-auditlogs-rg)                         │
│                                                                 │
│  └── Storage Account  (mrbdevauditlogssa)                       │
│       ├── No public access                                      │
│       ├── HTTPS only                                            │
│       ├── TLS 1.2 minimum                                       │
│       ├── Soft delete: 14 days                                  │
│       ├── Blob versioning: enabled                              │
│       ├── Blob container: audit-logs (private)                  │
│       └── Diagnostic logging → same storage account            │
└─────────────────────────────────────────────────────────────────┘
```

### What Is Different from NexaCore NCT-INFRA-001

| NexaCore NCT-001 | Meridian MRB-001 |
|---|---|
| Public blob access enabled | No public access — ever |
| No versioning | Versioning enabled |
| No soft delete | Soft delete 14 days |
| No TLS enforcement | TLS 1.2 minimum |
| 5 mandatory tags | 8 mandatory tags |
| Static website focus | Audit log archival focus |

The Terraform resources are similar — the security configuration
inside them is completely different. That is intentional.
Same tool, higher security bar.

### What You Already Know — No Guidance Given

- `providers.tf` + `features {}` → NCT-001 onward
- `backend.tf` → NCT-003 onward
- `variables.tf` + `terraform.tfvars` → NCT-001 onward
- `outputs.tf` → NCT-001 onward
- `locals {}` for tags → NCT-003 onward
- `azurerm_resource_group` → every project
- `azurerm_storage_account` → NCT-001, NCT-003, NCT-008
- `azurerm_storage_container` → NCT-003

Apply all of the above from memory. The spec focuses only on
what is new or different.

### Scope Boundaries

- No Key Vault this project — focus is on storage security config
- No VM, no networking, no App Service
- One storage account, one container
- `dev` environment only

---

## 2. Naming Conventions

### Full Resource Naming

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-auditlogs-rg` |
| Storage Account | `mrbdevauditlogssa` (no hyphens, max 24 chars) |
| Blob Container | `audit-logs` |

### File Structure

```
mrb-infra-001/
├── providers.tf
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

### Remote State Key

```
mrb-infra-001/dev/terraform.tfstate
```

> Use the same bootstrap storage account from the NexaCore series
> if it is still running. If not, re-run the bootstrap from
> NCT-INFRA-003 first. The state container is shared.

---

## 3. Sample Data

```hcl
# terraform.tfvars

org_prefix              = "mrb"
environment             = "dev"
azure_location          = "East US"
resource_group_name     = "mrb-dev-auditlogs-rg"
storage_account_name    = "mrbdevauditlogssa"
container_name          = "audit-logs"
owner_name              = "alex-morgan"
cost_centre             = "CC-CLOUD-001"
data_classification     = "internal"
compliance_scope        = "internal-audit"
soft_delete_days        = 14
```

---

## 4. Core Components to Build

### Component 1 — Resource Group

**File:** `main.tf`

You know this. Eight tags this time instead of six.
`DataClassification` and `ComplianceScope` are new.

Build the `locals {}` common_tags map with all eight tags.
Every resource in this project uses it.

---

### Component 2 — Storage Account with Meridian Security Baseline

**File:** `main.tf`

You have built `azurerm_storage_account` before (NCT-001, NCT-003,
NCT-008). This time the security arguments inside it are different
and stricter. Focus on the new arguments below.

**You must define `azurerm_storage_account` with:**

Standard arguments you already know:
- `name`, `resource_group_name`, `location`
- `account_tier` = `"Standard"`
- `account_replication_type` = `"LRS"`
- `tags` = `local.common_tags`

**New Meridian-required security arguments:**

```hcl
# No public access to any blob — MRB security baseline
allow_nested_items_to_be_public = false

# HTTPS only — reject any HTTP requests
enable_https_traffic_only = true

# Minimum TLS version — TLS 1.0 and 1.1 are not permitted at MRB
min_tls_version = "TLS1_2"

# Blob properties block — versioning + soft delete
blob_properties {
  versioning_enabled = true

  delete_retention_policy {
    days = var.soft_delete_days    # 14 days at MRB minimum
  }

  container_delete_retention_policy {
    days = var.soft_delete_days    # also protect deleted containers
  }
}
```

> `delete_retention_policy` protects individual blobs.
> `container_delete_retention_policy` protects entire containers.
> Meridian requires both — a deleted container should be
> recoverable, not just individual files inside it.

> **Cost note:** All of these security settings are free.
> Versioning stores multiple versions of each blob —
> the only added cost is storage for those versions.
> For a dev learning environment with no real data,
> the cost is effectively zero.

---

### Component 3 — Blob Container

**File:** `main.tf`

You built `azurerm_storage_container` in NCT-INFRA-003.
Same resource, same pattern.

**You must define `azurerm_storage_container`:**

- `name` = `var.container_name` (`"audit-logs"`)
- `storage_account_name` = reference to SA name attribute
- `container_access_type` = `"private"` — mandatory at MRB

> `"private"` means only authenticated Azure identities
> with explicit permission can access this container.
> No anonymous reads. No public URLs. Ever.
> This is the only acceptable value for Meridian Bank storage.

---

### Component 4 — Variables and Outputs

**Files:** `variables.tf` and `outputs.tf`

**Variables to declare** (all with type and description):

```
org_prefix
environment
azure_location
resource_group_name
storage_account_name
container_name
owner_name
cost_centre
data_classification     ← new for MRB
compliance_scope        ← new for MRB
soft_delete_days        ← type = number
```

**Outputs to expose:**

```
storage_account_name       ← actual SA name
storage_account_id         ← Azure resource ID
primary_blob_endpoint      ← the blob service URL
container_name             ← confirms container was created
resource_group_name        ← the RG name
soft_delete_enabled        ← true (confirm the policy is on)
```

> `soft_delete_enabled` is a simple `true` value output.
> Its purpose is documentation — when another engineer runs
> `terraform output` they immediately see the compliance
> settings are active without opening the Azure Portal.

---

## 5. Hints & Pitfalls

### Hint 1 — `enable_https_traffic_only` May Show as Deprecated

In newer versions of the Azure provider (`azurerm ~> 3.x`),
`enable_https_traffic_only` may show a deprecation warning
and suggest using `https_traffic_only_enabled` instead.

If you see this warning:
```
Warning: Argument is deprecated
  "enable_https_traffic_only" has been deprecated in favour of
  "https_traffic_only_enabled"
```

Switch to the new argument name:
```hcl
https_traffic_only_enabled = true
```

Both work, but use the newer one if your provider version flags it.
This is a real-world lesson — provider APIs evolve and argument
names change. Always read deprecation warnings, never ignore them.

### Hint 2 — `blob_properties` Block Has Nested Blocks — Indentation Matters

The `blob_properties` block contains nested blocks inside it.
A common mistake is getting the closing braces wrong:

```hcl
# WRONG — missing closing brace for delete_retention_policy
blob_properties {
  versioning_enabled = true
  delete_retention_policy {
    days = 14
                          # ← missing } here
  container_delete_retention_policy {
    days = 14
  }
}

# CORRECT — every block properly closed
blob_properties {
  versioning_enabled = true

  delete_retention_policy {
    days = 14
  }                       # ← closes delete_retention_policy

  container_delete_retention_policy {
    days = 14
  }                       # ← closes container_delete_retention_policy
}                         # ← closes blob_properties
```

Run `terraform fmt` after writing this block — it will flag
mismatched braces immediately.

### Hint 3 — Soft Delete Days Has a Minimum and Maximum

Azure enforces these limits on `delete_retention_policy`:
- Minimum: `1` day
- Maximum: `365` days

Meridian's policy is 14 days minimum. If you set `days = 0`
by mistake, Azure will reject it during apply:

```
Error: soft delete must be enabled with a period between 1 and 365 days
```

The variable `soft_delete_days` is declared as `number` —
make sure the value in `terraform.tfvars` is `14`, not `"14"`
(string). Passing a string to a number variable causes a
type mismatch error at plan time.

---

## 6. Workflow (PowerShell)

```powershell
# Navigate to project
cd C:\Projects\mrb-infra-001

# Confirm Azure login
az account show --output table

# Standard workflow
terraform init
terraform validate
terraform fmt
terraform plan
# Should show: 3 resources to add (RG + SA + Container)

terraform apply
# Type: yes

# Verify security settings are applied
az storage account show `
  --name mrbdevauditlogssa `
  --resource-group mrb-dev-auditlogs-rg `
  --query "{Name:name, HttpsOnly:enableHttpsTrafficOnly, TLS:minimumTlsVersion, PublicAccess:allowBlobPublicAccess}" `
  --output table
# Expected:
# HttpsOnly = true
# TLS       = TLS1_2
# PublicAccess = false

# Verify soft delete is enabled
az storage account blob-service-properties show `
  --account-name mrbdevauditlogssa `
  --resource-group mrb-dev-auditlogs-rg `
  --query "{Versioning:isVersioningEnabled, SoftDelete:deleteRetentionPolicy}" `
  --output json
# Expected: isVersioningEnabled = true, deleteRetentionPolicy.days = 14

# Verify container is private
az storage container show `
  --name audit-logs `
  --account-name mrbdevauditlogssa `
  --query publicAccess `
  --output tsv
# Expected: (empty output = private, no public access)

# Destroy when done
terraform destroy
# Type: yes
```

---

## 7. Meridian Bank Code Review Checklist

```
[ ] All 8 mandatory tags present on every taggable resource
[ ] DataClassification = "internal" on storage account
[ ] ComplianceScope = "internal-audit" on storage account
[ ] allow_nested_items_to_be_public = false
[ ] enable_https_traffic_only = true (or https_traffic_only_enabled)
[ ] min_tls_version = "TLS1_2"
[ ] versioning_enabled = true inside blob_properties
[ ] delete_retention_policy days = 14
[ ] container_delete_retention_policy days = 14
[ ] container_access_type = "private"
[ ] soft_delete_days variable declared as type = number
[ ] No hardcoded values — all from variables
[ ] terraform validate passes
[ ] terraform fmt run
[ ] Azure CLI verification commands run and confirmed
[ ] terraform destroy completed at end of session
```

---

## 8. What Comes Next

```
MRB-INFRA-001   ✅  Secure Storage + Compliance Baseline    ← THIS PROJECT
MRB-INFRA-002   📋  Azure Key Vault (MRB compliance edition)
                     Stricter access policies, RBAC instead of
                     legacy access policies, audit logging on KV
MRB-INFRA-003   📋  Private Networking (no public IPs)
                     VNet, private subnets, NSG with bank-grade rules
MRB-INFRA-004   📋  Azure SQL with Threat Detection
                     SQL + Advanced Threat Protection + Auditing
MRB-INFRA-005   📋  App Service + Managed Identity
                     No credentials in config — VM/App accesses
                     Key Vault via its own Azure identity
```

> **What Managed Identity means (preview for MRB-005):**
> Instead of storing credentials to access Key Vault,
> the App Service IS an identity in Azure AD.
> It proves who it is without a password.
> This is the bank-grade approach — no secrets in config at all.

---

## Cost Reference — This Project

```
Resource              SKU          Est. Cost
────────────────────────────────────────────────────
Resource Group        Free         $0.00
Storage Account       Standard LRS ~$0.002/GB/month
Blob Container        Free         $0.00
────────────────────────────────────────────────────
Total (dev session)                < $0.01
Destroy same day      →            $0.00 effective
```

---

*Meridian Bank — Cloud Platform Engineering | Internal Training Material*
*MRB-INFRA-001 | Trainee Series | Windows + VS Code + PowerShell*
*CONFIDENTIAL — Internal Use Only*
