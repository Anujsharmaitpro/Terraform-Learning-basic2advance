# Apex Industries — Cloud Infrastructure Training Series
## Governance Trio — Resource Locks, Cost Budgets, Built-In Policy
**Project Code:** `APX-INFRA-013` | **Level:** Beginner+++ | **Frequency:** Used everywhere
**Environment:** Windows + VS Code + PowerShell | Fully self-contained | Cost: Free

---

> **From your Team Lead:** Three genuinely different governance
> controls in one ticket — all free, all things almost every org
> sets up before anything else touches production. A lock that
> stops accidental deletion. A budget that emails someone before
> spend gets out of hand. And this time, a BUILT-IN Azure Policy
> instead of the custom one you wrote in MRB-008 — showing you
> both approaches exist. — *Morgan Chen*

---

## 1. Overview — Three New Concepts

### Concept 1 — Resource Locks

A lock is the simplest governance control that exists: it makes a
resource (or an entire Resource Group) immune to accidental
deletion or modification, regardless of who's trying, including
someone with full Owner permissions.

```
CanNotDelete lock  -> resource can be modified, but NEVER deleted
ReadOnly lock          -> resource can be viewed, but NEVER
                          modified OR deleted
```

```hcl
resource "azurerm_management_lock" "rg_lock" {
  name       = "prevent-accidental-deletion"
  scope      = azurerm_resource_group.rg.id
  lock_level = "CanNotDelete"
  notes        = "Locked to prevent accidental deletion during the lab"
}
```

> **Important for THIS lab specifically:** you must REMOVE this
> lock before terraform destroy will work — a CanNotDelete
> lock blocks Terraform's own deletion attempt exactly as it would
> block a human's. This is intentional and correct behavior — see
> Hint 1 for the actual destroy sequence.

### Concept 2 — Cost Budgets

A budget doesn't PREVENT spending — it ALERTS when spending
crosses a threshold you define. This is the practical, everyday
governance tool most orgs actually rely on, since Azure has no
native "hard stop spending at $X" mechanism for most resource
types.

```hcl
resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = "apx-dev-013-budget"
  resource_group_id  = azurerm_resource_group.rg.id

  amount     = 10
  time_grain   = "Monthly"

  time_period {
    start_date = "2026-01-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold        = 80
    operator            = "GreaterThan"
    threshold_type          = "Actual"
    contact_emails               = [var.alert_email]
  }
}
```

**Every argument explained:**

```hcl
amount     = 10
time_grain   = "Monthly"
```
The budget ceiling — $10/month, resetting every month
automatically. This maps directly to your actual $5-10/month
learning budget from earlier in this series — this is the
Terraform-native version of that manual discipline.

```hcl
notification {
  threshold        = 80
  operator            = "GreaterThan"
  threshold_type          = "Actual"
  contact_emails               = [var.alert_email]
}
```
"When ACTUAL spend this month exceeds 80% of the $10 budget
(i.e. $8), email this address." You can define multiple
notification blocks at different thresholds (50%, 80%, 100%) —
this project uses one for simplicity.

### Concept 3 — Built-In Azure Policy (Different From MRB-008)

MRB-008 taught you to WRITE a custom policy from scratch using
azurerm_policy_definition + jsonencode(). This project uses a
different, equally common approach: assigning one of Azure's
hundreds of PRE-WRITTEN built-in policies, which requires no
policy_rule authoring at all — just a reference to Microsoft's
existing definition.

```hcl
data "azurerm_policy_definition" "require_location" {
  display_name = "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "location_policy" {
  name                 = "apx-dev-013-location-policy"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition.require_location.id

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = ["East US", "West US"]
    }
  })
}
```

> "Allowed locations" is one of Azure's most commonly used
> built-in policies — it restricts WHICH regions resources can be
> created in. Notice you're using a data source to LOOK UP an
> existing policy definition by name (built-in policies already
> exist in every tenant), then only writing the parameters block
> yourself — a much smaller amount of code than authoring a custom
> policy_rule from scratch.

**When to use built-in vs custom, the real-world guidance:**
```
Built-in policy    -> use whenever Azure already has one that
                       fits — hundreds exist covering tags,
                       locations, SKUs, naming, encryption, etc.
Custom policy        -> only when no built-in policy matches your
                          exact requirement (like MRB-008's specific
                          DataClassification tag requirement)
```

---

## 2. Naming + Tags

| Resource | Name |
|---|---|
| Resource Group | `apx-dev-013-rg` |
| Resource Lock | `prevent-accidental-deletion` |
| Cost Budget | `apx-dev-013-budget` |
| Policy Assignment | `apx-dev-013-location-policy` |

```hcl
# terraform.tfvars
org_prefix           = "apx"
environment          = "dev"
azure_location       = "East US"
resource_group_name  = "apx-dev-013-rg"
owner_name           = "sam-rivera"
alert_email             = "your-email@example.com"
budget_amount             = 10
```

---

## 3. Core Components

### Component 1 — Resource Group (Build From Memory)

Standard RG. This project also creates a small test resource
(reuse a Storage Account from APX-003) so the lock and policy have
something real to demonstrate against.

### Component 2 — Resource Lock

```hcl
resource "azurerm_management_lock" "rg_lock" {
  name       = "prevent-accidental-deletion"
  scope      = azurerm_resource_group.rg.id
  lock_level = "CanNotDelete"
  notes        = "Locked to prevent accidental deletion during the lab"
}
```

### Component 3 — Cost Budget

```hcl
variable "alert_email" {
  description = "Email address to notify when the budget threshold is crossed"
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget ceiling in USD"
  type        = number
  validation {
    condition     = var.budget_amount >= 1 && var.budget_amount <= 50
    error_message = "budget_amount should stay within your actual learning budget (1-50)."
  }
}

resource "azurerm_consumption_budget_resource_group" "budget" {
  name              = "${local.name_prefix}-budget"
  resource_group_id  = azurerm_resource_group.rg.id

  amount     = var.budget_amount
  time_grain   = "Monthly"

  time_period {
    start_date = "2026-01-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold        = 80
    operator            = "GreaterThan"
    threshold_type          = "Actual"
    contact_emails               = [var.alert_email]
  }
}
```

### Component 4 — Built-In Policy Assignment

Build exactly as shown in the Overview section — data
"azurerm_policy_definition" to look up "Allowed locations", then
azurerm_resource_group_policy_assignment with a parameters
block restricting to your two chosen regions.

### Component 5 — Test Resource (Reuse APX-003's Storage Account)

Build one simple azurerm_storage_account to demonstrate the
lock and policy against — no lifecycle policy needed this time,
just the base resource.

### Component 6 — Outputs

```
lock_id
budget_id
policy_assignment_id
resource_group_name
```

---

## 4. Hints

**Hint 1 — You MUST remove the lock before terraform destroy
will succeed:** the CanNotDelete lock blocks Terraform's own
deletion attempt, exactly as it would block a human clicking
delete in the Portal. The correct sequence is:

```powershell
terraform destroy -target=azurerm_management_lock.rg_lock
terraform destroy
```

This two-step destroy is a genuinely new pattern — every previous
project in this series used a single terraform destroy. Locks
are the first resource type where destroy order actually requires
manual sequencing rather than Terraform figuring it out
automatically (since the lock's entire purpose is to resist
exactly that automatic behavior).

**Hint 2 — Budget alerts take up to 24 hours to reflect real
spend, this is an Azure platform limitation:** you will NOT see
your budget's notification fire during a short lab session — cost
data isn't real-time. This project's success criteria is
confirming the budget CONFIGURATION is correct via CLI, not
witnessing a live alert fire.

**Hint 3 — data "azurerm_policy_definition" requires an EXACT
display name match:** "Allowed locations" must be typed exactly,
including capitalization — a slight variation returns no result
and terraform plan fails with a clear "could not find policy
definition" error. If you want to explore other built-in policies,
az policy definition list --query "[].displayName" shows you the
exact strings Azure expects.

---

## 5. Workflow (PowerShell)

```powershell
cd C:\Projects\apx-infra-013

terraform init; terraform validate; terraform fmt
terraform plan -out=tfplan
terraform apply tfplan

# Verify the lock exists
az lock list --resource-group apx-dev-013-rg --output table

# Try to delete the resource group via CLI — should be BLOCKED
az group delete --name apx-dev-013-rg --yes --no-wait
# Expected: an error citing the CanNotDelete lock

# Verify the budget configuration
az consumption budget list --output table

# Verify the policy assignment
az policy assignment list --resource-group apx-dev-013-rg --output table

# Try creating a resource in a DISALLOWED region — should be BLOCKED
az storage account create `
  --name apxdev013testwesteurope `
  --resource-group apx-dev-013-rg `
  --location "West Europe" `
  --sku Standard_LRS
# Expected: rejected by the "Allowed locations" policy

# DESTROY — TWO STEPS, LOCK FIRST
terraform destroy -target=azurerm_management_lock.rg_lock
terraform destroy
```

**What you should see:** a deletion attempt genuinely blocked by
the lock, and a resource creation attempt genuinely blocked by
the location policy — two real, negative-test proofs that the
governance controls are actually enforcing something, not just
existing as configuration.

---

## 6. Checklist

```
[ ] Resource Lock: lock_level = "CanNotDelete", scoped to the RG
[ ] Cost Budget: amount uses var.budget_amount, has validation{}
[ ] Budget notification threshold = 80, operator = "GreaterThan"
[ ] Policy uses a data source lookup — NOT a custom policy_rule
[ ] Policy parameters restrict to specific allowed regions
[ ] Attempted deletion via CLI genuinely blocked by the lock
[ ] Attempted out-of-region resource creation genuinely blocked by policy
[ ] Two-step destroy used: lock removed first, then everything else
[ ] terraform destroy completed
```

---

## 7. Cost
**Free.** Resource Locks, Cost Budgets, and Policy Assignments all
have zero direct cost. The one test Storage Account created is
negligible LRS pricing, destroyed at the end of the session.

## Series Status
```
APX-012   VMSS Autoscale
APX-013   Governance Trio — Locks, Budgets, Built-In Policy  <- THIS PROJECT
APX-014   Terraform Workspaces
```

---

## What Changes Starting Next Project

APX-013 closes out the "new resource territory" arc of this
series. APX-014 and APX-015 shift focus entirely — no new Azure
resource types, purely Terraform WORKFLOW skills (Workspaces,
CI/CD) applied to configs you've already built.

*Apex Industries — Cloud Platform Engineering | Training Series*
