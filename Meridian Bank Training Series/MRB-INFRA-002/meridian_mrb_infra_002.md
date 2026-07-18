# Meridian Bank — Cloud Infrastructure Training Series
## Azure AD + Managed Identity — Secretless Authentication
**Project Code:** `MRB-INFRA-002` | **Track:** Cloud Infrastructure Engineer (Trainee)
**Level:** Beginner+ | **Environment:** Windows + VS Code + PowerShell
**Frequency:** Used in nearly every org — foundational identity work

---

> **A message from your Team Lead:**
> In the NexaCore series you learned to store secrets in Key Vault
> and read them with data sources. That is a real improvement over
> hardcoded credentials — but there is still a password sitting in
> Key Vault that something has to know how to retrieve.
>
> At Meridian Bank, our security team has a stricter standard for
> anything that touches production: wherever possible, no password
> or key should exist AT ALL — not in a config file, not in a vault,
> nowhere. The resource itself should prove its identity directly
> to Azure AD.
>
> This is called Managed Identity. It is the single most important
> security concept you will learn in this entire series. Once you
> understand it, you will notice how much of what you built in the
> NexaCore series could have been done without a single password.
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
| **Ticket ID** | `MRB-INFRA-002` |
| **Depends On** | Nothing — fully standalone |
| **Environment** | `dev` only |
| **Cloud** | Microsoft Azure |
| **IaC Tool** | Terraform `v1.6+` |
| **Azure Region** | `East US` |
| **Cost Centre** | `CC-CLOUD-001` |
| **Terminal** | PowerShell (Windows + VS Code) |

---

## 1. Project Overview

### What You Are Building

**A Linux VM with a System-Assigned Managed Identity, granted
RBAC permission to read a secret from Key Vault — with ZERO
credentials anywhere in your Terraform configuration.**

```
┌──────────────────────────────────────────────────────────────┐
│  Key Vault  (mrb-dev-002-kv)                                 │
│  RBAC authorization model (not legacy access policies)        │
│  └── secret: db-connection-string                             │
└──────────────────────────┬─────────────────────────────────────┘
                           │ RBAC role grants access
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  Linux VM  (mrb-dev-002-vm)                                  │
│  System-Assigned Managed Identity: ENABLED                    │
│  Role: "Key Vault Secrets User" — granted to the VM's OWN     │
│  identity, not to you, not to any password                    │
│                                                               │
│  When the VM needs the secret, it asks Azure AD:              │
│  "Prove I am mrb-dev-002-vm" → Azure AD confirms → secret      │
│  is released. No password. No key. No connection string       │
│  stored anywhere on the VM or in your Terraform state.         │
└──────────────────────────────────────────────────────────────┘
```

### The Core Concept — Before Any Code

**The old way (everything you built in NexaCore):**
```
You  → know a password  → use the password  → access the resource
```

**The Managed Identity way:**
```
Azure VM  → IS an identity in Azure AD  → proves itself  → access granted
```

Think of the old way like a hotel room key card that anyone
holding it can use. Managed Identity is like a hotel recognizing
your face at the door — no card exists to steal, lose, or leak.
The VM's identity is baked into Azure itself, not into a piece
of data your Terraform config has to protect.

### What Is New in This Project

| Concept | What You Will Learn |
|---|---|
| System-Assigned Managed Identity | An Azure resource becomes its own Azure AD identity |
| `identity {}` block | How you enable Managed Identity on a resource |
| `azurerm_role_assignment` | Granting a specific permission to a specific identity |
| RBAC Key Vault model | `enable_rbac_authorization = true` instead of `access_policy` |
| Built-in role definitions | Using Azure's pre-made roles like "Key Vault Secrets User" |

### What You Are Reusing — No Guidance Given

- `azurerm_resource_group` → every project
- `azurerm_linux_virtual_machine` (without the identity part) → NCT-002, NCT-004
- `azurerm_virtual_network`, `azurerm_subnet`, `azurerm_network_security_group`,
  `azurerm_public_ip`, `azurerm_network_interface` → NCT-002
- `providers.tf` + `backend.tf` → NCT-003 onward
- `locals {}` for tags → NCT-003 onward
- `data "azurerm_client_config"` → NCT-004 onward

Build the full networking stack and VM from memory. This spec
focuses only on the identity and RBAC pieces.

### Scope Boundaries

- One VM, one Key Vault, one secret, one role assignment
- SSH key authentication for the VM itself (you still need to log
  in) — Managed Identity is for the VM-to-Azure relationship, not
  your-laptop-to-VM
- No App Service in this project — pure VM + identity focus
- `dev` environment only

---

## 2. Naming Conventions

### Full Resource Naming

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-002-rg` |
| Key Vault | `mrb-dev-002-kv` |
| Virtual Network | `mrb-dev-002-vnet` |
| Subnet | `mrb-dev-002-subnet` |
| NSG | `mrb-dev-002-nsg` |
| Public IP | `mrb-dev-002-pip` |
| NIC | `mrb-dev-002-nic` |
| Virtual Machine | `mrb-dev-002-vm` |

### File Structure

```
mrb-infra-002/
├── providers.tf
├── backend.tf
├── data.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

### Remote State Key

```
mrb-infra-002/dev/terraform.tfstate
```

### MRB Mandatory Tags (all 8 — established in MRB-001)

| Tag Key | Value |
|---|---|
| `Project` | `MRB-INFRA-002` |
| `Environment` | `dev` |
| `Owner` | `alex-morgan` |
| `ManagedBy` | `terraform` |
| `CostCentre` | `CC-CLOUD-001` |
| `Team` | `cloud-platform` |
| `DataClassification` | `confidential` |
| `ComplianceScope` | `internal-audit` |

> `DataClassification` is `confidential` this time — one step up
> from MRB-001's `internal`, because this project handles a
> database connection string, which carries higher sensitivity
> than an audit log file.

---

## 3. Sample Data

```hcl
# terraform.tfvars

org_prefix           = "mrb"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "mrb-dev-002-rg"
key_vault_name       = "mrb-dev-002-kv"
vm_size              = "Standard_B1s"
admin_username       = "mrbadmin"
allowed_ssh_ip       = "YOUR_PUBLIC_IP/32"
owner_name           = "alex-morgan"
cost_centre          = "CC-CLOUD-001"
data_classification  = "confidential"
compliance_scope     = "internal-audit"
```

### Key Vault Secret to Store

```
Secret name: db-connection-string
Secret value: "Server=mrb-sql;Database=mrbapp;Trusted_Connection=True;"
```

> This is a placeholder connection string for the exercise — it
> does not point to a real database in this project. The purpose
> is purely to demonstrate the identity-based retrieval pattern.

---

## 4. Core Components to Build

### Component 1 — Resource Group + Networking

**File:** `main.tf`

Build the full stack from memory — you have done this multiple
times:
- `azurerm_resource_group`
- `azurerm_virtual_network` + `azurerm_subnet`
- `azurerm_network_security_group` (SSH rule from `var.allowed_ssh_ip`)
- `azurerm_subnet_network_security_group_association`
- `azurerm_public_ip` + `azurerm_network_interface`

No further guidance given.

---

### Component 2 — Key Vault Using RBAC Authorization

**File:** `main.tf`

This is different from every Key Vault you built in the NexaCore
series. Instead of `access_policy` blocks, Meridian requires
RBAC-based authorization.

**You must define `azurerm_key_vault`:**

- `name`, `location`, `resource_group_name` — as usual
- `sku_name = "standard"`
- `tenant_id = data.azurerm_client_config.current.tenant_id`
- `soft_delete_retention_days = 14` (MRB minimum, from MRB-001)
- `purge_protection_enabled = false` (for learning — allows clean re-apply)
- **`enable_rbac_authorization = true`** ← this is the key difference
- All eight MRB tags

**Notice what is MISSING compared to NCT-INFRA-004:**
No `access_policy {}` block at all. With RBAC authorization
enabled, permissions are granted entirely through
`azurerm_role_assignment` resources instead — the same
permission system used for every other Azure resource type.

**You still need a role assignment for YOURSELF** to create the
secret in the first place (Terraform runs as you):

```hcl
resource "azurerm_role_assignment" "your_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id          = data.azurerm_client_config.current.object_id
}
```

> "Key Vault Secrets Officer" can create, read, and delete secrets.
> This is what YOU need to run `terraform apply` successfully.
> The VM will get a DIFFERENT, more limited role — see Component 4.

**Add the secret** (same pattern as NCT-004):
```hcl
resource "azurerm_key_vault_secret" "db_connection" {
  name         = "db-connection-string"
  value        = "Server=mrb-sql;Database=mrbapp;Trusted_Connection=True;"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_role_assignment.your_kv_access]
}
```

> Notice the `depends_on` here points to the ROLE ASSIGNMENT, not
> just the vault. Without your role assignment being active first,
> Terraform (acting as you) cannot write the secret — same 403
> error pattern you saw with access policies in NCT-004, but now
> caused by a missing role assignment instead of a missing
> access policy.

---

### Component 3 — Linux VM with System-Assigned Managed Identity

**File:** `main.tf`

Build the VM exactly as you did in NCT-002 and NCT-004 — SSH key
auth, same `os_disk`, same `source_image_reference`. The ONLY
addition is the `identity {}` block.

**Add this block inside `azurerm_linux_virtual_machine`:**

```hcl
identity {
  type = "SystemAssigned"
}
```

That is the entire mechanism for turning the VM into its own
Azure AD identity. One block, three lines. Everything else about
the VM resource is unchanged from what you already know.

> After `terraform apply`, this VM will have a `principal_id`
> attribute — an automatically generated Azure AD object ID that
> represents the VM itself. You did not create this ID. Azure
> generated it the moment `identity { type = "SystemAssigned" }`
> was applied.

---

### Component 4 — Grant the VM's Identity Access to Key Vault

**File:** `main.tf`

This is the step that actually connects the VM to the Key Vault.
Without it, the VM has an identity, but that identity has no
permissions anywhere — an identity with no role assignment can
do nothing.

**You must define a second `azurerm_role_assignment`:**

```hcl
resource "azurerm_role_assignment" "vm_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id          = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}
```

**Break this down carefully:**

- `scope` — WHERE the permission applies. Here, the Key Vault.
- `role_definition_name` — WHAT permission is granted.
  `"Key Vault Secrets User"` can only READ secrets — it cannot
  create or delete them. This is intentionally more restrictive
  than the `"Key Vault Secrets Officer"` role you gave yourself.
- `principal_id` — WHO gets the permission. This references
  `azurerm_linux_virtual_machine.vm.identity[0].principal_id` —
  the VM's own automatically generated Azure AD identity.

> **Why `identity[0]`?** The `identity` attribute on a VM resource
> is technically a list (because Azure also supports
> User-Assigned identities, where a VM can have multiple). For
> System-Assigned identity, there is always exactly one entry, so
> you access it with `[0]`.

**The principle of least privilege in action:**
```
You (running Terraform)  →  "Key Vault Secrets Officer"  →  can manage secrets
VM (System Identity)      →  "Key Vault Secrets User"     →  can only READ secrets
```

The VM should never be able to create or delete secrets — only
read the one it needs. This is exactly how Meridian expects
permissions to be scoped in production.

---

### Component 5 — Variables and Outputs

**Files:** `variables.tf` and `outputs.tf`

**Variables to declare:**

```
org_prefix
environment
azure_location
resource_group_name
key_vault_name
vm_size
admin_username
allowed_ssh_ip
owner_name
cost_centre
data_classification
compliance_scope
```

**Outputs to expose:**

```
vm_name                    ← the VM name
vm_public_ip                ← for SSH access
vm_managed_identity_id      ← azurerm_linux_virtual_machine.vm.identity[0].principal_id
key_vault_uri                ← the vault's URL
key_vault_name               ← confirms which vault
resource_group_name          ← the RG name
```

> `vm_managed_identity_id` is a genuinely useful output — it lets
> anyone reviewing this project immediately see the VM's Azure AD
> identity without digging through the Azure Portal.

---

## 5. Hints & Pitfalls

### Hint 1 — You Cannot Prove Managed Identity Works From Terraform Alone

This is important to understand honestly. Terraform provisions
the VM, the identity, the Key Vault, and the role assignment —
but Terraform does not run CODE ON the VM. To actually SEE the
Managed Identity retrieve the secret, you would need to SSH into
the VM and run a command against Azure's metadata endpoint from
inside it.

**This project's definition of "done" is:**
- The VM has a `principal_id` (proven via `terraform output`)
- The role assignment exists (proven via Azure CLI)
- The infrastructure is CORRECTLY WIRED

**Optional — if you want to see it work live**, SSH into the VM
and run this (requires `curl` and `jq`, available by default on
Ubuntu 22.04):

```bash
# Run this FROM INSIDE the VM after SSH-ing in
curl -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" \
  | jq
```

If this returns a valid access token, the Managed Identity is
working end-to-end. This step is optional — understanding the
Terraform wiring is the actual learning objective of this ticket.

---

### Hint 2 — RBAC Role Propagation Can Take a Few Minutes

Unlike Key Vault access policies (which apply almost instantly),
RBAC role assignments can take **up to 5-10 minutes** to fully
propagate through Azure AD. If you test the Managed Identity
immediately after `terraform apply` completes and it fails with
a `403 Forbidden`, this is very likely why — not a configuration
error.

Wait a few minutes and try again before assuming something is
broken in your Terraform code.

---

### Hint 3 — Two Different Role Assignments, Easy to Confuse

This project has TWO `azurerm_role_assignment` resources, and
mixing up their `principal_id` is a very easy mistake:

```hcl
# Role assignment 1 — YOU (so Terraform can create the secret)
principal_id = data.azurerm_client_config.current.object_id

# Role assignment 2 — THE VM (so it can read the secret)
principal_id = azurerm_linux_virtual_machine.vm.identity[0].principal_id
```

If you accidentally use `data.azurerm_client_config.current.object_id`
for BOTH role assignments, the VM will never actually get access
— only you will have permission, and the VM's identity does nothing.
Double check which `principal_id` belongs to which resource before
applying.

---

## 6. Workflow (PowerShell — Windows + VS Code)

```powershell
cd C:\Projects\mrb-infra-002

$myIp = (Invoke-WebRequest https://api.ipify.org).Content.Trim()
Write-Host "Your IP: $myIp"
# Put this in terraform.tfvars as allowed_ssh_ip = "$myIp/32"

terraform init
terraform validate
terraform fmt
terraform plan
# Should show: RG, networking (6 resources), Key Vault, secret,
# 2 role assignments, VM with identity block

terraform apply
# Type: yes

# Verify the VM has a Managed Identity
terraform output vm_managed_identity_id
# Should print a GUID — this is the VM's Azure AD object ID

# Verify via Azure CLI
az vm identity show `
  --name mrb-dev-002-vm `
  --resource-group mrb-dev-002-rg `
  --output table

# Verify the role assignment exists
az role assignment list `
  --assignee (terraform output -raw vm_managed_identity_id) `
  --output table
# Expected: "Key Vault Secrets User" role listed

# Optional — SSH in and test the identity live (see Hint 1)
ssh -i ~/.ssh/id_rsa mrbadmin@(terraform output -raw vm_public_ip)

# Destroy when done
terraform destroy
# Type: yes

# Purge Key Vault
az keyvault purge `
  --name mrb-dev-002-kv `
  --location "East US"
```

---

## 7. Meridian Bank Code Review Checklist

```
[ ] Key Vault uses enable_rbac_authorization = true — NO access_policy block
[ ] Your own identity granted "Key Vault Secrets Officer" role
[ ] VM has identity { type = "SystemAssigned" } block
[ ] VM's identity granted "Key Vault Secrets User" role (read-only, least privilege)
[ ] Two SEPARATE role assignments — not the same principal_id used twice
[ ] Secret resource depends_on your role assignment (not the vault alone)
[ ] All 8 MRB tags present on every taggable resource
[ ] DataClassification = "confidential" (higher than MRB-001's "internal")
[ ] vm_managed_identity_id output returns a valid GUID after apply
[ ] Azure CLI confirms role assignment exists for the VM's identity
[ ] terraform destroy + Key Vault purge completed
```

---

## 8. The Concept That Changes Everything Going Forward

```
Every future Meridian project should ask this question first:

"Does this resource need to talk to another Azure resource?"

  YES  →  Can it use Managed Identity instead of a stored credential?
           If YES → use Managed Identity (MRB-002 pattern)
           If NO  → fall back to Key Vault + RBAC (MRB-001/002 pattern)
                    NEVER fall back to hardcoded credentials
```

This is the single biggest mindset shift of the Meridian series.
NexaCore taught you to store secrets properly. Meridian teaches
you to question whether a secret needs to exist at all.

---

## 9. What Comes Next

```
MRB-INFRA-001   ✅  Secure Storage + Compliance Baseline
MRB-INFRA-002   ✅  Azure AD + Managed Identity                  ← THIS PROJECT
MRB-INFRA-003   📋  Key Vault + RBAC for App Service
                     Same identity pattern, applied to App Service
                     instead of a VM — proves the concept generalizes
MRB-INFRA-004   📋  Private Networking + Standard Load Balancer
MRB-INFRA-005   📋  Traffic Manager + Routing Concepts
MRB-INFRA-006+  📋  Multi-Tier Architecture Design
```

---

## Cost Reference — This Project

```
Resource              SKU              Est. Cost (few hours, then destroy)
──────────────────────────────────────────────────────────────────────
Resource Group        Free             $0.00
Virtual Network        Free             $0.00
Subnet                 Free             $0.00
NSG                     Free             $0.00
Public IP               Standard         ~$0.01
NIC                     Free             $0.00
Linux VM                Standard_B1s     ~$0.02
Key Vault               Standard         ~$0.01 (few operations)
Role Assignments        Free             $0.00
──────────────────────────────────────────────────────────────────────
Total                                    Under $0.05
```

---

*Meridian Bank — Cloud Platform Engineering | Internal Training Material*
*MRB-INFRA-002 | Trainee Series | Windows + VS Code + PowerShell*
*CONFIDENTIAL — Internal Use Only*
