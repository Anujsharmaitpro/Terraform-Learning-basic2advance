# Terraform Variables — Input, Output & Local Variables
## Deep-Dive Learning Guide — Day 5 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure Examples | PowerShell Commands Throughout

---

## Before You Start

This is Day 5. By now you know:
- Day 1: What Terraform is and why it exists
- Day 2: What providers are and version constraints
- Day 3: Writing resources, dependencies, authentication
- Day 4: State file, remote backends, state locking

Today is about making your Terraform code **reusable, readable, and
maintainable** using three types of variables. By the end of this guide
you will never hardcode a value in Terraform again — and you'll understand
exactly how to pass values in six different ways and which one wins.

---

## Table of Contents

1. Why Variables Exist — The Hardcoding Problem
2. The Three Types of Terraform Variables — Overview
3. Type Constraints — What Values Can a Variable Hold?
4. INPUT Variables — Full Deep Dive
5. Defining an Input Variable — Every Field Explained
6. Using an Input Variable in a Resource
7. The Six Ways to Pass a Variable Value
8. Variable Precedence — Which Value Wins?
9. OUTPUT Variables — Full Deep Dive
10. Defining an Output Variable — Every Field Explained
11. The `terraform output` Command
12. LOCAL Variables — Full Deep Dive
13. When to Use Locals vs Input Variables
14. Using Locals with Complex Tags — Azure Example
15. The Complete Code — All Three Variable Types Together
16. Common Mistakes Beginners Make
17. Practice Exercises
18. Complete Cheat Sheet

---

## 1. Why Variables Exist — The Hardcoding Problem

### What hardcoding means

Look at this Terraform code:

```hcl
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"          # ← hardcoded
  tags = {
    Environment = "Staging"         # ← hardcoded
  }
}

resource "azurerm_storage_account" "example" {
  name                     = "techtutorials101"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    Environment = "Staging"         # ← hardcoded again (same value!)
  }
}
```

**The word "Staging" appears twice.** If you need to change to "Production",
you must find and update every single place it appears. In a real project
with 40+ resources, this means 40+ manual edits — and one missed edit
means inconsistent tagging.

### The same problem, multiplied

Imagine you have six environments: Dev, SIT, UAT, Pre-Prod, DR, Production.
With hardcoded values, you need six separate copies of every file. Each
copy drifts differently over time. You end up with six slightly different
configurations that are supposed to be identical.

### The solution: variables

Define the value **once**. Reference it **everywhere**. Change it **in one place**.

```hcl
variable "environment" {
  default = "Staging"
}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
  tags = {
    Environment = var.environment    # ← references the variable
  }
}

resource "azurerm_storage_account" "example" {
  # ...
  tags = {
    Environment = var.environment    # ← same variable, always consistent
  }
}
```

Now change `default = "Staging"` to `default = "Production"` once, and
all 40 resources get the correct tag automatically.

---

## 2. The Three Types of Terraform Variables — Overview

Terraform has three distinct variable types. They solve three different problems:

```
┌─────────────────────────────────────────────────────────────────────┐
│  VARIABLE TYPE   │  DIRECTION  │  USE CASE                          │
├─────────────────────────────────────────────────────────────────────┤
│  Input Variable  │  IN  →      │  Values passed INTO Terraform      │
│  (var.*)         │             │  from outside (user, file, CLI)    │
├─────────────────────────────────────────────────────────────────────┤
│  Output Variable │      → OUT  │  Values returned FROM Terraform    │
│  (output)        │             │  after apply (IDs, names, URLs)    │
├─────────────────────────────────────────────────────────────────────┤
│  Local Variable  │  INTERNAL   │  Values computed/reused INSIDE     │
│  (local.*)       │             │  Terraform — not exposed outside   │
└─────────────────────────────────────────────────────────────────────┘
```

### The function analogy

Think of a Terraform configuration like a function in any programming language:

```
function deploy_infrastructure(environment, location) {   ← Input variables
  
  # internal calculations
  common_tags = { env: environment, lob: "Banking" }     ← Local variables
  
  # create resources...
  
  return storage_account_name                             ← Output variables
}
```

Inputs feed into the function. Locals are used internally. Outputs come out.

---

## 3. Type Constraints — What Values Can a Variable Hold?

Every input variable can optionally declare what **type** of value it accepts.
This prevents mistakes — like passing a number where a string is expected.

### Primitive types (single values)

| Type | What it stores | Examples |
|---|---|---|
| `string` | Text in double quotes | `"West Europe"`, `"Staging"`, `"t2.micro"` |
| `number` | Any numeric value | `3`, `100`, `3.14` |
| `bool` | True or false | `true`, `false` |

### Complex types (collections of values)

| Type | Structure | Example |
|---|---|---|
| `list` | Ordered sequence, allows duplicates | `["East US", "West Europe", "UK South"]` |
| `set` | Unordered, unique values only | `toset(["alice", "bob", "charlie"])` |
| `map` | Key-value pairs | `{ env = "dev", tier = "web" }` |
| `object` | Named attributes with specific types | `{ name = string, port = number }` |
| `tuple` | Fixed-length sequence of mixed types | `["web", 80, true]` |

### The default type — `any`

If you don't specify a type, Terraform uses `any` — it accepts whatever
value you pass. This is fine for learning but reduces safety in production.

```hcl
variable "environment" {
  # No type specified → type = any (default)
  default = "Staging"
}

variable "location" {
  type    = string     # Only accepts strings
  default = "West Europe"
}

variable "instance_count" {
  type    = number     # Only accepts numbers
  default = 2
}

variable "enable_monitoring" {
  type    = bool       # Only accepts true/false
  default = true
}
```

---

## 4. INPUT Variables — Full Deep Dive

### What is an input variable?

An input variable is a **parameter** your Terraform configuration accepts
from the outside world. It lets the same code produce different results
depending on what values are passed in.

### Real-world example of why this matters

You have ONE Terraform codebase for your application. You deploy it to
six environments. The only thing that differs between environments is
a handful of values (environment name, VM size, replica count).

```
Same .tf code + var environment="dev"  → creates dev infrastructure
Same .tf code + var environment="prod" → creates prod infrastructure
Same .tf code + var environment="uat"  → creates uat infrastructure
```

One codebase. Six deployments. Zero code duplication.

---

## 5. Defining an Input Variable — Every Field Explained

### The full syntax

```hcl
variable "environment" {
  type        = string
  description = "The deployment environment (dev, staging, prod)"
  default     = "staging"
  sensitive   = false
}
```

### Field-by-field breakdown

**`variable "environment"`**
- `variable` is the keyword — always required
- `"environment"` is the variable name — you choose this
- This name is how you reference the variable elsewhere: `var.environment`

**`type = string`**
- Optional but strongly recommended
- Tells Terraform what kind of value this variable accepts
- If you pass a number when `string` is expected, Terraform errors immediately
- Default is `any` if omitted

**`description = "..."`**
- Optional but a professional best practice
- Shown when running `terraform plan` with no value provided
- Shown in auto-generated documentation
- Write descriptions for your teammates, not yourself

**`default = "staging"`**
- Optional
- If provided, Terraform uses this value when no other value is supplied
- If NOT provided, Terraform will prompt you interactively for a value
  when you run `terraform plan` or `terraform apply`

**`sensitive = true`**
- Optional, defaults to `false`
- When `true`, Terraform hides the value in plan/apply output:
  ```
  ~ tags = {
      ~ Environment = (sensitive value)
    }
  ```
- Does NOT encrypt the value — it's still stored in the state file
- Use for passwords, API keys, connection strings

### A variable with no default (required variable)

```hcl
variable "project_name" {
  type        = string
  description = "The name of the project (required)"
  # No default → user MUST provide this value
}
```

If no value is provided, Terraform prompts:
```
var.project_name
  The name of the project (required)

  Enter a value:
```

---

## 6. Using an Input Variable in a Resource

### The reference syntax

```
var.variable_name
 │   │
 │   └── the name you gave in the variable block
 └── always lowercase "var" with a dot
```

### Complete Azure example

```hcl
# ─── Variable Definitions ─────────────────────────────────────────
variable "environment" {
  type        = string
  description = "Deployment environment name"
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

# ─── Resources Using the Variables ────────────────────────────────
resource "azurerm_resource_group" "example" {
  name     = "rg-${var.project}-${var.environment}"  # string interpolation
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "azurerm_storage_account" "example" {
  name                     = "${var.project}${var.environment}stg"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.environment    # same variable, stays consistent
    Project     = var.project
  }
}
```

### String interpolation with variables

When you need to embed a variable inside a longer string, use `${ }`:

```hcl
name = "rg-${var.project}-${var.environment}"
# If project="myapp" and environment="staging"
# Result: "rg-myapp-staging"
```

---

## 7. The Six Ways to Pass a Variable Value

This is where most beginners get confused. Terraform accepts variable
values from six different sources. Here they are with PowerShell examples:

### Method 1 — Default value (lowest precedence)

Already defined in the `variable` block itself:

```hcl
variable "environment" {
  default = "staging"    # ← used when no other method provides a value
}
```

When to use: sensible fallback values for development.

---

### Method 2 — Environment variable with `TF_VAR_` prefix

Set an OS environment variable. The name must be:
`TF_VAR_` + the variable name

**PowerShell:**
```powershell
# Set it
$env:TF_VAR_environment = "command-line-env"

# Verify it
$env:TF_VAR_environment

# Clear it
Remove-Item Env:TF_VAR_environment

# Check all TF_VAR_ variables
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }
```

**Bash (for reference):**
```bash
export TF_VAR_environment="command-line-env"
unset TF_VAR_environment
env | grep TF_VAR
```

When to use: CI/CD pipelines that inject values as environment variables.
**Note:** This has the LOWEST precedence among the active methods — it
will be overridden by tfvars files and the `-var` flag.

---

### Method 3 — `terraform.tfvars` file (auto-loaded)

Create a file named exactly `terraform.tfvars` in the same folder:

```hcl
# terraform.tfvars
environment = "demo"
location    = "East US"
project     = "bankingapp"
```

Terraform automatically loads this file without any extra flags.
The format is just `key = value` — no `variable` keyword, no curly braces.

**PowerShell — create the file:**
```powershell
# Create terraform.tfvars
@"
environment = "demo"
location    = "East US"
project     = "bankingapp"
"@ | Out-File -FilePath "terraform.tfvars" -Encoding utf8
```

When to use: default non-sensitive values for a project or environment.
**Important:** Do NOT commit `terraform.tfvars` to Git if it contains
sensitive values like passwords.

---

### Method 4 — Custom `.tfvars` file with `-var-file` flag

Create any file with a `.tfvars` or `.tfvars.json` extension and
specify it explicitly:

```hcl
# prod.tfvars
environment = "production"
location    = "UK South"
project     = "bankingapp"
```

```hcl
# dev.tfvars
environment = "development"
location    = "West Europe"
project     = "bankingapp"
```

**PowerShell — run with a specific file:**
```powershell
terraform plan -var-file="prod.tfvars"
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
```

This is the recommended approach for managing multiple environments
from the same codebase.

---

### Method 5 — `-var` flag on the command line

Pass values directly as command-line arguments:

**PowerShell:**
```powershell
terraform plan -var="environment=dev"
terraform plan -var="environment=dev" -var="location=East US"
terraform apply -var="environment=production" --auto-approve
```

When to use:
- Quick overrides for testing
- Passing secrets in CI/CD (value from a secret store, not hardcoded)
- One-off deployments that need a specific value

---

### Method 6 — `*.auto.tfvars` files (auto-loaded)

Any file ending in `.auto.tfvars` is automatically loaded — you don't
need to specify it with `-var-file`:

```hcl
# staging.auto.tfvars
environment = "staging"
location    = "West Europe"
```

```hcl
# common.auto.tfvars
project = "bankingapp"
```

**PowerShell — create auto-loaded files:**
```powershell
@"
environment = "staging"
"@ | Out-File -FilePath "staging.auto.tfvars" -Encoding utf8
```

When to use: When you always want certain files loaded without
remembering to specify them, and you have multiple `.tfvars` files
for different purposes.

---

## 8. Variable Precedence — Which Value Wins?

When multiple methods provide a value for the same variable, Terraform
uses the one with the **highest precedence**. The source that wins is
the one later in this list:

```
LOWEST PRECEDENCE (loses to everything above it)
    │
    │  1. Environment variables (TF_VAR_*)
    │
    │  2. terraform.tfvars file (auto-loaded)
    │
    │  3. terraform.tfvars.json file (auto-loaded)
    │
    │  4. *.auto.tfvars files (alphabetical order)
    │
    │  5. *.auto.tfvars.json files (alphabetical order)
    │
    ▼  6. -var-file flag on command line
    
HIGHEST PRECEDENCE (wins over everything below it)
       7. -var flag on command line
```

### Why the instructor saw `demo` instead of `command-line-env`

The instructor set `TF_VAR_environment=command-line-env` via environment
variable, but already had `terraform.tfvars` containing `environment = "demo"`.

Since `terraform.tfvars` has HIGHER precedence than `TF_VAR_*`, the
tfvars value (`demo`) won.

Then when he added `-var="environment=dev"`, THAT won because the `-var`
flag has the highest precedence.

### Visual example

```
TF_VAR_environment = "command-line-env"   # Precedence level 1 (lowest)
terraform.tfvars: environment = "demo"    # Precedence level 2
-var="environment=dev"                    # Precedence level 7 (highest)

Result: "dev"  ← -var wins
```

### PowerShell debugging — check what value Terraform is using

Add a temporary output to your code:

```hcl
output "debug_environment" {
  value = var.environment
}
```

Then run:

```powershell
terraform plan
# Output section will show:
# Changes to Outputs:
#   + debug_environment = "dev"
```

**PowerShell — check for TF_VAR_ variables currently set:**
```powershell
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }
```

**PowerShell — clear a specific TF_VAR_ variable:**
```powershell
Remove-Item Env:TF_VAR_environment
```

---

## 9. OUTPUT Variables — Full Deep Dive

### What is an output variable?

An output variable is a value that Terraform **prints to your screen**
after `terraform apply` completes. Think of it as the return value of
your Terraform configuration.

### Why are outputs useful?

**Reason 1 — See important values after apply**
After creating 10 resources, you want to know: "What is the storage
account's primary endpoint URL? What is the Resource Group's ID?"
Outputs print these automatically.

**Reason 2 — Pass values between modules**
In large Terraform projects, you split code into modules. Module A
creates a network. Module B creates servers inside that network.
Module B needs the subnet ID from Module A — outputs are how values
travel between modules.

**Reason 3 — CI/CD integration**
After `terraform apply`, a CI/CD pipeline can run `terraform output`
to get the created resource URLs and pass them to the next pipeline
stage (e.g., to configure an application).

**Reason 4 — Human reference**
Simply displaying "Your application is available at: https://..." after
deploy is a good developer experience.

---

## 10. Defining an Output Variable — Every Field Explained

### Full syntax

```hcl
output "storage_account_name" {
  description = "The name of the created Storage Account"
  value       = azurerm_storage_account.example.name
  sensitive   = false
}
```

### Field-by-field breakdown

**`output "storage_account_name"`**
- `output` is the keyword — always required
- `"storage_account_name"` is the output name — you choose this
- Used when running `terraform output storage_account_name`

**`value = azurerm_storage_account.example.name`**
- **Required** — this is the actual value to output
- Can reference any resource attribute or variable
- Uses the same reference syntax as resource arguments

**`description = "..."`**
- Optional but recommended
- Shown in `terraform output` command alongside the value

**`sensitive = true`**
- Optional, defaults to `false`
- When `true`, hides the value in terminal output:
  ```
  storage_account_key = <sensitive>
  ```
- Still stored in state file — just hidden in terminal

### Comprehensive Azure example

```hcl
# Output the Resource Group name
output "resource_group_name" {
  description = "Name of the created Resource Group"
  value       = azurerm_resource_group.example.name
}

# Output the Storage Account name
output "storage_account_name" {
  description = "Name of the created Storage Account"
  value       = azurerm_storage_account.example.name
}

# Output the primary blob endpoint URL
output "storage_blob_endpoint" {
  description = "Primary blob endpoint for the Storage Account"
  value       = azurerm_storage_account.example.primary_blob_endpoint
}

# Output the Resource Group ID (generated by Azure after creation)
output "resource_group_id" {
  description = "Unique Azure Resource ID of the Resource Group"
  value       = azurerm_resource_group.example.id
}

# Sensitive output — hides value in terminal
output "storage_primary_key" {
  description = "Primary access key (sensitive)"
  value       = azurerm_storage_account.example.primary_access_key
  sensitive   = true
}
```

### What you see after `terraform apply`

```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

resource_group_name   = "rg-myapp-staging"
storage_account_name  = "techtutorials101"
storage_blob_endpoint = "https://techtutorials101.blob.core.windows.net/"
resource_group_id     = "/subscriptions/xxxx/resourceGroups/rg-myapp-staging"
storage_primary_key   = <sensitive>
```

### Referencing attributes you didn't set (auto-generated by Azure)

Once Terraform creates a resource, it gains access to ALL attributes
Azure generates — not just the ones you configured. In the video, the
instructor showed that after typing `azurerm_storage_account.example.`
the VS Code extension suggested many fields including `id`,
`primary_blob_endpoint`, `primary_access_key`, and more.

```hcl
# Attributes you SET (inputs):
azurerm_storage_account.example.name
azurerm_storage_account.example.account_tier
azurerm_storage_account.example.account_replication_type

# Attributes Azure GENERATES (available after apply):
azurerm_storage_account.example.id
azurerm_storage_account.example.primary_blob_endpoint
azurerm_storage_account.example.primary_access_key
azurerm_storage_account.example.primary_connection_string
azurerm_storage_account.example.secondary_blob_endpoint
```

---

## 11. The `terraform output` Command

After `terraform apply`, you can query outputs at any time without re-running apply:

**PowerShell:**
```powershell
# Show all outputs
terraform output

# Show a specific output
terraform output storage_account_name

# Show output in JSON format (useful for scripts/CI-CD)
terraform output -json

# Show a sensitive output value
terraform output -raw storage_primary_key

# Use output value in a PowerShell variable
$storageName = terraform output -raw storage_account_name
Write-Host "Storage Account: $storageName"
```

Example output of `terraform output`:
```
resource_group_name   = "rg-myapp-staging"
storage_account_name  = "techtutorials101"
storage_blob_endpoint = "https://techtutorials101.blob.core.windows.net/"
storage_primary_key   = <sensitive>
```

---

## 12. LOCAL Variables — Full Deep Dive

### What is a local variable?

A **local variable** (or simply "local") is a value you compute or define
inside Terraform for internal use. Unlike input variables, locals cannot
be passed in from outside — they are always determined by the code itself.

### The keyword difference — easy to confuse!

```hcl
# DEFINE locals — uses plural "locals" with an "s"
locals {
  common_tags = {
    Environment = "dev"
    LOB         = "Banking"
    Stage       = "Alpha"
  }
}

# REFERENCE a local — uses singular "local" WITHOUT an "s"
tags = local.common_tags
# or drill into a specific field:
environment = local.common_tags.environment
```

This trips up nearly every beginner. Define with `locals {}`, reference
with `local.`.

### The full syntax

```hcl
locals {
  # Simple values
  environment    = "staging"
  region_short   = "we"
  full_name      = "myapp-staging"

  # Computed from other values
  resource_prefix = "rg-${var.project}-${var.environment}"

  # Complex value — a map of tags
  common_tags = {
    Environment = var.environment
    Project     = var.project
    LOB         = "Banking"
    Stage       = "Alpha"
    ManagedBy   = "Terraform"
  }

  # Computed from a list
  storage_name = lower("${var.project}${var.environment}stg")
}
```

---

## 13. When to Use Locals vs Input Variables

This is the question the instructor addressed. Here is the clear answer:

| Situation | Use |
|---|---|
| Value changes per environment or user | **Input variable** |
| Value is always the same (never changes) | **Local** |
| Value is computed from other variables | **Local** |
| Value needs to be reused across many resources without repetition | **Local** |
| Value should be overridable from outside (CLI, CI/CD) | **Input variable** |
| Value is a combination of other values | **Local** |

### The instructor's exact scenario

```hcl
# WRONG — using input variable for something that never changes
variable "line_of_business" {
  default = "Banking"    # This never changes. Why is it a variable?
}

# RIGHT — use a local for values that don't change
locals {
  line_of_business = "Banking"    # Internal constant — not exposed outside
}
```

### Another common locals pattern — computed names

```hcl
variable "project" { default = "myapp" }
variable "environment" { default = "staging" }

locals {
  # Compute resource names once, use everywhere
  rg_name      = "rg-${var.project}-${var.environment}"
  storage_name = lower("${var.project}${var.environment}stg")
  vnet_name    = "vnet-${var.project}-${var.environment}"
}

resource "azurerm_resource_group" "example" {
  name     = local.rg_name        # "rg-myapp-staging"
  location = "West Europe"
}

resource "azurerm_storage_account" "example" {
  name                = local.storage_name    # "myappstagingestg"
  resource_group_name = local.rg_name
  # ...
}
```

If the naming convention changes, update only the locals block — all
resources automatically get the new names.

---

## 14. Using Locals with Complex Tags — The Azure Example from the Video

The instructor demonstrated locals with a map of tags. Here is that
concept fully expanded:

```hcl
variable "environment" {
  type    = string
  default = "staging"
}

locals {
  # Define ALL common tags in one place
  common_tags = {
    Environment = var.environment       # from input variable — can change
    LOB         = "Banking"             # internal constant — never changes
    Stage       = "Alpha"               # internal constant — never changes
    ManagedBy   = "Terraform"           # always the same
    CreatedDate = "2024-01-01"          # set once, stays the same
  }
}

resource "azurerm_resource_group" "example" {
  name     = "rg-example-${var.environment}"
  location = "West Europe"
  tags     = local.common_tags           # ← apply all tags at once
}

resource "azurerm_storage_account" "example" {
  name                     = "myapp${var.environment}stg"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags    # ← same tags, zero duplication
}
```

### Drilling into a specific field from a local map

If you only need ONE tag value (not the whole map), drill into it:

```hcl
# Get the entire tags map
tags = local.common_tags

# Get just one value from the map
environment_label = local.common_tags.environment
lob_label         = local.common_tags.lob
stage_label       = local.common_tags.stage
```

The instructor demonstrated that NOT specifying which key causes an error:

```hcl
# ❌ This errors — tags expects key-value pairs, not the whole nested map
tags = {
  Environment = local.common_tags    # wrong — this is the full map
}

# ✅ Reference the specific field
tags = {
  Environment = local.common_tags.environment    # correct — gets just that value
}

# ✅ Or use the entire map directly as tags
tags = local.common_tags    # correct — uses the whole map as all tags
```

---

## 15. The Complete Code — All Three Variable Types Together

This is the full, clean version of everything from this video:

**`variables.tf`** — all input variable definitions
```hcl
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
  default     = "myapp"
}
```

**`locals.tf`** — all local variable definitions
```hcl
locals {
  # Computed resource name prefix
  name_prefix = "${var.project}-${var.environment}"

  # Common tags applied to ALL resources
  common_tags = {
    Environment = var.environment
    Project     = var.project
    LOB         = "Banking"
    Stage       = "Alpha"
    ManagedBy   = "Terraform"
  }
}
```

**`providers.tf`** — provider configuration
```hcl
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
}
```

**`main.tf`** — infrastructure resources
```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-${local.name_prefix}"    # uses local
  location = var.location                 # uses input variable

  tags = local.common_tags                # uses local map
}

resource "azurerm_storage_account" "example" {
  name = lower(
    replace("${var.project}${var.environment}stg", "-", "")
  )
  # Storage accounts: lowercase, no hyphens, 3-24 chars

  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.common_tags    # same tags as the resource group
}
```

**`outputs.tf`** — output variable definitions
```hcl
output "resource_group_name" {
  description = "Name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.example.name
}

output "storage_blob_endpoint" {
  description = "Primary Blob endpoint URL"
  value       = azurerm_storage_account.example.primary_blob_endpoint
}

output "applied_tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}
```

**`terraform.tfvars`** — default values (non-sensitive)
```hcl
environment = "staging"
location    = "West Europe"
project     = "myapp"
```

**Running everything — PowerShell:**
```powershell
# 1. Initialise
terraform init

# 2. Validate
terraform validate

# 3. Plan with default values (from terraform.tfvars)
terraform plan

# 4. Plan with override via -var flag
terraform plan -var="environment=dev"

# 5. Plan with a separate tfvars file
terraform plan -var-file="prod.tfvars"

# 6. Apply
terraform apply --auto-approve

# 7. Check outputs
terraform output
terraform output storage_account_name

# 8. Clean up
terraform destroy --auto-approve
```

---

## 16. Common Mistakes Beginners Make

### Mistake 1 — Writing `locals` instead of `local` when referencing

```hcl
# ❌ Wrong — "locals" (plural) does not work as a reference
tags = locals.common_tags

# ✅ Correct — "local" (singular) for references
tags = local.common_tags
```

Define with `locals {}` (plural). Reference with `local.` (singular).

---

### Mistake 2 — Forgetting `var.` when using an input variable

```hcl
# ❌ Wrong — just the name doesn't work
location = location

# ✅ Correct — must prefix with var.
location = var.location
```

---

### Mistake 3 — Using `TF_VAR_` environment variable and wondering why it doesn't override tfvars

```powershell
# You set this:
$env:TF_VAR_environment = "prod"

# But terraform.tfvars has:
# environment = "staging"

# Result: "staging" wins (tfvars has higher precedence than TF_VAR_*)
# Fix: remove terraform.tfvars or use -var flag instead
```

---

### Mistake 4 — Not specifying a key when using a local map as a tag value

```hcl
locals {
  common_tags = {
    Environment = "staging"
    LOB         = "Banking"
  }
}

# ❌ Wrong — passing the whole map as a tag value
tags = {
  Environment = local.common_tags    # error: string required
}

# ✅ Correct Option A — use a specific field
tags = {
  Environment = local.common_tags.environment
}

# ✅ Correct Option B — use the whole map as ALL tags
tags = local.common_tags
```

---

### Mistake 5 — Committing `terraform.tfvars` with sensitive values to Git

```powershell
# ❌ BAD .gitignore — no protection for tfvars
# .gitignore contains only:
# .terraform/
# terraform.tfstate

# ✅ GOOD .gitignore — protects sensitive tfvars
# Add to .gitignore:
# .terraform/
# terraform.tfstate
# terraform.tfstate.backup
# *.tfvars           ← prevents ALL tfvars from being committed
```

For non-sensitive tfvars (like environment names), committing is fine.
For sensitive tfvars (passwords, keys), never commit.

---

### Mistake 6 — Putting sensitive values in `default` field of a variable

```hcl
# ❌ Default values are visible in code — BAD for secrets
variable "db_password" {
  default = "MySecretPassword123!"    # Anyone reading the .tf file sees this
}

# ✅ No default — Terraform prompts or CI/CD passes via -var
variable "db_password" {
  type      = string
  sensitive = true
  # No default — must be provided at runtime
}
```

**PowerShell — pass sensitive value at runtime:**
```powershell
terraform apply -var="db_password=$($dbPassword)"
# Or read from a secret manager and pass it in
```

---

## 17. Practice Exercises

### Exercise 1 — Convert Hardcoded to Variables

Convert this hardcoded code to use input variables:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-production"
  location = "East US"
  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

**Answer:**
```hcl
variable "environment" {
  type    = string
  default = "production"
}

variable "location" {
  type    = string
  default = "East US"
}

variable "team" {
  type    = string
  default = "platform"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.environment}"
  location = var.location
  tags = {
    Environment = var.environment
    Team        = var.team
  }
}
```

---

### Exercise 2 — Variable Precedence

You have all of these set simultaneously:
```
terraform.tfvars:      environment = "tfvars-value"
TF_VAR_environment:    "env-var-value"   (PowerShell: $env:TF_VAR_environment)
-var flag:             environment=cli-value
default in code:       "default-value"
```

What value does `var.environment` have when you run `terraform plan -var="environment=cli-value"`?

**Answer:**
```
cli-value

The -var flag has the highest precedence. The order from lowest to highest:
1. TF_VAR_environment = "env-var-value"         (lowest)
2. default = "default-value"
3. terraform.tfvars: "tfvars-value"
4. -var="environment=cli-value"                  (highest) ← WINS
```

---

### Exercise 3 — Write Output Variables

Write three output variables for this storage account:
- Its name
- Its primary blob endpoint
- Its primary access key (marked as sensitive)

**Answer:**
```hcl
output "name" {
  description = "Storage Account name"
  value       = azurerm_storage_account.example.name
}

output "blob_endpoint" {
  description = "Primary Blob Storage endpoint"
  value       = azurerm_storage_account.example.primary_blob_endpoint
}

output "primary_key" {
  description = "Primary access key"
  value       = azurerm_storage_account.example.primary_access_key
  sensitive   = true
}
```

---

### Exercise 4 — Locals with Common Tags

Define a `locals` block with common tags for an Azure banking application:
- Environment (from input variable)
- Line of Business = "Retail Banking"
- Cost Centre = "IT-INFRA-001"
- Managed By = "Terraform"

Then apply those tags to a Resource Group.

**Answer:**
```hcl
variable "environment" {
  type    = string
  default = "dev"
}

locals {
  common_tags = {
    Environment    = var.environment
    LOB            = "Retail Banking"
    CostCentre     = "IT-INFRA-001"
    ManagedBy      = "Terraform"
  }
}

resource "azurerm_resource_group" "example" {
  name     = "rg-banking-${var.environment}"
  location = "West Europe"
  tags     = local.common_tags
}
```

---

### Exercise 5 — PowerShell: All Six Methods

In PowerShell, demonstrate all six ways to pass `environment=prod`:

**Answer:**
```powershell
# Method 1: Default in code (no PowerShell needed — just set default="prod")

# Method 2: TF_VAR_ environment variable
$env:TF_VAR_environment = "prod"
terraform plan

# Method 3: terraform.tfvars (create file with: environment = "prod")

# Method 4: -var-file flag
terraform plan -var-file="prod.tfvars"

# Method 5: -var flag
terraform plan -var="environment=prod"

# Method 6: auto.tfvars (create prod.auto.tfvars with: environment = "prod")
# then run terraform plan with no flags — it's loaded automatically
```

---

## 18. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║          TERRAFORM VARIABLES — DAY 5 QUICK REFERENCE                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  THREE VARIABLE TYPES                                                        ║
║                                                                              ║
║  Input:   var.name     → values passed IN from outside                      ║
║  Output:  output       → values returned OUT after apply                    ║
║  Local:   local.name   → values used INTERNALLY (not exposed)               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  INPUT VARIABLE SYNTAX                                                       ║
║                                                                              ║
║  variable "name" {                                                           ║
║    type        = string          # string, number, bool, list, map, etc.    ║
║    description = "What it is"    # Optional — documents the variable        ║
║    default     = "value"         # Optional — used if no value provided     ║
║    sensitive   = false           # true = hidden in output, not in state    ║
║  }                                                                           ║
║                                                                              ║
║  Reference: var.name                                                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  OUTPUT VARIABLE SYNTAX                                                      ║
║                                                                              ║
║  output "name" {                                                             ║
║    description = "What it shows"                                            ║
║    value       = resource_type.local_name.attribute    # Required           ║
║    sensitive   = false                                                       ║
║  }                                                                           ║
║                                                                              ║
║  Commands: terraform output                                                  ║
║            terraform output -raw name                                        ║
║            terraform output -json                                            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LOCAL VARIABLE SYNTAX                                                       ║
║                                                                              ║
║  locals {                          ← define with "locals" (plural)          ║
║    name  = "value"                                                           ║
║    tags  = { key = "value" }                                                 ║
║    computed = "${var.a}-${var.b}"                                            ║
║  }                                                                           ║
║                                                                              ║
║  Reference: local.name             ← use "local" (singular, no s)          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  VARIABLE PRECEDENCE (highest wins)                                          ║
║                                                                              ║
║  7. -var flag             terraform plan -var="env=prod"     ← WINS         ║
║  6. -var-file flag        terraform plan -var-file="p.tfvars"               ║
║  5. *.auto.tfvars.json                                                       ║
║  4. *.auto.tfvars                                                            ║
║  3. terraform.tfvars.json                                                    ║
║  2. terraform.tfvars                                                         ║
║  1. TF_VAR_* env variable $env:TF_VAR_env="prod"            ← LOWEST       ║
║     (below tfvars files!)                                                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL COMMANDS                                                         ║
║                                                                              ║
║  Set TF_VAR:    $env:TF_VAR_environment = "prod"                            ║
║  Clear TF_VAR:  Remove-Item Env:TF_VAR_environment                          ║
║  List TF_VARs:  Get-ChildItem Env: | Where {$_.Name -like "TF_VAR_*"}      ║
║  Use -var:      terraform plan -var="environment=prod"                      ║
║  Use -var-file: terraform plan -var-file="prod.tfvars"                      ║
║  See outputs:   terraform output                                             ║
║  Get one output:terraform output -raw storage_account_name                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  WHEN TO USE EACH TYPE                                                       ║
║                                                                              ║
║  Input variable:  changes per env/user (location, env name, VM size)       ║
║  Local variable:  computed values, constants, complex tag maps              ║
║  Output variable: resource IDs/URLs needed after apply or by CI/CD         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PRIMITIVE TYPES                                                             ║
║  string → "text"    number → 42    bool → true/false                       ║
║                                                                              ║
║  COMPLEX TYPES                                                               ║
║  list   → ["a","b"]    map → {k="v"}    set → unique list                  ║
║  object → typed map    tuple → mixed-type fixed list                        ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
Think of Terraform like a function call:

  deploy(environment="prod", location="East US")   ← Input variables (var.*)
  {
    prefix = "myapp-prod"                           ← Local variables (local.*)
    tags   = { Env="prod", LOB="Banking" }          ← Local variables

    create Resource Group...
    create Storage Account...

    return storage_endpoint_url                     ← Output variables (output)
  }

Inputs  → given to Terraform from outside
Locals  → calculated inside Terraform, invisible from outside
Outputs → returned from Terraform to you or the next step in your pipeline
```

---

*Guide covers: Terraform input variables, output variables, local variables,
type constraints (string/number/bool/list/set/map/object/tuple), variable
definition syntax (type/description/default/sensitive), var. reference syntax,
local. vs locals{} distinction, six ways to pass variable values, TF_VAR_
environment variables in PowerShell, terraform.tfvars, auto.tfvars,
-var flag, -var-file flag, variable precedence order, terraform output command,
sensitive outputs, computed locals, common_tags pattern, string interpolation
with ${}, PowerShell Set/Remove/List for TF_VAR_ variables, debugging variable
values with output blocks, .gitignore for tfvars files.*
