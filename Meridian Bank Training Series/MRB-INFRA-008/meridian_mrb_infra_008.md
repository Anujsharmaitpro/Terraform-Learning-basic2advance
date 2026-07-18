# Meridian Bank — Cloud Infrastructure Training Series
## Azure Policy — Enforce Compliance Automatically
**Project Code:** `MRB-INFRA-008` | **Level:** Intermediate | **Frequency:** Common in regulated orgs
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: Free

---

> **From your Team Lead:** Every checklist you've manually
> ticked off since MRB-001 — all 8 tags present, TLS 1.2 minimum,
> no public storage access — has relied on YOU remembering to
> check it. That doesn't scale, and it doesn't survive a new
> engineer joining who hasn't read every ticket in this series.
>
> Azure Policy makes compliance a property of the platform, not
> a property of the engineer. Once assigned, Azure itself refuses
> to create a resource that violates the policy — Terraform,
> the Portal, the CLI, anything. This ticket is short but
> important. — *Rohan Mehta*

---

## Org Context
`dev` | `East US` | `CC-CLOUD-001` | Fully standalone

---

## 1. Overview

**A custom Azure Policy definition requiring the `DataClassification`
tag on every resource, assigned to a Resource Group — then proven
by attempting to create a non-compliant resource and watching
Azure reject it.**

```
Policy Definition (mrb-require-data-classification)
  "Every resource in scope MUST have a DataClassification tag"
         │
         ▼
Policy Assignment
  Applied to: Resource Group mrb-dev-008-rg
         │
         ▼
Test: Storage Account WITHOUT the tag
  → Azure rejects it before Terraform can even finish creating it
Test: Storage Account WITH the tag
  → Succeeds normally
```

### The New Concept — Policy as Code, Enforced by the Platform

Every previous project relied on a checklist you personally
followed. Azure Policy is fundamentally different — it's a rule
Azure itself evaluates at the moment ANY resource is created,
regardless of who or what is creating it.

```
Old model:  Engineer follows a checklist  →  hopefully compliant
New model:  Azure evaluates every request  →  provably compliant
```

### New Terraform Resources

| Resource | Purpose |
|---|---|
| `azurerm_policy_definition` | The rule itself — what to check, what to do if violated |
| `azurerm_resource_group_policy_assignment` | Applies that rule to a specific scope |

### Reused Without Guidance
`azurerm_resource_group`, `azurerm_storage_account` (used only as
the test subject to prove the policy works).

---

## 2. Best Practices Applied in This Project

### `.gitignore`

```gitignore
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
*.tfplan
crash.log
```

### File Structure

```
mrb-infra-008/
├── providers.tf
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── .gitignore
└── README.md
```

### README.md Template

```markdown
# MRB-INFRA-008 — Azure Policy Enforcement

## What This Provisions
A custom Azure Policy requiring the DataClassification tag on
all resources in the target Resource Group, plus a test Storage
Account proving the policy is enforced.

## Prerequisites
- Azure CLI logged in (az login)
- Terraform v1.6+
- Owner or Resource Policy Contributor role on the subscription

## How to Run
​```powershell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
​```

## How to Destroy
​```powershell
terraform destroy
​```

## Estimated Cost
Free — Azure Policy has no charge. Test Storage Account is
Standard LRS, negligible.

## Known Limitations
Policy uses "Deny" effect for missing tags — does not auto-append
default tags (that would use the "Modify" effect, out of scope
for this beginner+ exercise).
```

---

## 3. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `mrb-dev-008-rg` |
| Policy Definition | `mrb-require-data-classification` |
| Policy Assignment | `mrb-dev-008-policy-assignment` |
| Test Storage Account | `mrbdev008teststoragejd` |

Same 8 MRB tags on the RG and test resource.
`DataClassification = "internal"`.

```hcl
# terraform.tfvars
org_prefix                  = "mrb"
environment                 = "dev"
azure_location               = "East US"
resource_group_name          = "mrb-dev-008-rg"
test_storage_account_name    = "mrbdev008teststoragejd"
owner_name                   = "alex-morgan"
cost_centre                  = "CC-CLOUD-001"
data_classification          = "internal"
compliance_scope             = "internal-audit"
required_tag_name            = "DataClassification"
```

---

## 4. Core Components

### Component 1 — Resource Group (with validation, per best practices)

```hcl
locals {
  name_prefix = "${var.org_prefix}-${var.environment}-008"

  common_tags = {
    Project             = "MRB-INFRA-008"
    Environment         = var.environment
    Owner               = var.owner_name
    ManagedBy           = "terraform"
    CostCentre          = var.cost_centre
    Team                = "cloud-platform"
    DataClassification  = var.data_classification
    ComplianceScope     = var.compliance_scope
  }
}

variable "data_classification" {
  description = "MRB data sensitivity classification"
  type        = string

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}
```

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${local.name_prefix}-rg"
  location = var.azure_location
  tags     = local.common_tags
}
```

### Component 2 — The Policy Definition

This is the core of the ticket — the actual rule, written in
Azure Policy's own JSON-based rule language, embedded inside
Terraform using `jsonencode()`.

```hcl
resource "azurerm_policy_definition" "require_tag" {
  name         = "mrb-require-data-classification"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "MRB: Require DataClassification tag"
  description  = "Denies creation of any resource missing the DataClassification tag."

  policy_rule = jsonencode({
    if = {
      field  = "tags['${var.required_tag_name}']"
      exists = "false"
    }
    then = {
      effect = "deny"
    }
  })
}
```

**Break this down piece by piece:**

- `policy_type = "Custom"` — you're writing your own rule, not
  using one of Azure's hundreds of built-in policies.
- `mode = "Indexed"` — this policy only evaluates resource types
  that actually support tags (skips resources like subnets, which
  you already know from NCT-002 don't support tags at all).
- `policy_rule` — the actual logic, written as a JSON structure
  Terraform builds using `jsonencode()`. Read it like an if/then
  statement:
  ```
  IF   the resource's tags do NOT contain a key called
       "DataClassification"
  THEN deny the request entirely
  ```

> **Why `jsonencode()` instead of writing raw JSON as a string?**
> `jsonencode()` takes a normal HCL object (the `if`/`then`
> structure above) and correctly converts it to valid JSON,
> handling escaping and formatting automatically. Writing raw
> JSON as a quoted string is fragile — a single misplaced quote
> breaks the whole policy silently.

### Component 3 — The Policy Assignment

A definition alone does nothing — it must be ASSIGNED to a scope
(a subscription, a resource group, or a management group) before
Azure starts enforcing it.

```hcl
resource "azurerm_resource_group_policy_assignment" "assign_policy" {
  name                 = "mrb-dev-008-policy-assignment"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.require_tag.id
  display_name          = "Enforce DataClassification tag in mrb-dev-008-rg"
}
```

> **Scope matters enormously here.** This assignment targets
> `azurerm_resource_group.rg.id` — meaning enforcement applies
> ONLY within this one resource group. A real bank would assign
> similar policies at the SUBSCRIPTION level so nothing anywhere
> can slip through — but scoping tightly to one RG for this
> exercise means you won't accidentally block yourself from
> creating resources elsewhere while learning.

### Component 4 — Test Storage Account (Compliant)

```hcl
resource "azurerm_storage_account" "test_sa" {
  name                     = var.test_storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type = "LRS"

  tags = local.common_tags   # includes DataClassification — will pass

  depends_on = [azurerm_resource_group_policy_assignment.assign_policy]
}
```

> `depends_on` here ensures the policy assignment is fully active
> BEFORE Terraform attempts to create the storage account —
> otherwise there's a race condition where the storage account
> might be created a moment before the policy is actually
> enforcing, making your test meaningless.

### Component 5 — Variables + Outputs

Outputs:
```
policy_definition_id
policy_assignment_id
test_storage_account_name
resource_group_name
```

---

## 5. Hints

**Hint 1 — Policy propagation can take several minutes, same as
RBAC from MRB-002:** if you test immediately after `terraform
apply` and the policy doesn't seem to be enforcing yet, this is
almost always propagation delay, not a broken policy definition.
Wait 5-10 minutes before concluding something is wrong.

**Hint 2 — To actually SEE the policy reject something, you need
to manually test it separately from your main apply:** your
`terraform.tfvars`-driven `test_sa` resource is intentionally
COMPLIANT (it has the tag) so your main `terraform apply` succeeds
cleanly. To witness an actual denial, temporarily comment out the
`tags` line on a throwaway resource and run `terraform plan` +
`terraform apply` — Azure will reject it with a clear policy
violation error. Remember to revert the change afterward.

**Hint 3 — `mode = "Indexed"` vs `mode = "All"`:** if you set
`mode = "All"`, the policy tries to evaluate every resource type,
including ones that don't support tags (like subnets) — causing
confusing false evaluation attempts. `"Indexed"` is the correct
choice specifically for tag-based policies; it automatically
skips non-taggable resource types.

---

## 6. Workflow (PowerShell — With Best Practices Applied)

```powershell
cd C:\Projects\mrb-infra-008

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan          # review before applying
terraform apply tfplan

# Verify with Terraform's own state, not just Azure CLI
terraform state list
terraform state show azurerm_policy_definition.require_tag

# Verify via Azure CLI
az policy definition show `
  --name mrb-require-data-classification `
  --output table

az policy assignment list `
  --resource-group mrb-dev-008-rg `
  --output table

# Confirm the test storage account is compliant
az policy state list `
  --resource-group mrb-dev-008-rg `
  --query "[].{Resource:resourceId, Compliance:complianceState}" `
  --output table
# Expected: Compliant

# OPTIONAL — witness an actual denial (see Hint 2)
# Temporarily add a resource WITHOUT the DataClassification tag,
# run terraform plan -out=tfplan2, then terraform apply tfplan2
# Expected: Azure rejects with a policy violation error

terraform destroy
```

---

## 7. Checklist

```
[ ] .gitignore present, includes *.tfplan
[ ] README.md present with all required sections
[ ] data_classification variable has a validation{} block
[ ] Naming computed once via locals.name_prefix
[ ] Used terraform plan -out=tfplan / apply tfplan (not bare apply)
[ ] policy_rule built with jsonencode(), not a raw JSON string
[ ] mode = "Indexed" (not "All")
[ ] Policy assignment depends_on used before the test resource
[ ] terraform state list run as a verification step
[ ] Azure CLI confirms policy assignment exists and test SA is Compliant
[ ] terraform destroy completed
```

---

## 8. Cost
**Free.** Azure Policy has zero cost regardless of how many
policies or assignments you create. The only cost in this
project is the test Storage Account — negligible LRS pricing,
destroy after the lab session as always.

## Series Status
```
MRB-001 to 007   ✅  Foundations through Multi-Tier + Private Endpoint
MRB-008          ✅  Azure Policy — automated compliance      ← THIS PROJECT
MRB-009          📋  Application Gateway ⚠️ (cost exception)
MRB-010          📋  Full Capstone
```

*Meridian Bank — Cloud Platform Engineering | CONFIDENTIAL*
