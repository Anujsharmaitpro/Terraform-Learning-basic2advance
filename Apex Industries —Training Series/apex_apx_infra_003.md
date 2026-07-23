# Apex Industries — Cloud Infrastructure Training Series
## Storage + Lifecycle Management Policy
**Project Code:** `APX-INFRA-003` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.00

---

> **From your Team Lead:** You've built storage accounts four
> times now across your training. This ticket adds ONE new piece
> — automatic file cleanup rules — and connects your Azure AD
> group from APX-002 to a real Azure resource for the first time.
> Nothing scary here — you already know both halves, this ticket
> just wires them together. — *Morgan Chen*

---

## Org Context
`dev` | `East US` | No dependencies — standalone | Cost: ~$0.00

---

## 1. Overview

### The One New Concept — Lifecycle Management Policy

Every storage account you've built so far keeps files forever
until someone manually deletes them. A **Lifecycle Management
Policy** automates that — it's a rule that says "if a file hasn't
been touched in X days, do Y to it automatically."

```
Example rule:
  IF a blob hasn't been modified in 30 days
  THEN move it to a cheaper storage tier automatically

Example rule:
  IF a blob hasn't been modified in 90 days
  THEN delete it automatically
```

This is genuinely common in real orgs — nobody wants to manually
review and clean up storage every month. You write the rule once,
Azure enforces it forever.

### The Second Piece — Connecting Your Two Provider Worlds

APX-001 and APX-002 built Azure AD objects (`azuread` provider) —
completely separate from Azure resources. This project draws the
line between them for the first time: your `azuread_group` from
APX-002 gets an RBAC role on THIS project's storage account,
proving that identity objects and resources genuinely connect —
this is what makes Azure AD useful in practice, not just an
abstract exercise.

```
Azure AD Group (built fresh in this project,
                 same pattern as APX-002)
       │
       │  RBAC role assignment
       ▼
Storage Account
   └── Lifecycle Policy: auto-delete blobs older than 90 days
```

### Reused, Now Connected Differently

| From | What | New Use Here |
|---|---|---|
| APX-002 | `azuread_group` pattern | Same resource, but now GRANTED a real role on Azure storage |
| NCT-001/003/008 | `azurerm_storage_account` | Same resource, now with a lifecycle policy attached |
| Every project | `azurerm_role_assignment` pattern (from MRB-002/003) | Reused exactly as before, just a different `scope` and `role_definition_name` |

---

## 2. Naming Convention

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-003-rg"
storage_account_name = "apxdev003storagejd"
group_name           = "apx-dev-storage-readers"
owner_name           = "sam-rivera"
```

---

## 3. Core Components

### Component 1 — Resource Group + Storage Account (Build From Memory)

You have built this exact resource type four times. Standard
settings: `account_tier = "Standard"`, `account_replication_type = "LRS"`.
No new guidance needed here.

### Component 2 — The Azure AD Group (Build From Memory, Same as APX-002)

```hcl
resource "azuread_group" "storage_readers" {
  display_name     = var.group_name
  security_enabled = true
}
```

> Notice: this group is STATIC this time (no `dynamic_membership`
> block) — deliberately simpler than APX-002's dynamic group,
> since the new learning in THIS project is the RBAC connection,
> not another group-membership variation. One new concept at a
> time, same discipline as always.

### Component 3 — The RBAC Connection (New Application of a Pattern You Know)

This is the piece that didn't exist in APX-001 or APX-002 — it's
what actually lets the group DO something with the storage account.

```hcl
resource "azurerm_role_assignment" "group_storage_access" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id           = azuread_group.storage_readers.object_id
}
```

**You already know this exact resource shape from MRB-002 and
MRB-003** — the only difference is what's being connected:

```
MRB-002:  VM's Managed Identity  →  role  →  Key Vault
MRB-003:  App Service's Identity →  role  →  Key Vault
APX-003:  Azure AD Group          →  role  →  Storage Account
```

Same `azurerm_role_assignment` resource, same three-argument
shape (`scope`, `role_definition_name`, `principal_id`) — just a
GROUP as the `principal_id` this time instead of a resource's own
Managed Identity. This is worth noticing explicitly: RBAC role
assignment is a completely general pattern — it doesn't care if
the thing receiving the role is a VM, an App Service, or a group
of humans.

> `"Storage Blob Data Reader"` is a built-in Azure role — anyone
> (or anything) with this role can READ blobs in the storage
> account but cannot write, delete, or modify anything. Any member
> of your `storage_readers` group would inherit this read-only
> access.

### Component 4 — The Lifecycle Management Policy (Genuinely New)

```hcl
resource "azurerm_storage_management_policy" "cleanup_policy" {
  storage_account_id = azurerm_storage_account.sa.id

  rule {
    name    = "auto-delete-old-blobs"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 90
      }
    }
  }
}
```

**Every piece explained:**

```hcl
rule {
  name    = "auto-delete-old-blobs"
  enabled = true
```
A policy can contain MULTIPLE rules (not used here, but the
`rule` block is repeatable if you needed different rules for
different blob prefixes later — the same "check if a block is
repeatable" instinct from the `dynamic` block guide applies here
too, though this project only uses one rule).

```hcl
  filters {
    blob_types = ["blockBlob"]
  }
```
This rule applies only to `blockBlob` type files — the standard
file type for most everyday blobs (documents, images, logs).
Azure Storage has other blob types (`appendBlob`, `pageBlob`) used
for specialized scenarios you're unlikely to hit as a beginner.

```hcl
  actions {
    base_blob {
      delete_after_days_since_modification_greater_than = 90
    }
  }
```
The actual rule logic: if a blob hasn't been MODIFIED in more
than 90 days, delete it automatically. `base_blob` refers to the
current/active version of a file (as opposed to a previous
version, if versioning were enabled — which it isn't in this
project, keeping it simple).

### Component 5 — Variables + Outputs

Outputs:
```
storage_account_name
group_object_id
lifecycle_policy_id
role_assignment_id
```

---

## 4. Hints

**Hint 1 — Lifecycle policies apply going forward, not
retroactively in a way you can immediately observe:** you won't
SEE any blob get deleted during this lab, because the storage
account is empty and even if it weren't, "90 days since
modification" won't trigger during a short session. This project
proves the RULE is correctly configured — not that a deletion has
actually happened. Verify success via the Azure CLI showing the
policy exists correctly, not by expecting to witness a deletion.

**Hint 2 — The RBAC role takes a few minutes to propagate, same
pattern as MRB-002/003:** if you check group permissions
immediately after `apply` and something looks off, this is very
likely propagation delay, not a configuration mistake. You've
seen this exact caveat before — it's a genuinely recurring Azure
behavior, not a one-off quirk.

**Hint 3 — `principal_id` works identically whether it's a group,
a user, or a Managed Identity:** this is the generalization worth
sitting with. Azure RBAC doesn't distinguish between "a person," "a
group of people," or "a piece of software" when granting access —
they're all just an `object_id` to the role assignment system. This
is why the exact same Terraform resource shape worked in MRB-002
(a VM's identity), MRB-003 (an App Service's identity), and now
here (a human group) — RBAC treats them all identically.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-003

terraform init
terraform validate
terraform fmt
terraform plan
terraform apply
# Type: yes

terraform state list
# Should show: RG, storage account, group, role assignment, lifecycle policy

# Verify the lifecycle policy
az storage account management-policy show `
  --account-name apxdev003storagejd `
  --resource-group apx-dev-003-rg `
  --output json

# Verify the role assignment
az role assignment list `
  --assignee (terraform output -raw group_object_id) `
  --output table
# Expected: "Storage Blob Data Reader" listed

terraform destroy
```

---

## 6. Checklist

```
[ ] Storage account built from memory — standard settings
[ ] Azure AD group is STATIC this time (no dynamic_membership)
[ ] Role assignment: scope = storage account, role = "Storage Blob Data Reader"
[ ] principal_id = the group's object_id, not a user or VM identity
[ ] Lifecycle policy: filters on blockBlob, base_blob action, 90-day threshold
[ ] terraform state list shows all 5 resource types
[ ] Azure CLI confirms role assignment and lifecycle policy both exist
[ ] terraform destroy completed
```

---

## 7. Cost
**~$0.00.** Empty Standard LRS storage account, no blobs uploaded.
Lifecycle policies and RBAC role assignments have zero direct
cost regardless of tier.

## Series Status
```
APX-001   ✅  Azure AD Fundamentals
APX-002   ✅  Dynamic Group Membership
APX-003   ✅  Storage + Lifecycle Policy + First AD-to-Resource Connection  ← THIS PROJECT
APX-004   📋  Networking Basics — VNet Peering
```

*Apex Industries — Cloud Platform Engineering | Training Series*
