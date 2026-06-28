# Terraform File Structure & Best Practices
## Deep-Dive Learning Guide — Day 6 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure Examples | PowerShell Commands Throughout

---

## Before You Start

This is Day 6. By now you know:
- Day 1: What Terraform is and why it exists
- Day 2: What providers are and version constraints
- Day 3: Writing resources, dependencies, authentication
- Day 4: State file and remote backends
- Day 5: Input, output, and local variables

Today is about **organisation**. You've been writing everything into one
`main.tf` file. That works for learning, but it becomes unmanageable fast.
This video shows how to split everything into the right files — the way
professional Terraform engineers structure every project.

---

## Table of Contents

1. The Problem with One Big File
2. The Professional File Structure — Overview
3. The Golden Rule: How Terraform Loads Files
4. File 1 — `provider.tf` (or `versions.tf`)
5. File 2 — `backend.tf`
6. File 3 — `variables.tf`
7. File 4 — `locals.tf`
8. File 5 — `main.tf` (or per-resource files)
9. File 6 — `outputs.tf`
10. File 7 — `terraform.tfvars`
11. Why Each File Exists Separately — The Team Perspective
12. File Load Order — Alphabetical and What That Means
13. Dependencies Revisited — Implicit vs Explicit
14. Using Variables Inside Locals — The Right Pattern
15. The Full Project — Every File Written Out
16. What Goes in `.gitignore`
17. Common Mistakes Beginners Make
18. Practice Exercises
19. Complete Cheat Sheet

---

## 1. The Problem with One Big File

Look at what a single `main.tf` looks like after only a few resources:

```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tf-state-rg"
    storage_account_name = "tfstateaccount"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "location" {
  type    = string
  default = "West Europe"
}

locals {
  common_tags = {
    Environment = var.environment
    LOB         = "Banking"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_resource_group" "example" {
  name     = "rg-example-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "example" {
  name                     = "myapp${var.environment}stg"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

output "storage_account_name" {
  value = azurerm_storage_account.example.name
}
```

This is already 60+ lines for just two resources. Real projects have
50–200 resources. A single file would become thousands of lines — impossible
to navigate, review, or maintain.

### The specific problems

```
Problem 1 — Navigation:
  "Where is the backend configuration?" → grep through 1000 lines

Problem 2 — Code review:
  "What changed in this pull request?" → every change is in one file,
  making it impossible to see if backend, variables, AND resources all changed

Problem 3 — Team conflicts:
  Developer A edits the variable section
  Developer B edits the resource section
  Git reports a merge conflict in main.tf — even though they touched
  completely different things

Problem 4 — Maintenance:
  "Which files do I need to edit to add a new environment variable?"
  → Can't answer without reading the whole file

Problem 5 — Onboarding:
  A new team member asks "where's the provider config?" → no clear answer
```

The solution is to split the file into purpose-specific files. Each file
has one job. You always know where to look.

---

## 2. The Professional File Structure — Overview

Here is the standard structure the instructor builds toward:

```
project-root/
│
├── provider.tf          ← provider + required_version
├── backend.tf           ← remote state backend configuration
├── variables.tf         ← all input variable definitions
├── locals.tf            ← all local variable definitions
├── main.tf              ← main resources (or split per resource type)
├── resource_group.tf    ← (optional) dedicated file per resource type
├── storage_account.tf   ← (optional) dedicated file per resource type
├── outputs.tf           ← all output variable definitions
│
├── terraform.tfvars     ← default variable values (non-sensitive)
│
├── .terraform/          ← auto-created by terraform init (don't edit)
├── .terraform.lock.hcl  ← version lock file (commit to Git)
│
└── .gitignore           ← files Git should not track
```

Each file has a **single responsibility**. You always know which file
to open for which concern.

---

## 3. The Golden Rule: How Terraform Loads Files

Before splitting files, you must understand one critical rule:

> **Terraform reads ALL `.tf` files in the current directory and treats
> them as ONE single configuration. File names and file order do NOT matter.**

This means:

```
You can name files anything ending in .tf
You can put blocks in any order within files
You can reference a variable defined in variables.tf from main.tf
You can reference a resource from resource_group.tf in storage_account.tf
```

Terraform merges everything in memory before processing. To Terraform,
there is no difference between one big `main.tf` and ten separate files.
The split is purely for human readability and team workflow.

### What file types Terraform loads automatically

```
File pattern              Loaded by
────────────────────────  ────────────────────────────────
*.tf                      Always loaded (all .tf files)
terraform.tfvars          Always loaded (variable values)
*.auto.tfvars             Always loaded (variable values)
terraform.tfvars.json     Always loaded (variable values)
*.auto.tfvars.json        Always loaded (variable values)
```

Everything else (like `.txt`, `.sh`, `.json` without auto prefix) is ignored.

---

## 4. File 1 — `provider.tf` (also called `versions.tf`)

**Purpose:** Declares which Terraform version is required and which
providers are needed, plus configures those providers.

**Why separate?** This file almost never changes. Once you set your
provider version and required Terraform version, you only touch this
file when deliberately upgrading. Keeping it separate means code
reviewers can immediately see if a PR is accidentally changing provider
versions.

```hcl
# provider.tf

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Authentication via ARM_* environment variables:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}
```

### Naming convention

The instructor said you can call it either `provider.tf` or `versions.tf`.
Both are common in the industry. HashiCorp's own modules tend to use
`versions.tf`. Many teams prefer `provider.tf` because it's more descriptive.
Either works — just be consistent within a project.

---

## 5. File 2 — `backend.tf`

**Purpose:** Tells Terraform where to store the state file (remote backend).

**Why separate?** The backend configuration is infrastructure-level
configuration — it's about HOW Terraform operates, not WHAT it builds.
It rarely changes. Separating it means you never accidentally modify
your remote state settings when editing resource configuration.

```hcl
# backend.tf

terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state-day6"
    storage_account_name = "day6tfstate17834"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
```

### The critical syntax note the instructor hit

The `backend` block MUST be nested inside a `terraform { }` block.
You cannot place it at the top level of a `.tf` file on its own:

```hcl
# ❌ WRONG — backend at top level causes an error
backend "azurerm" {
  resource_group_name = "tf-state-day6"
  ...
}

# ✅ CORRECT — backend nested inside terraform { }
terraform {
  backend "azurerm" {
    resource_group_name = "tf-state-day6"
    ...
  }
}
```

The instructor encountered exactly this error during the demo and fixed
it by wrapping the backend block inside `terraform { }`.

### What about splitting `terraform { }` across files?

You might wonder: "I have `terraform { required_providers... }` in
`provider.tf` and `terraform { backend... }` in `backend.tf` — is that
allowed?"

**Yes.** Terraform merges multiple `terraform { }` blocks from different
files into one. So having the required_providers in `provider.tf` and
the backend in `backend.tf` is perfectly valid and is exactly what the
instructor does.

---

## 6. File 3 — `variables.tf`

**Purpose:** Defines all input variables — their names, types, descriptions,
and default values.

**Why separate?** This is the file people read first when they want to
know "what inputs does this Terraform project accept?" It's like the
function signature — it tells you everything you need to pass in.
Keeping it separate means anyone new to the project can understand
what's configurable without reading all the resources.

```hcl
# variables.tf

variable "environment" {
  type        = string
  description = "Deployment environment name (dev, staging, prod)"
  default     = "staging"
}

variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "West Europe"
}

variable "project" {
  type        = string
  description = "Short project name used in resource naming"
  default     = "myapp"
}

variable "account_replication_type" {
  type        = string
  description = "Storage account replication type (LRS, GRS, ZRS)"
  default     = "LRS"
}
```

### What goes in `variables.tf` vs NOT in `variables.tf`

```
YES — variables.tf:
  variable definitions (type, description, default, sensitive)
  ALL input variables for the project

NO — variables.tf:
  Actual values (those go in terraform.tfvars)
  Locals (those go in locals.tf)
  Outputs (those go in outputs.tf)
```

---

## 7. File 4 — `locals.tf`

**Purpose:** Defines all local values — computed values, constants, and
complex data structures like common tag maps.

**Why separate?** Locals are the internal logic of your Terraform project.
They often reference variables and compute derived values. Keeping them
separate makes it easy to see "what computed values does this project use?"
without digging through resource configuration.

```hcl
# locals.tf

locals {
  # Computed name prefix — used in all resource names
  name_prefix = "${var.project}-${var.environment}"

  # Common tags applied to every resource
  # Combines input variables with constants
  common_tags = {
    Environment = var.environment     # from input variable — changes per env
    Project     = var.project         # from input variable — changes per project
    LOB         = "Banking"           # constant — never changes
    Stage       = "Alpha"             # constant — changes rarely
    ManagedBy   = "Terraform"         # constant — always the same
  }

  # Computed storage account name (must be lowercase, no hyphens)
  storage_account_name = lower(
    replace("${var.project}${var.environment}stg", "-", "")
  )
}
```

### The key insight from the video — using variables INSIDE locals

The instructor demonstrated that you CAN reference `var.*` inside locals.
This is a powerful pattern:

```hcl
locals {
  common_tags = {
    Environment = var.environment    # ← var reference inside locals
    Project     = var.project        # ← var reference inside locals
    LOB         = "Banking"          # ← hardcoded constant
  }
}
```

This means:
- The tag value changes when `var.environment` changes
- You don't hardcode the environment name twice (once in the variable,
  once in the local)
- You get the flexibility of variables WITH the reusability of locals

---

## 8. File 5 — `main.tf` and Per-Resource Files

**Purpose:** Contains your actual Azure infrastructure resource definitions.

**Two approaches — both are valid:**

### Approach A — Everything in `main.tf`

Fine for small projects (under 10 resources):

```hcl
# main.tf — all resources in one file
resource "azurerm_resource_group" "example" { ... }
resource "azurerm_storage_account" "example" { ... }
resource "azurerm_virtual_network" "example" { ... }
```

### Approach B — Separate file per resource type (recommended for larger projects)

The instructor creates separate files:

```
resource_group.tf      ← azurerm_resource_group resources
storage_account.tf     ← azurerm_storage_account resources
virtual_network.tf     ← azurerm_virtual_network resources
virtual_machine.tf     ← azurerm_linux_virtual_machine resources
```

This makes it trivial to find where a specific resource is defined.
When a team member says "I'm adding a new virtual network," you know
exactly which file they're working in — reducing merge conflicts.

### The resource files

```hcl
# resource_group.tf
resource "azurerm_resource_group" "example" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}
```

```hcl
# storage_account.tf
resource "azurerm_storage_account" "example" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  tags                     = local.common_tags
}
```

Notice that `storage_account.tf` references `azurerm_resource_group.example`
which is defined in `resource_group.tf`. This is perfectly fine — Terraform
merges all files and resolves cross-file references automatically.

---

## 9. File 6 — `outputs.tf`

**Purpose:** Defines all output values that Terraform prints after apply
and exposes for use by other modules or CI/CD pipelines.

**Why separate?** Outputs are the "API" of your Terraform module — what
it returns to the outside world. Keeping them in one file means anyone
integrating with this project can read `outputs.tf` to see what values
are available without reading all the resource code.

```hcl
# outputs.tf

output "resource_group_name" {
  description = "Name of the created Resource Group"
  value       = azurerm_resource_group.example.name
}

output "resource_group_id" {
  description = "Azure Resource ID of the Resource Group"
  value       = azurerm_resource_group.example.id
}

output "storage_account_name" {
  description = "Name of the created Storage Account"
  value       = azurerm_storage_account.example.name
}

output "storage_primary_blob_endpoint" {
  description = "Primary blob endpoint URL"
  value       = azurerm_storage_account.example.primary_blob_endpoint
}

output "applied_environment" {
  description = "The environment tag applied to all resources"
  value       = local.common_tags.environment
}
```

---

## 10. File 7 — `terraform.tfvars`

**Purpose:** Provides actual values for your input variables for the
default/current environment.

**Why separate from `variables.tf`?** `variables.tf` defines the shape
of variables (what's accepted). `terraform.tfvars` provides the actual
values. This split lets you have one `variables.tf` that never changes,
and multiple `.tfvars` files for different environments.

```hcl
# terraform.tfvars

environment              = "staging"
location                 = "West Europe"
project                  = "bankingapp"
account_replication_type = "LRS"
```

### Multiple environment files pattern

```
terraform.tfvars          ← default (staging/dev)
prod.tfvars               ← production overrides
dr.tfvars                 ← disaster recovery overrides
```

**PowerShell — run for different environments:**
```powershell
# Default (uses terraform.tfvars automatically)
terraform plan

# Production
terraform plan -var-file="prod.tfvars"

# Disaster Recovery
terraform plan -var-file="dr.tfvars"
```

---

## 11. Why Each File Exists Separately — The Team Perspective

This is the "why" the instructor explained. When working in a team, code
changes go through **pull requests** (PRs) — one person makes a change,
another reviews it before it's merged.

Here's why file separation makes PRs dramatically easier to review:

### Scenario: Developer adds a new tag to all resources

**Without file separation:**
```
Changed file: main.tf (+5 lines)
Reviewer has to read through hundreds of lines to find
the 5-line tag change buried in the middle.
```

**With file separation:**
```
Changed file: locals.tf (+1 line to common_tags)
Reviewer immediately knows: "This person touched only the locals.
They added a tag. Nothing else changed."
```

### Scenario: DevOps engineer upgrades provider version

**Without file separation:**
```
Changed file: main.tf
Reviewer: "What else did they change? I need to check every resource..."
```

**With file separation:**
```
Changed file: provider.tf (version bump)
Reviewer: "Only the provider version changed. Simple approval."
```

### The frequency-of-change principle

Different files change at different rates. Organise them by how often
they change:

```
Almost never changes:
  backend.tf     ← set once, rarely touched
  provider.tf    ← only when upgrading versions

Changes occasionally:
  variables.tf   ← when adding new configurable options
  locals.tf      ← when adding new computed values
  outputs.tf     ← when exposing new values

Changes regularly:
  *.tf (resources) ← when adding/modifying infrastructure
  terraform.tfvars ← when adjusting environment values
```

This structure means a junior engineer editing resources never needs to
open `backend.tf` — and if they do, it's a red flag that something unusual
is happening.

---

## 12. File Load Order — Alphabetical and What That Means

Terraform loads `.tf` files in **alphabetical order by filename** within
a directory.

```
Load order for our project:
  1. backend.tf
  2. locals.tf
  3. outputs.tf
  4. provider.tf
  5. resource_group.tf
  6. storage_account.tf
  7. variables.tf
```

### Does this mean resources are CREATED in alphabetical order?

**No.** The load order determines when Terraform READS the files, not
when it CREATES resources. The creation order is determined entirely by
the **dependency graph** — what depends on what.

But there IS a potential issue the instructor highlighted:

### The alphabetical ordering trap

```
Suppose you have:
  a_storage_account.tf   ← contains azurerm_storage_account
  r_resource_group.tf    ← contains azurerm_resource_group

Alphabetically: a_storage_account.tf loads first.

The storage account depends on the resource group.
If Terraform tries to create them in the order loaded... would it fail?
```

**Answer:** Not if you use implicit dependency.

```hcl
resource "azurerm_storage_account" "example" {
  resource_group_name = azurerm_resource_group.example.name  # ← implicit dependency
  location            = azurerm_resource_group.example.location
}
```

Because `storage_account.tf` REFERENCES `azurerm_resource_group.example`,
Terraform knows the Resource Group must be created first — regardless of
which file loaded first.

The load order matters for: catching syntax errors early, and in very
edge cases with circular dependencies. For normal use, the dependency
graph handles creation order.

### When alphabetical order CAN cause problems

If you hardcode values instead of using references:

```hcl
# storage_account.tf — DANGEROUS if resource group doesn't exist yet
resource "azurerm_storage_account" "example" {
  resource_group_name = "rg-example-staging"    # ← hardcoded!
  # No implicit dependency! Terraform doesn't know RG must come first.
}
```

If the resource group is still being created when Terraform tries to
create the storage account, you get an error. The fix is always to use
references — which creates implicit dependencies.

---

## 13. Dependencies Revisited — Implicit vs Explicit

The instructor revisited this from Day 3 in the context of file structure.
Here is the full explanation:

### Implicit Dependency — Always Prefer This

Created automatically when you reference one resource's attribute inside
another resource:

```hcl
# resource_group.tf
resource "azurerm_resource_group" "example" {
  name     = "rg-example-staging"
  location = "West Europe"
}

# storage_account.tf — references resource_group.example → implicit dependency
resource "azurerm_storage_account" "example" {
  name                = "myappstagingstg"
  resource_group_name = azurerm_resource_group.example.name      # ← reference
  location            = azurerm_resource_group.example.location  # ← reference
  account_tier        = "Standard"
  account_replication_type = "LRS"
}
```

Terraform reads `azurerm_resource_group.example.name` and understands:
"I need `azurerm_resource_group.example` to exist before I can create
`azurerm_storage_account.example`."

Result: Resource Group is always created first. Automatically. No matter
what file order or alphabetical order applies.

### Explicit Dependency — Use Only When You Must

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "myappstagingstg"
  resource_group_name      = "rg-example-staging"   # hardcoded — no implicit dep
  location                 = "West Europe"           # hardcoded
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [
    azurerm_resource_group.example    # ← manually declare the dependency
  ]
}
```

Use `depends_on` only when:
- You can't use a reference (the relationship isn't expressed in any attribute)
- A resource depends on a side effect of another resource, not its output
  (e.g., "wait for this firewall rule to be applied before creating the VM")

### The recommendation

```
Default choice:  implicit dependency (via references)
  → less code, self-documenting, Terraform manages it automatically

Fallback choice: explicit dependency (via depends_on)
  → when implicit isn't possible
  → adds noise, makes intent less clear
```

---

## 14. Using Variables Inside Locals — The Right Pattern

The instructor demonstrated this during the demo. This pattern is one
of the most useful in real Terraform projects.

### The pattern

```hcl
# variables.tf — user provides this
variable "environment" {
  type    = string
  default = "staging"
}

variable "project" {
  type    = string
  default = "bankingapp"
}

# locals.tf — Terraform computes this internally
locals {
  common_tags = {
    Environment = var.environment    # ← reads from input variable
    Project     = var.project        # ← reads from input variable
    LOB         = "Banking"          # ← constant
    ManagedBy   = "Terraform"        # ← constant
  }
}

# storage_account.tf — uses the computed local
resource "azurerm_storage_account" "example" {
  ...
  tags = local.common_tags           # ← uses the local
}
```

### Why this is better than alternatives

```
Alternative A — var directly in resource (no local):
  tags = {
    Environment = var.environment    ← must repeat in every resource
    LOB         = "Banking"          ← must repeat in every resource
  }
  Problem: 40 resources = 40 copies of the same tag block

Alternative B — hardcoded in local:
  locals {
    common_tags = {
      Environment = "staging"        ← hardcoded, won't change with var
    }
  }
  Problem: Can't pass different environment values at deploy time

Pattern from video (var inside local):
  locals {
    common_tags = {
      Environment = var.environment  ← dynamic (from user)
      LOB         = "Banking"        ← static (never changes)
    }
  }
  Best of both: dynamic where needed, static where appropriate
               defined once, used everywhere
```

### What the instructor proved

After adding `Environment = var.environment` inside the locals block,
running `terraform plan` with `terraform.tfvars` containing
`environment = "from file"` showed the tag value as `"from file"` —
confirming that variables pass through to locals correctly.

---

## 15. The Full Project — Every File Written Out

Here is the complete, professional file structure from this video:

**PowerShell — create the project structure:**
```powershell
# Create the project directory
New-Item -ItemType Directory -Path "day06"
Set-Location "day06"

# Create all the empty files
New-Item -ItemType File -Name "provider.tf"
New-Item -ItemType File -Name "backend.tf"
New-Item -ItemType File -Name "variables.tf"
New-Item -ItemType File -Name "locals.tf"
New-Item -ItemType File -Name "resource_group.tf"
New-Item -ItemType File -Name "storage_account.tf"
New-Item -ItemType File -Name "outputs.tf"
New-Item -ItemType File -Name "terraform.tfvars"
```

---

**`provider.tf`**
```hcl
# provider.tf
# Purpose: Declare required Terraform version and providers
# Change frequency: Rare — only when upgrading versions

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Authentication: set ARM_* environment variables in PowerShell:
  # $env:ARM_CLIENT_ID       = "..."
  # $env:ARM_CLIENT_SECRET   = "..."
  # $env:ARM_TENANT_ID       = "..."
  # $env:ARM_SUBSCRIPTION_ID = "..."
}
```

---

**`backend.tf`**
```hcl
# backend.tf
# Purpose: Configure remote state storage in Azure Blob Storage
# Change frequency: Rarely — set once per project
# NOTE: backend block MUST be inside terraform { }

terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state-day6"
    storage_account_name = "day6tfstate17834"   # ← replace with your value
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
```

---

**`variables.tf`**
```hcl
# variables.tf
# Purpose: Define all input variables (shape and defaults)
# Change frequency: When adding new configurable options

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "staging"
}

variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "West Europe"
}

variable "project" {
  type        = string
  description = "Short project name for resource naming"
  default     = "bankingapp"
}

variable "account_replication_type" {
  type        = string
  description = "Storage account replication type (LRS, GRS, ZRS, GZRS)"
  default     = "LRS"
}
```

---

**`locals.tf`**
```hcl
# locals.tf
# Purpose: Define computed values and reusable data structures
# Change frequency: Occasional — when adding new computed values

locals {
  # Computed resource name prefix
  name_prefix = "${var.project}-${var.environment}"

  # Storage account name — must be lowercase, 3-24 chars, no hyphens
  storage_account_name = lower(
    replace("${var.project}${var.environment}stg", "-", "")
  )

  # Common tags applied to all resources
  # Mixes dynamic variables with static constants
  common_tags = {
    Environment = var.environment      # dynamic — from input variable
    Project     = var.project          # dynamic — from input variable
    LOB         = "Banking"            # static constant
    Stage       = "Alpha"              # static constant
    ManagedBy   = "Terraform"          # static constant
  }
}
```

---

**`resource_group.tf`**
```hcl
# resource_group.tf
# Purpose: Azure Resource Group — container for all project resources
# Change frequency: Rarely — RG config is usually stable

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}
```

---

**`storage_account.tf`**
```hcl
# storage_account.tf
# Purpose: Azure Storage Account for application data
# Change frequency: When modifying storage configuration

resource "azurerm_storage_account" "example" {
  name = local.storage_account_name

  # Implicit dependency on resource_group.tf:
  # Terraform creates the Resource Group BEFORE this storage account
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location

  account_tier             = "Standard"
  account_replication_type = var.account_replication_type

  tags = local.common_tags
}
```

---

**`outputs.tf`**
```hcl
# outputs.tf
# Purpose: Expose values after apply — for CI/CD or module consumers
# Change frequency: When adding new values for downstream systems

output "resource_group_name" {
  description = "Name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "resource_group_id" {
  description = "Azure Resource ID of the Resource Group"
  value       = azurerm_resource_group.example.id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.example.name
}

output "storage_primary_blob_endpoint" {
  description = "Primary blob endpoint URL"
  value       = azurerm_storage_account.example.primary_blob_endpoint
}

output "common_tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}
```

---

**`terraform.tfvars`**
```hcl
# terraform.tfvars
# Purpose: Default values for this environment
# Change frequency: When deploying to a different environment

environment              = "staging"
location                 = "West Europe"
project                  = "bankingapp"
account_replication_type = "LRS"
```

---

**PowerShell — full run sequence:**
```powershell
# Authenticate to Azure
az login

# Set Service Principal credentials (for non-interactive auth)
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# 1. Download providers and connect to backend
terraform init

# 2. Validate all .tf files for syntax errors
terraform validate

# 3. Preview changes
terraform plan

# 4. Preview with production values
terraform plan -var-file="prod.tfvars"

# 5. Preview with inline override
terraform plan -var="environment=dev"

# 6. Apply
terraform apply --auto-approve

# 7. View outputs
terraform output

# 8. View specific output
terraform output storage_account_name

# 9. Clean up
terraform destroy --auto-approve

# 10. Unset credentials when done
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 16. What Goes in `.gitignore`

When you commit your Terraform project to Git, some files must never
be committed:

```
# .gitignore for Terraform projects

# Provider binaries — large binary files, OS-specific, regenerated by terraform init
.terraform/

# State files — contain sensitive data (access keys, passwords, IDs)
terraform.tfstate
terraform.tfstate.backup

# Variable files that may contain secrets
# Decide per file — non-sensitive tfvars CAN be committed
*.tfvars.json

# Override files — local developer overrides, not for sharing
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Terraform plan output files
*.tfplan

# macOS junk
.DS_Store
```

**Files you SHOULD commit:**
```
✅ *.tf files            — your infrastructure code
✅ .terraform.lock.hcl  — version lock file (ensures team consistency)
✅ terraform.tfvars      — IF it contains only non-sensitive defaults
✅ *.auto.tfvars         — IF non-sensitive
```

**PowerShell — create the .gitignore:**
```powershell
@"
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
*.tfplan
.DS_Store
"@ | Out-File -FilePath ".gitignore" -Encoding utf8
```

---

## 17. Common Mistakes Beginners Make

### Mistake 1 — Putting `backend` block outside `terraform { }`

```hcl
# ❌ Wrong — backend at the top level
backend "azurerm" {
  resource_group_name = "tf-state-rg"
  ...
}

# ✅ Correct — backend inside terraform { }
terraform {
  backend "azurerm" {
    resource_group_name = "tf-state-rg"
    ...
  }
}
```

This is the exact error the instructor hit in the demo. The error message
Terraform gives is confusing if you don't know this rule.

---

### Mistake 2 — Thinking files load in the order you expect

```
You think: provider.tf loads first, then main.tf, then outputs.tf
Reality:    backend.tf, locals.tf, main.tf, outputs.tf, provider.tf
            (alphabetical order)

But this doesn't matter! Terraform merges all files before doing anything.
Don't try to control load order — use dependencies instead.
```

---

### Mistake 3 — Splitting the terraform block incorrectly

```hcl
# provider.tf — this is fine ✅
terraform {
  required_version = ">= 1.9.0"
  required_providers { ... }
}

# backend.tf — this is also fine ✅ (multiple terraform blocks allowed)
terraform {
  backend "azurerm" { ... }
}
```

But you CANNOT have TWO `required_providers` blocks:

```hcl
# provider.tf — first required_providers
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

# backend.tf — second required_providers ← ERROR
terraform {
  required_providers {
    random = { source = "hashicorp/random" }  # ❌ duplicate block
  }
}
```

Keep all providers in ONE file (`provider.tf`). Only the backend goes
in `backend.tf`.

---

### Mistake 4 — Writing `locals.` (with a dot) when defining

```hcl
# ❌ Wrong — "locals." with dot doesn't work as definition
locals. {
  common_tags = { ... }
}

# ✅ Correct — "locals" followed directly by opening brace
locals {
  common_tags = { ... }
}
```

And when REFERENCING, use `local.` (singular without s):

```hcl
tags = local.common_tags    # ✅ singular "local" with dot
tags = locals.common_tags   # ❌ "locals" doesn't work as reference
```

---

### Mistake 5 — Hardcoding in resources when locals are available

```hcl
# ❌ Inconsistent — some use locals, some hardcode
resource "azurerm_resource_group" "example" {
  tags = local.common_tags    # uses local
}

resource "azurerm_storage_account" "example" {
  tags = {
    Environment = "staging"   # hardcoded — out of sync if var changes!
    LOB         = "Banking"
  }
}

# ✅ Consistent — all use locals
resource "azurerm_resource_group" "example" {
  tags = local.common_tags
}

resource "azurerm_storage_account" "example" {
  tags = local.common_tags
}
```

---

### Mistake 6 — Not running `terraform init` after adding `backend.tf`

After creating `backend.tf` in a folder that previously had no backend:

```powershell
# ❌ Skipping init — will get confusing errors
terraform plan   # Error: Backend initialisation required

# ✅ Always init after backend changes
terraform init   # Downloads providers, connects to new backend
terraform plan   # Now works
```

---

## 18. Practice Exercises

### Exercise 1 — File Identification

For each item below, identify which file it belongs in:

```
a) provider "azurerm" { features {} }
b) variable "environment" { type = string }
c) output "storage_name" { value = azurerm_storage_account.example.name }
d) locals { common_tags = { Env = var.environment } }
e) backend "azurerm" { resource_group_name = "..." }
f) resource "azurerm_resource_group" "example" { ... }
g) environment = "production"    ← just this line, key=value format
```

**Answers:**
```
a) provider.tf
b) variables.tf
c) outputs.tf
d) locals.tf
e) backend.tf (inside terraform { })
f) resource_group.tf (or main.tf)
g) terraform.tfvars  (or prod.tfvars)
```

---

### Exercise 2 — Fix the Broken Backend

Find and fix ALL errors:

```hcl
# backend.tf
backend "azurerm" {
  resource_group_name  = "tf-state"
  storage_account_name = "mystateaccount"
  container_name       = "tfstate"
  key                  = "terraform.tfstate"
}
```

**Answer:**
```hcl
# backend.tf — FIXED: backend must be inside terraform { }
terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state"
    storage_account_name = "mystateaccount"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"   # also improved key name
  }
}
```

---

### Exercise 3 — Build the Full Structure

Starting from scratch, write the PowerShell commands to:
1. Create a folder called `day06-practice`
2. Navigate into it
3. Create all 7 standard Terraform files

**Answer:**
```powershell
New-Item -ItemType Directory -Path "day06-practice"
Set-Location "day06-practice"

$files = @(
  "provider.tf",
  "backend.tf",
  "variables.tf",
  "locals.tf",
  "resource_group.tf",
  "storage_account.tf",
  "outputs.tf",
  "terraform.tfvars"
)

foreach ($file in $files) {
  New-Item -ItemType File -Name $file
  Write-Host "Created: $file"
}
```

---

### Exercise 4 — Implicit vs Explicit Dependency

Rewrite this to use implicit dependency instead of explicit:

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "myappstorage001"
  resource_group_name      = "rg-myapp-staging"      # hardcoded
  location                 = "West Europe"            # hardcoded
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [azurerm_resource_group.example]
}
```

**Answer:**
```hcl
resource "azurerm_storage_account" "example" {
  name = "myappstorage001"

  # Implicit dependency — resource group is created first automatically
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  # No depends_on needed — implicit dependency handles it
}
```

---

## 19. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║        TERRAFORM FILE STRUCTURE — DAY 6 QUICK REFERENCE                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  STANDARD FILE STRUCTURE                                                     ║
║                                                                              ║
║  provider.tf        required_version + required_providers + provider {}     ║
║  backend.tf         terraform { backend "azurerm" { ... } }                 ║
║  variables.tf       all variable "name" { } definitions                     ║
║  locals.tf          locals { name = value } definitions                     ║
║  resource_group.tf  azurerm_resource_group resources                        ║
║  storage_account.tf azurerm_storage_account resources                      ║
║  outputs.tf         all output "name" { } definitions                       ║
║  terraform.tfvars   key = "value" pairs (non-sensitive defaults)            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  THE GOLDEN RULE                                                             ║
║  Terraform merges ALL .tf files in the current directory.                   ║
║  File names don't matter. Order doesn't matter.                             ║
║  Any .tf file can reference anything from any other .tf file.               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  BACKEND BLOCK — CRITICAL SYNTAX                                             ║
║                                                                              ║
║  terraform {              ← MUST be inside terraform { }                    ║
║    backend "azurerm" {                                                       ║
║      resource_group_name  = "tf-state-rg"                                   ║
║      storage_account_name = "tfstateaccount"                                ║
║      container_name       = "tfstate"                                       ║
║      key                  = "dev.terraform.tfstate"                         ║
║    }                                                                         ║
║  }                                                                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  FILE LOAD ORDER                                                             ║
║  Alphabetical by filename                                                    ║
║  But: creation order is determined by DEPENDENCY GRAPH, not file order      ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DEPENDENCY TYPES                                                            ║
║                                                                              ║
║  Implicit (preferred):                                                       ║
║    resource_group_name = azurerm_resource_group.example.name                ║
║    → Terraform infers order automatically                                    ║
║                                                                              ║
║  Explicit (when implicit isn't possible):                                    ║
║    depends_on = [azurerm_resource_group.example]                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LOCALS SYNTAX REMINDER                                                      ║
║  Define:   locals { name = value }   ← "locals" (plural, no dot)           ║
║  Use:      local.name                ← "local"  (singular, with dot)        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL COMMANDS                                                         ║
║                                                                              ║
║  Create dir:       New-Item -ItemType Directory -Path "day06"               ║
║  Navigate:         Set-Location "day06"                                      ║
║  Create file:      New-Item -ItemType File -Name "provider.tf"              ║
║  Set ARM creds:    $env:ARM_CLIENT_ID = "your-id"                           ║
║  Clear ARM creds:  Remove-Item Env:ARM_CLIENT_ID                            ║
║  Init:             terraform init                                            ║
║  Validate:         terraform validate                                        ║
║  Plan:             terraform plan                                            ║
║  Plan + var:       terraform plan -var="environment=prod"                   ║
║  Plan + file:      terraform plan -var-file="prod.tfvars"                   ║
║  Apply:            terraform apply --auto-approve                           ║
║  Destroy:          terraform destroy --auto-approve                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  .gitignore — ALWAYS INCLUDE                                                 ║
║  .terraform/               provider binaries (large, OS-specific)           ║
║  terraform.tfstate         contains secrets — never commit                  ║
║  terraform.tfstate.backup  contains secrets — never commit                  ║
║  *.tfplan                  plan output files                                 ║
║                                                                              ║
║  DO commit:                                                                  ║
║  .terraform.lock.hcl       version lock — ensures team consistency          ║
║  *.tf                      your infrastructure code                         ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
ONE BIG FILE (Day 3 approach):
  main.tf = provider + backend + variables + locals + resources + outputs
  ↓
  Finding anything = ctrl+F and scroll forever
  Code reviews     = impossible to see what changed
  Team conflicts   = everyone editing the same file

SPLIT FILES (Day 6 approach):
  provider.tf      = "How does Terraform connect?"
  backend.tf       = "Where is the state stored?"
  variables.tf     = "What inputs does this accept?"
  locals.tf        = "What internal values does this compute?"
  resource_*.tf    = "What infrastructure does this create?"
  outputs.tf       = "What values does this return?"
  terraform.tfvars = "What values are we using right now?"
  ↓
  Finding anything = open the right file immediately
  Code reviews     = "Only resource_group.tf changed — clear approval"
  Team conflicts   = each person works in their own file

Same Terraform. Same result. Better humans can work with it.
```

---

*Guide covers: Terraform file structure best practices, provider.tf vs versions.tf,
backend.tf syntax (backend inside terraform block), variables.tf, locals.tf,
resource-per-file pattern, outputs.tf, terraform.tfvars, golden rule of file loading,
alphabetical load order, dependency graph vs file order, implicit vs explicit
dependency, depends_on, using var.* inside locals, variables referencing in locals,
common_tags pattern, multiple terraform{} blocks across files, .gitignore for
Terraform, pull request review workflow benefits, frequency-of-change principle,
PowerShell file creation commands, PowerShell ARM credential management.*
