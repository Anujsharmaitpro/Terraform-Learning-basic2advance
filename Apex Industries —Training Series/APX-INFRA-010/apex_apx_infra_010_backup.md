# Apex Industries — Cloud Infrastructure Training Series
## Backup & Disaster Recovery — Recovery Services Vault
**Project Code:** `APX-INFRA-010` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: ~$0.10/session

---

> **From your Team Lead:** Every project so far has been about
> building things. This ticket is about protecting what you've
> already built. Every single org — startup, bank, retailer,
> hospital — has to answer "what happens if this VM gets deleted
> or corrupted?" This is that answer, and it's genuinely one of
> the most universally required skills in cloud infrastructure.
> — *Morgan Chen*

---

## 1. Overview — Genuinely New Territory

### What a Recovery Services Vault Actually Is

Every resource you've built until now was about running
something. A Recovery Services Vault is different — its entire
job is to hold POINT-IN-TIME COPIES of other resources, so you
can restore them if something goes wrong.

```
Recovery Services Vault (apx-dev-010-rsv)
  └── Backup Policy: "back up this VM once a day, keep for 7 days"
        └── Protected VM: apx-dev-010-vm
              └── Recovery Points: snapshots taken over time,
                    each one a restorable version of the VM
```

### The New Concept — Backup Is a Relationship, Not a Setting

Unlike most resources you've built (where a single resource
block does one thing), backup involves THREE resources working
together, each with a distinct job:

```
azurerm_recovery_services_vault
  → the CONTAINER — where all backup data lives

azurerm_backup_policy_vm
  → the SCHEDULE — how often, and how long to keep backups

azurerm_backup_protected_vm
  → the RELATIONSHIP — which specific VM uses which specific policy
```

Think of it like a photo backup service: the vault is your cloud
storage account, the policy is "back up my photos folder nightly,
keep 30 days," and the protected VM is the actual folder you've
pointed at that policy. All three pieces exist independently but
only work together when connected.

### What You Are Building

```
Recovery Services Vault (apx-dev-010-rsv)
  Backup Policy: daily, 7-day retention
    │
    ▼
  Protects: apx-dev-010-vm (a simple Linux VM, built from memory)
    │
    ▼
  First backup triggered manually → creates a real recovery point
    → you can see it, verify it exists, and understand exactly
      what a restore would use
```

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_virtual_network` + `azurerm_subnet`,
`azurerm_network_security_group`, `azurerm_public_ip`,
`azurerm_network_interface`, `azurerm_linux_virtual_machine` — the
full VM stack from NCT-002/MRB-002/MRB-004. Build this entirely
from memory; this project's guidance is only for the backup pieces.

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-010-rg` |
| VM (the thing being backed up) | `apx-dev-010-vm` |
| Recovery Services Vault | `apx-dev-010-rsv` |
| Backup Policy | `apx-dev-010-backup-policy` |

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-010-rg"
vm_size                = "Standard_B1s"
admin_username           = "apxadmin"
allowed_ssh_ip             = "YOUR_PUBLIC_IP/32"
owner_name                   = "sam-rivera"
backup_retention_days          = 7
```

---

## 3. Core Components

### Component 1 — VM + Networking (Build From Memory)

Standard networking stack + one `Standard_B1s` Linux VM with SSH
key auth. No new guidance.

### Component 2 — Recovery Services Vault

```hcl
resource "azurerm_recovery_services_vault" "rsv" {
  name                = "${local.name_prefix}-rsv"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  sku                    = "Standard"

  soft_delete_enabled = true

  tags = local.common_tags
}
```

**Every argument explained:**

```hcl
sku = "Standard"
```
This is the ONLY SKU available for Recovery Services Vaults —
there's no "Basic" or "Free" tier equivalent for this resource
type. Cost is driven by how much data you actually store and how
often backups run, not by the SKU itself.

```hcl
soft_delete_enabled = true
```
If a backup is accidentally deleted, it's retained for a further
period (14 days by default) before permanent removal — the same
safety-net philosophy you've seen with Key Vault's
`soft_delete_retention_days` and Storage's lifecycle policies,
applied here to backup data specifically.

### Component 3 — Backup Policy — The Schedule

```hcl
resource "azurerm_backup_policy_vm" "policy" {
  name                = "${local.name_prefix}-backup-policy"
  resource_group_name  = azurerm_resource_group.rg.name
  recovery_vault_name    = azurerm_recovery_services_vault.rsv.name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time        = "23:00"
  }

  retention_daily {
    count = var.backup_retention_days
  }
}
```

**Every argument explained:**

```hcl
backup {
  frequency = "Daily"
  time        = "23:00"
}
```
Defines WHEN backups happen. `frequency` can also be `"Weekly"`.
`time` is a 24-hour clock string, in the `timezone` specified
above — this policy takes a backup every day at 11 PM UTC.

```hcl
retention_daily {
  count = var.backup_retention_days
}
```
Defines HOW LONG each daily backup is kept before Azure
automatically deletes it. With `count = 7`, you'll always have
roughly the last 7 daily backups available, with older ones aging
out automatically — no manual cleanup needed, similar philosophy
to Storage's lifecycle policy from APX-003.

### Component 4 — Protected VM — Connecting the VM to the Policy

```hcl
resource "azurerm_backup_protected_vm" "protected" {
  resource_group_name  = azurerm_resource_group.rg.name
  recovery_vault_name    = azurerm_recovery_services_vault.rsv.name
  source_vm_id             = azurerm_linux_virtual_machine.vm.id
  backup_policy_id           = azurerm_backup_policy_vm.policy.id
}
```

> This is the resource that actually links everything together.
> Without it, you'd have a Vault and a Policy that exist
> independently, and a VM that isn't backed up by anything — the
> same category of mistake as forgetting an NSG association or a
> backend pool association earlier in this series. The connection
> resource is what makes the relationship real.

### Component 5 — Variables + Outputs

```hcl
variable "backup_retention_days" {
  description = "Number of daily backups to retain"
  type        = number
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 30
    error_message = "backup_retention_days must be between 1 and 30 for this lab."
  }
}
```

Outputs:
```
vault_name
vm_name
backup_policy_id
```

---

## 4. Hints

**Hint 1 — Terraform sets up the SCHEDULE, it doesn't trigger a
backup immediately:** after `terraform apply`, no backup has
actually run yet — the policy will fire at its next scheduled
time (11 PM UTC in this project's config). To see a real recovery
point during your lab session, you need to trigger an ON-DEMAND
backup manually via Azure CLI (shown in the workflow below) —
this is normal, expected behavior, not something Terraform is
supposed to do for you.

**Hint 2 — The first backup of any VM is always a "full" backup
and takes longer than you'd expect:** even for a small
`Standard_B1s` VM, the first on-demand backup can take 10-20
minutes to complete, because Azure has to copy the entire disk
for the first time. Subsequent backups are incremental and much
faster. Don't assume something is broken if the first backup
takes a while.

**Hint 3 — `azurerm_backup_protected_vm` will fail if the VM and
Vault are in different regions:** this is an Azure hard
requirement — the Recovery Services Vault must be in the SAME
region as the VM it's protecting. If you see a region-mismatch
error, check that `azure_location` is used consistently for both.

---

## 5. Workflow (PowerShell) — Including a Real Triggered Backup

```powershell
cd C:\Projects\apx-infra-010

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

terraform state list
# Should show: VM + networking, recovery vault, backup policy,
# protected VM association

# Verify the vault and policy exist
az backup vault show --name apx-dev-010-rsv --resource-group apx-dev-010-rg --output table
az backup policy list --vault-name apx-dev-010-rsv --resource-group apx-dev-010-rg --output table

# Confirm the VM is registered as protected
az backup item list `
  --vault-name apx-dev-010-rsv `
  --resource-group apx-dev-010-rg `
  --output table
# Expected: apx-dev-010-vm listed, protection state "Protected"

# TRIGGER A REAL, ON-DEMAND BACKUP — this is the actual test
az backup protection backup-now `
  --vault-name apx-dev-010-rsv `
  --resource-group apx-dev-010-rg `
  --container-name apx-dev-010-vm `
  --item-name apx-dev-010-vm `
  --backup-management-type AzureIaasVM `
  --output table

# This returns a Job ID — check on it
az backup job list `
  --vault-name apx-dev-010-rsv `
  --resource-group apx-dev-010-rg `
  --output table
# Watch the "Status" column — will show "InProgress" then "Completed"
# (can take 10-20 minutes for the first backup — see Hint 2)

# ONCE COMPLETE — verify a real recovery point now exists
az backup recoverypoint list `
  --vault-name apx-dev-010-rsv `
  --resource-group apx-dev-010-rg `
  --container-name apx-dev-010-vm `
  --item-name apx-dev-010-vm `
  --backup-management-type AzureIaasVM `
  --output table
```

**What you should see:** at least one recovery point, with a real
timestamp — proof that an actual, restorable snapshot of your VM
now exists in the vault. This is the tangible "I built something
real" outcome for this project — a genuine, restorable backup you
created and can point to.

```powershell
terraform destroy
```

> **Note on destroy order:** Terraform will handle removing the
> protection relationship and policy before the vault itself —
> same automatic dependency-ordering behavior you've relied on
> throughout this series. If `terraform destroy` fails with a
> vault-not-empty error, it usually means a backup job was still
> running; wait for it to complete and destroy again.

---

## 6. Checklist

```
[ ] Recovery Services Vault created, sku = "Standard"
[ ] Backup Policy defines frequency + retention_daily
[ ] azurerm_backup_protected_vm links the VM to the policy
[ ] VM and Vault are in the SAME azure_location
[ ] backup_retention_days has a validation{} block (1-30 range)
[ ] az backup item list confirms the VM shows as "Protected"
[ ] On-demand backup triggered manually via CLI
[ ] At least one recovery point confirmed via CLI after the backup completes
[ ] terraform destroy completed (after backup job finishes)
```

---

## 7. Cost
`Standard_B1s` VM (~$0.02/hr) + Recovery Services Vault (charged
per GB of backup data stored — for one small VM's first backup,
typically a few cents). **A lab session including one triggered
backup: well under $0.20.**

## Series Status
```
APX-009   ✅  Traffic Manager + QR Generator
APX-010   ✅  Backup & Disaster Recovery — Recovery Services Vault  ← THIS PROJECT
APX-011   📋  Azure Files + NAT Gateway
```

---

## Why This Replaced the Original Capstone Plan

The original roadmap had APX-010 repeating MRB-010's full
multi-tier + App Gateway architecture a second time. That pattern
had already appeared in MRB-006 through MRB-010, then again in
APX-007 through APX-009 — four repetitions was past the point of
useful reinforcement. Backup & Disaster Recovery is genuinely new
territory, genuinely universal across every type of org, and
genuinely low-cost — exactly the direction worth prioritizing
before circling back to repeat architecture patterns.

*Apex Industries — Cloud Platform Engineering | Training Series*
