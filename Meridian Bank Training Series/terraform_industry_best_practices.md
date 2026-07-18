# Terraform Industry Best Practices
## A Standalone Reference Guide — Habits Real Teams Actually Use
**Companion to: the for_each/dynamic guide | Applies from MRB-008 onward**

---

## Why This Guide Exists

Everything you've built so far has been correct Terraform. This
guide is not about correctness — it's about the habits that
separate "code that works" from "code a real team would accept
in a pull request." These are small disciplines, but skipping
them is exactly how technically-working infrastructure becomes
a liability six months later.

---

## PART 1 — Version Control Hygiene

### The `.gitignore` — Non-Negotiable

Every Terraform project needs one, before the first commit,
not after you accidentally commit a secret.

```gitignore
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.backup
*.tfvars
*.tfplan
crash.log
override.tf
override.tf.json
```

**Why each line matters:**

```
.terraform/          → downloaded provider binaries, huge, regenerable
.terraform.lock.hcl  → DEBATABLE — many teams DO commit this (see below)
*.tfstate             → contains real resource IDs and sometimes secrets in plain text
*.tfvars               → contains your actual passwords, IPs, account names
*.tfplan               → a saved plan can contain sensitive values
```

**Important exception — `terraform.lock.hcl`:** unlike everything
else in this list, many real teams DO commit this file. It locks
the exact provider version your team is using so everyone gets
identical behavior. If you remove it from `.gitignore`, that's a
deliberate, common choice — not a mistake.

---

## PART 2 — The Plan-Review-Apply Discipline

### The Habit You Have Been Skipping

Every project so far has taught you:
```
terraform plan
terraform apply
```

Two separate commands, run back to back. In real teams, this is
considered risky — between your `plan` and your `apply`, someone
else could have changed the underlying Azure state, or you might
mis-remember what the plan actually said.

### The Industry Standard — Saved Plan Files

```powershell
# Step 1: Save the plan to a file instead of just viewing it
terraform plan -out=tfplan

# Step 2: Review the saved file (can be done later, by someone else)
terraform show tfplan

# Step 3: Apply EXACTLY that saved plan — no surprises, no drift
terraform apply tfplan
```

**Why this matters:** `terraform apply tfplan` applies the EXACT
plan you reviewed — not a fresh plan generated at apply time. If
anything changed in Azure between your `plan` and `apply` steps,
Terraform will refuse to apply a stale plan rather than silently
doing something different from what you approved.

This is exactly how CI/CD pipelines work in real companies: a
pipeline generates the plan, a human or an automated policy
reviews it, then a separate step applies that specific, saved plan.

**Add `*.tfplan` to your `.gitignore`** — plan files can contain
sensitive values and should never be committed.

---

## PART 3 — Variable Validation

### The Problem Without Validation

```hcl
variable "environment" {
  type = string
}
```

Nothing stops someone from typing `"dev "` (trailing space),
`"Development"`, or `"prd"` instead of `"prod"`. The typo doesn't
fail until Azure rejects a malformed resource name, deep into
`terraform apply` — wasting time and giving a confusing error.

### The Industry Standard — `validation` Blocks

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment must be exactly one of: dev, stg, prod."
  }
}
```

Now, a typo fails INSTANTLY at `terraform plan` — before touching
Azure at all — with a clear, human-written error message instead
of a cryptic Azure API rejection five minutes into an apply.

**Another common example — validating a number range:**

```hcl
variable "soft_delete_days" {
  description = "Key Vault soft delete retention in days"
  type        = number

  validation {
    condition     = var.soft_delete_days >= 7 && var.soft_delete_days <= 90
    error_message = "soft_delete_days must be between 7 and 90."
  }
}
```

**And validating a string pattern (useful for names with strict rules):**

```hcl
variable "storage_account_name" {
  description = "Storage account name — lowercase alphanumeric, 3-24 chars"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase letters/numbers only."
  }
}
```

**Where to add validation going forward:** any variable with
strict rules (globally unique names, restricted character sets,
enum-like values such as `environment` or `data_classification`)
should get a `validation` block. Not every variable needs one —
adding it to `owner_name` for example, adds little value.

---

## PART 4 — Project Documentation

### Every Real Terraform Repo Has a README

Not extensive — but present. A missing README is one of the
fastest ways a pull request gets rejected in a real team, because
it means the next engineer has to reverse-engineer your intent
from the code alone.

**Minimum structure for every project going forward:**

```markdown
# Project Name

## What This Provisions
One paragraph — what gets created and why.

## Prerequisites
- Azure CLI logged in (`az login`)
- Terraform v1.6+
- SSH key at ~/.ssh/id_rsa.pub (if applicable)

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
Brief note — SKUs used, rough hourly/monthly cost.

## Known Limitations
Anything intentionally out of scope for this project.
```

From MRB-008 onward, every project spec will include a matching
`README.md` template you can drop directly into your project folder.

---

## PART 5 — Verifying Through Terraform Itself, Not Just Azure CLI

### The Habit You Have Been Building

Every project so far has taught Azure CLI verification commands
(`az webapp show`, `az sql server show`, etc.) — genuinely useful,
because they confirm Azure's actual state independent of Terraform.

### What Real Teams Also Do — Terraform's Own View

```powershell
# List every resource Terraform currently manages
terraform state list

# Show full details of ONE specific resource from state
terraform show

# Inspect one resource's current state in detail
terraform state show azurerm_linux_web_app.app_tier
```

**Why this matters:** Azure CLI tells you what EXISTS. Terraform
state tells you what TERRAFORM THINKS it manages. These can
drift apart — if someone manually changes a resource in the
Azure Portal, Azure CLI will show the manual change, but
Terraform's state will still show the OLD configuration until
your next `plan` detects the drift.

**A genuinely useful habit:** run `terraform plan` periodically
even when you don't intend to change anything. If it shows
unexpected changes, something outside Terraform touched your
infrastructure — a portal edit, a script, another engineer.

---

## PART 6 — Formatting and Validation as a Pre-Commit Habit

### What You Already Do

`terraform fmt` and `terraform validate` have been part of every
project's workflow section — but usually presented as steps right
before `apply`.

### The Industry Standard — Before Every Commit, Not Just Before Apply

```powershell
# Run this before EVERY git commit, not just before apply
terraform fmt -check -recursive
terraform validate
```

**The `-check` flag** makes `fmt` report problems WITHOUT
automatically fixing them — useful in a CI pipeline where you
want the build to fail loudly if someone forgot to format their
code, rather than silently auto-fixing and hiding the habit gap.

**The `-recursive` flag** checks every `.tf` file in every
subfolder — essential once you have a `modules/` folder, since
plain `terraform fmt` only checks the current directory.

Many real teams wire this into a **pre-commit hook** — a small
script that runs automatically every time you type `git commit`,
blocking the commit if formatting or validation fails. You don't
need to set this up for these lab projects, but knowing it exists
matters — it's genuinely common in professional repos.

---

## PART 7 — Naming Computed Once, Referenced Everywhere

### The Repetition You Have Been Living With

Across ten-plus projects, you've likely typed patterns like this
repeatedly:

```hcl
name = "${var.org_prefix}-${var.environment}-${var.workload}-rg"
```

Reasonable in a small project. Starts to hurt once the same
prefix pattern needs to be reused across 8-10 resources in one
file — any inconsistency (a missed hyphen, wrong variable order)
creates naming drift between resources.

### The Industry Standard — Compute Once in `locals`

```hcl
locals {
  name_prefix = "${var.org_prefix}-${var.environment}-${var.workload}"

  # Every resource name built from the SAME base string
  rg_name    = "${local.name_prefix}-rg"
  vnet_name  = "${local.name_prefix}-vnet"
  kv_name    = "${local.name_prefix}-kv"
  # ...
}
```

You already used this exact pattern inside the module in
NCT-INFRA-003 and NCT-INFRA-010. **Going forward, this becomes
the default for every project, not just modules** — every root
config should compute its naming prefix once in `locals`, and
every resource name should reference `local.name_prefix`, never
rebuild the string inline.

---

## PART 8 — Provider Version Pinning — The Reasoning, Not Just the Rule

### What You've Been Told

```hcl
required_providers {
  azurerm = {
    source  = "hashicorp/azurerm"
    version = "~> 3.0"
  }
}
```

### Why This Actually Matters

The `~>` operator means "allow patch and minor updates, but never
a major version bump." `~> 3.0` allows `3.1`, `3.45`, `3.99` — but
blocks `4.0`.

**The real-world reason:** Azure provider major versions
sometimes rename arguments, change default values, or remove
deprecated features entirely (you already saw a small example of
this in MRB-001's `enable_https_traffic_only` deprecation warning).
If your `required_providers` block has NO version constraint at
all, a `terraform init` run six months from now could silently
pull in a breaking major version update — and your previously
working `.tf` files might fail to apply, or worse, apply
successfully but with different behavior than you intended.

**Pinning is not paranoia — it's how real teams avoid infrastructure
that "worked yesterday, broken today" with no code changes on
their end.**

---

## PART 9 — Cost Estimation as a Practice, Not Just a Note

### What I've Been Doing For You

Every project spec has included a "Cost" section with my own
estimate. That's useful, but real teams don't estimate costs by
hand — they use tools built for it.

### Tools Worth Knowing Exist

```
Azure Pricing Calculator    → https://azure.microsoft.com/pricing/calculator
                              Manually build out a cost estimate for a set of resources

Infracost                    → https://www.infracost.io
                              Reads your actual .tf files and produces a cost
                              breakdown automatically — the closest thing to
                              "terraform plan, but for cost" that exists

az cost management (CLI)     → Query real historical spend from your account
```

**You don't need to install Infracost for these lab projects** —
but knowing it exists, and that real infrastructure teams often
run it as part of their CI pipeline (so a pull request shows
"this change adds $47/month" automatically) is worth having in
your mental map of the industry.

---

## Quick Reference — What Changes From MRB-008 Onward

```
┌──────────────────────────────────────────────────────────────┐
│  Every project going forward will include:                    │
│                                                                │
│  1. .gitignore in the file structure section                  │
│  2. terraform plan -out=tfplan / apply tfplan in the workflow  │
│  3. At least one validation{} block on a strict-format variable│
│  4. A README.md template alongside the project spec            │
│  5. terraform state list / terraform show as a verify step     │
│  6. Naming computed once via locals.name_prefix                │
└──────────────────────────────────────────────────────────────┘
```

None of this changes WHAT you're building — same Azure resources,
same core Terraform concepts. It changes HOW you build it, so the
habits feel automatic by the time you're doing this professionally.

---

*This guide is a standalone reference — revisit it any time you
want to double check whether a project you're building follows
these practices. Applies to both the NexaCore and Meridian series
retroactively where you'd like to improve older projects, and to
every new project going forward.*
