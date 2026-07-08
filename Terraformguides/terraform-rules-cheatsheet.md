# Terraform & Azure — Rules, Conventions & Syntax Quick Reference

> A personal cheat sheet compiled from everything covered in this learning series.
> Keep this open while you code. Every rule here has burned someone in production.

---

## Table of Contents

1. [HCL Syntax Rules — Brackets, Braces, Parentheses](#1-hcl-syntax-rules)
2. [Naming Conventions — snake_case, Prefixes, Patterns](#2-naming-conventions)
3. [Singular vs. Plural Rules](#3-singular-vs-plural)
4. [Variable Rules](#4-variable-rules)
5. [Locals Rules](#5-locals-rules)
6. [Resource Block Rules](#6-resource-block-rules)
7. [Lifecycle Rules](#7-lifecycle-rules)
8. [Output Rules](#8-output-rules)
9. [Azure Resource Naming Rules (Hard Limits)](#9-azure-resource-naming-rules)
10. [Tagging Rules](#10-tagging-rules)
11. [File & Folder Structure Rules](#11-file--folder-structure-rules)
12. [Security & Secrets Rules](#12-security--secrets-rules)
13. [Terraform Workflow Rules](#13-terraform-workflow-rules)
14. [count vs. for_each Rules](#14-count-vs-for_each-rules)
15. [Dynamic Block Rules](#15-dynamic-block-rules)
16. [Service Principal Rules](#16-service-principal-rules)

---

## 1. HCL Syntax Rules

### `{}` Curly Braces — Block Body

Used to open and close every **block** in Terraform.

```hcl
# Resource block — curly braces wrap the entire body
resource "azurerm_resource_group" "main" {
  name     = "myapp-dev-rg"
  location = "eastus"
}

# Also used for inline map values
tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
}
```

**Rule:** Every opening `{` must have a matching closing `}`. Indentation inside braces is 2 spaces (Terraform standard).

---

### `()` Parentheses — Function Calls

Used exclusively for **calling built-in functions**.

```hcl
# Functions always use ()
name   = lower("MyApp-DEV")           # → "myapp-dev"
name   = replace("my-app", "-", "")   # → "myapp"
name   = substr("myappprod", 0, 24)   # → "myappprod" (max 24 chars)
prefix = format("%s-%s", var.project, var.environment)
tags   = merge(local.common_tags, { Extra = "value" })
```

**Rule:** Never use `()` outside a function call. `()` are not used to group logic the way some other languages do.

---

### `[]` Square Brackets — Lists and Index Access

Used for **list literals**, **list type constraints**, and **accessing items by position**.

```hcl
# List literal
allowed_ports = [22, 80, 443, 8080]

# Type constraint — a list of strings
variable "subnets" {
  type = list(string)
}

# Accessing by index (zero-based)
first_port = var.allowed_ports[0]   # → 22

# address_space in azurerm requires a list even for one value
address_space = ["10.0.0.0/16"]
```

**Rule:** Lists are ordered and zero-indexed. Use `[]` when you need order. Use `{}` (a map) when you need named keys.

---

### `""` Double Quotes — Strings and Interpolation

```hcl
# Plain string
name = "myapp-dev-rg"

# String interpolation — embed expressions inside ${}
name = "${var.project}-${var.environment}-rg"

# Heredoc — for multi-line strings
script = <<-EOT
  #!/bin/bash
  echo "Hello from ${var.environment}"
EOT
```

**Rule:** Always use double quotes `""` for strings, never single quotes. Interpolation uses `${}` inside the string.

---

### `=` vs. `:` — Assignment vs. Map Separator

```hcl
# = is used for argument assignment inside resource/variable blocks
name     = "myapp-dev-rg"
location = "eastus"

# : is used inside for expressions (map construction)
active_stores = {
  for store in local.all_stores :
  store.store_id => store        # => separates key from value in a for expression
  if store.is_active == "true"
}
```

---

### `=>` Arrow — Key-Value Separator in `for` Expressions

```hcl
# Produces a map: key => value
my_map = {
  for item in var.items :
  item.id => item.name
}
```

---

## 2. Naming Conventions

### The master pattern for Azure resource names

```
{project}-{environment}-{resource-type-abbreviation}
```

| Resource | Abbreviation | Example |
|---|---|---|
| Resource Group | `rg` | `myapp-dev-rg` |
| Virtual Network | `vnet` | `myapp-dev-vnet` |
| Subnet | `snet` | `myapp-dev-snet-app` |
| Network Security Group | `nsg` | `myapp-dev-nsg` |
| Storage Account | `sa` | `myappdevsa` (no hyphens!) |
| Key Vault | `kv` | `myapp-dev-kv` |
| CDN Profile | `cdn` | `myapp-dev-cdn` |
| Virtual Machine | `vm` | `myapp-dev-vm` |

### Case rules by context

| Context | Case | Example |
|---|---|---|
| Terraform variable names | `snake_case` | `storage_account_name` |
| Terraform local names | `snake_case` | `local.name_prefix` |
| Terraform resource labels | `snake_case` | `resource "azurerm_storage_account" "main"` |
| Terraform output names | `snake_case` | `output "resource_group_name"` |
| Azure resource names | `kebab-case` | `myapp-dev-rg` |
| Tag keys | `PascalCase` | `Environment`, `ManagedBy`, `CostCenter` |
| Tag values | as-is | `"Terraform"`, `"dev"` |

### The one strict naming rule

> You must never type the environment name (`dev` or `prod`) more than once in your code — only in the variable declaration or `.tfvars` file. Every resource name, tag, and output referencing the environment must derive it from `var.environment`.

**Wrong:**
```hcl
resource "azurerm_resource_group" "main" {
  name = "myapp-dev-rg"   # ← hardcoded "dev" — WRONG
}
```

**Right:**
```hcl
resource "azurerm_resource_group" "main" {
  name = "${local.name_prefix}-rg"   # ← derived — CORRECT
}
```

---

## 3. Singular vs. Plural

This is one of the most overlooked conventions. It directly affects how you read and reason about your code.

### Resource label — use the `main` label for single resources

```hcl
# Singular label when there is ONE of this resource type
resource "azurerm_resource_group" "main" { }
resource "azurerm_virtual_network" "main" { }
resource "azurerm_key_vault" "main" { }
```

Use `main` as the label when you only ever create one of that resource per environment. It signals "this is the primary one."

### Resource label — use a descriptive plural or name for multiple resources

```hcl
# Plural label when for_each creates multiple instances
resource "azurerm_subnet" "subnets" {
  for_each = toset(var.subnets)
  name     = each.key
}

resource "azurerm_storage_container" "stores" {
  for_each = local.active_stores
  name     = "store-${each.key}"
}
```

### Variable names — singular for a single value, plural for collections

```hcl
# Singular — holds one value
variable "environment" { type = string }
variable "location"    { type = string }
variable "vm_size"     { type = string }

# Plural — holds multiple values
variable "subnets"       { type = list(string) }
variable "allowed_ports" { type = list(number) }
variable "tags"          { type = map(string) }
```

### Local names — follow the same singular/plural pattern

```hcl
locals {
  name_prefix  = "..."         # singular — one prefix
  common_tags  = { ... }       # singular collective noun — one map
  active_stores = { ... }      # plural — a collection of stores
  storage_name  = "..."        # singular — one derived name
}
```

---

## 4. Variable Rules

### Declaration rules

```hcl
variable "environment" {
  type        = string           # always declare type
  description = "..."            # always write a description — treat it as documentation
  default     = "dev"            # optional — omit if the value must always be supplied

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Must be 'dev' or 'prod'."   # must start with uppercase, end with period
  }
}
```

**Rules:**
- Always declare `type` — never leave it untyped
- Always write a `description` — it is documentation
- Never set a `default` for secrets — force the caller to supply them explicitly
- `error_message` in a `validation` block must be a non-empty string
- Validation `condition` must evaluate to `true` for the value to be accepted

### Type system

```hcl
# Primitives
type = string
type = number
type = bool

# Collections
type = list(string)      # ordered, indexed by position [0], [1]...
type = map(string)       # unordered, indexed by key ["key"]
type = set(string)       # unordered, unique values, no index

# Structural
type = object({
  instance_count = number
  vm_size        = string
  allowed_ports  = list(number)
})

type = tuple([string, number, bool])  # fixed-length, mixed types
```

### Sensitive variables

```hcl
variable "api_key" {
  type      = string
  sensitive = true    # masks the value in plan/apply output
  # NO default — ever
}
```

**Critical rule:** `sensitive = true` on a variable only masks terminal output. The value is still stored in plaintext in the Terraform state file. Key Vault (or equivalent) is required for actual security.

---

## 5. Locals Rules

```hcl
locals {
  # Derive once, use everywhere
  name_prefix = "${var.project}-${var.environment}"

  # Build the tag map here — never inside individual resource blocks
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project
    },
    var.extra_tags   # allows callers to add tags without modifying the local
  )
}
```

**Rules:**
- Define a value in `locals` if it is used in more than one place — never repeat yourself
- `locals` cannot reference each other within the same block — split into two `locals {}` blocks if needed
- `locals` are not variables — they cannot be overridden from outside. If a value needs to change per environment, it belongs in a `variable`, not a `local`
- Use `locals` to translate messy variable inputs into clean, usable values

---

## 6. Resource Block Rules

### Structure

```hcl
resource "azurerm_resource_group" "main" {   # type = "azurerm_resource_group", label = "main"
  name     = "${local.name_prefix}-rg"       # argument = value
  location = var.location
  tags     = local.common_tags

  lifecycle {                                # meta-argument block (optional)
    prevent_destroy = true
    ignore_changes  = [tags["CreatedOn"]]
  }
}
```

### Referencing other resources

```hcl
# Pattern: resource_type.label.attribute
resource "azurerm_storage_account" "main" {
  resource_group_name = azurerm_resource_group.main.name      # reference another resource's output
  location            = azurerm_resource_group.main.location
}
```

**Rules:**
- Always reference other resources by their Terraform address (`type.label.attribute`), not by hardcoding the value. This creates an implicit dependency — Terraform creates the referenced resource first automatically.
- Use `depends_on` only when the dependency is not expressed through a reference (e.g. an IAM role that must exist before a resource can be created)

---

## 7. Lifecycle Rules

```hcl
lifecycle {
  prevent_destroy = true          # blocks terraform destroy for this resource
  ignore_changes  = [             # ignores diffs on specified attributes after creation
    tags["CreatedOn"],
    tags["LastModified"]
  ]
  create_before_destroy = true    # creates replacement before destroying original (reduces downtime)

  precondition {                  # checked before the resource is created/updated
    condition     = length(local.storage_name) <= 24
    error_message = "Derived storage name is too long."
  }
}
```

**Rules:**
- `prevent_destroy = true` cannot be conditional — it does not accept variable expressions. It is always on or always off in a given config.
- `ignore_changes` takes a list of attribute references, not strings
- Use `ignore_changes = [tags["CreatedOn"]]` on every resource that uses `timestamp()` in its tags — otherwise every apply will show a diff
- `precondition` is for checks that depend on derived/computed values (things you cannot check at the `variable` validation level)

---

## 8. Output Rules

```hcl
output "resource_group_name" {
  description = "Name of the resource group."   # always include
  value       = azurerm_resource_group.main.name

  sensitive = true   # use when the output could expose secret values
}
```

**Rules:**
- Always write a `description` on every output
- Mark outputs `sensitive = true` if they contain or could derive secret values
- `sensitive = true` on an output prevents it from appearing in plain `terraform output` — but it is still readable via `terraform output -json`. It is not a security control; it is a visibility control.
- Never create an output that exposes a secret API key, password, or connection string. Applications should read secrets directly from Key Vault, not from Terraform outputs.

---

## 9. Azure Resource Naming Rules (Hard Limits)

These are Azure's rules — Terraform cannot override them. Violations cause API errors.

| Resource | Allowed characters | Length | Case |
|---|---|---|---|
| Resource Group | Alphanumeric, hyphens, underscores, periods, parentheses | 1–90 | Case-insensitive |
| Storage Account | Lowercase letters and numbers only — **no hyphens** | 3–24 | Lowercase only |
| Key Vault | Alphanumeric and hyphens, must start with letter | 3–24 | Case-insensitive |
| Virtual Network | Alphanumeric, hyphens, underscores, periods | 2–64 | Case-insensitive |
| Subnet | Alphanumeric, hyphens, underscores, periods | 1–80 | Case-insensitive |
| NSG | Alphanumeric, hyphens, underscores, periods | 1–80 | Case-insensitive |
| Storage Container | Lowercase letters, numbers, and hyphens | 3–63 | Lowercase only |

### Storage Account name — the most common gotcha

```hcl
# Wrong — hyphens not allowed, may have uppercase
name = "${var.project}-${var.environment}-sa"   # → "myapp-dev-sa" ← INVALID

# Right — sanitize with functions
name = lower(replace("${var.project}${var.environment}sa", "-", ""))
# → "myappdevsa" ← VALID
```

**Always** validate the derived storage name with a `precondition` or variable `validation` block to catch length violations before Terraform contacts Azure.

---

## 10. Tagging Rules

### Mandatory tags (apply to every resource)

```hcl
locals {
  common_tags = {
    Environment = var.environment    # "dev" or "prod"
    ManagedBy   = "Terraform"        # always this exact string — never "terraform" or "TF"
    Project     = var.project
    CostCenter  = var.cost_center    # required by Finance
  }
}
```

### Applying tags

```hcl
# Every resource gets the common tag map
resource "azurerm_resource_group" "main" {
  tags = local.common_tags   # reference the local — never re-define the map inline
}

# Adding resource-specific tags alongside common tags
resource "azurerm_storage_account" "main" {
  tags = merge(local.common_tags, {
    Purpose = "static-hosting"
  })
}
```

### The `CreatedOn` timestamp problem

```hcl
locals {
  common_tags = {
    # ...
    CreatedOn = formatdate("YYYY-MM-DD", timestamp())
  }
}

# REQUIRED on every resource that uses this tag:
lifecycle {
  ignore_changes = [tags["CreatedOn"]]
  # Without this, every terraform apply will show a diff on every resource
  # because timestamp() produces a new value each run
}
```

**Rule:** If you include a `timestamp()` in your tags, you **must** pair it with `ignore_changes = [tags["CreatedOn"]]` on every resource. Without this, every apply will show spurious diffs even when nothing changed.

---

## 11. File & Folder Structure Rules

### Minimum required files

```
project/
├── main.tf           # all resource blocks
├── variables.tf      # all variable declarations
├── outputs.tf        # all output declarations
├── locals.tf         # all derived/computed values
├── terraform.tf      # terraform{} block + provider config
├── .gitignore        # must exist
└── stores.csv        # data files — commit these
```

### Files that must NEVER be committed to Git

```
# .gitignore — minimum required entries
*.tfvars              # may contain secrets
*.tfvars.json
.terraform/           # downloaded provider binaries
*.tfstate             # state file — contains secrets in plaintext
*.tfstate.backup
.terraform.lock.hcl   # commit this one — it pins provider versions
```

**Wait — commit `.terraform.lock.hcl` but not `.terraform/`:**
- `.terraform.lock.hcl` pins provider versions — commit it so all teammates use the same version
- `.terraform/` contains the downloaded binary — do not commit it (it's regenerated by `terraform init`)

### Environment-specific files

```
environments/
├── dev.tfvars      # dev values — no secrets
└── prod.tfvars     # prod values — no secrets
```

Secrets are never in `.tfvars` files. They are passed via environment variables:
```bash
export TF_VAR_api_key="your-secret-here"
```

---

## 12. Security & Secrets Rules

### The three levels of `sensitive` — and what each actually does

| Where applied | What it does | What it does NOT do |
|---|---|---|
| `variable "x" { sensitive = true }` | Masks value in plan/apply terminal output | Does not protect it in the state file |
| `output "x" { sensitive = true }` | Hides value from plain `terraform output` | Still readable via `terraform output -json` |
| State file | Nothing — no `sensitive` flag exists here | Value is always stored in plaintext |

### Rules

- Never put a secret default in a variable declaration
- Never hardcode secrets in any `.tf` file
- Never output secret values — let applications read from Key Vault directly
- Always store state files in a remote backend with restricted access (Azure Blob Storage with private access + encryption at rest)
- Always use RBAC role assignments over legacy Key Vault access policies
- Minimum Key Vault role: `Key Vault Secrets Officer` for write access, `Key Vault Secrets User` for read-only

---

## 13. Terraform Workflow Rules

### Always follow this order

```
terraform init        # 1. download providers, create lock file
terraform validate    # 2. syntax + validation check (no API calls)
terraform plan        # 3. preview changes — READ THIS CAREFULLY
terraform apply       # 4. make changes
terraform destroy     # 5. cleanup (only when done)
```

**Rules:**
- Never skip `terraform validate` — it catches errors locally before any API call
- Always read the full plan output before typing `yes`
- A plan showing `0 to add, 0 to change, 0 to destroy` after a second apply with no changes = correct configuration
- A plan showing changes after a second apply with no changes = something is unstable in your config — fix it
- Use `--auto-approve` only in automated pipelines, never for manual production applies
- Use `terraform destroy` for cleanup — never delete resources manually from the portal and never remove them from your `.tf` file to "hide" them

### Reading plan output symbols

```
+ resource will be CREATED
~ resource will be UPDATED in-place
- resource will be DESTROYED
-/+ resource will be DESTROYED then RECREATED (causes downtime)
<= data source will be READ
```

A `-/+` on a production resource is a red flag. Understand why before proceeding.

---

## 14. `count` vs. `for_each` Rules

### Use `count` when

- Creating a simple number of identical resources
- The number can change but the resources have no meaningful individual identity

```hcl
resource "azurerm_virtual_machine" "app" {
  count = var.env_config.instance_count
  name  = "${local.name_prefix}-vm-${count.index}"
}
```

### Use `for_each` when

- Items have a meaningful identity (a name, an ID)
- You might remove an item from the middle of the list later
- Each item produces a uniquely-named resource

```hcl
resource "azurerm_subnet" "subnets" {
  for_each = toset(var.subnets)   # convert list to set for for_each
  name     = each.key
}
```

### Why this matters — the middle-removal problem

With `count`, removing `"data"` from `["app", "data", "mgmt"]`:
- Before: index 0=app, 1=data, 2=mgmt
- After: index 0=app, 1=mgmt
- Terraform sees index 1 changed from `data` to `mgmt` → **destroys and recreates `mgmt`** even though nothing changed

With `for_each`, removing `"data"`:
- Terraform sees key `"data"` is gone → destroys only `data`
- `mgmt` is untouched ← **correct behaviour**

### `each.key` and `each.value`

```hcl
# With toset(list) — each.key == each.value == the item itself
for_each = toset(["app", "data", "mgmt"])
name     = each.key   # → "app", "data", "mgmt"

# With a map — each.key is the key, each.value is the value
for_each = { app = "10.0.0.0/24", data = "10.0.1.0/24" }
name             = each.key    # → "app"
address_prefix   = each.value  # → "10.0.0.0/24"

# With a map of objects — access object attributes via each.value
for_each = local.active_stores         # map of store objects
name     = each.value.store_name       # attribute of the object
```

---

## 15. Dynamic Block Rules

Use a `dynamic` block when you need to generate a variable number of nested blocks inside a resource — typically for security rules, IP configurations, or disk attachments.

```hcl
resource "azurerm_network_security_group" "main" {
  name = "${local.name_prefix}-nsg"
  # ...

  dynamic "security_rule" {
    for_each = var.env_config.allowed_ports
    iterator = port    # rename the loop variable — avoids confusion with outer scope

    content {
      name                       = "allow-inbound-${port.value}"
      priority                   = 100 + port.value
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(port.value)
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
```

**Rules:**
- Always use the `iterator` argument to give the loop variable a meaningful name — the default name is the block type (e.g. `security_rule`), which is confusing
- The `content {}` block is mandatory — it defines what goes inside each generated block
- For nested dynamic blocks (dynamic inside dynamic), always use `iterator` to avoid naming collision between outer and inner loop variables

---

## 16. Service Principal Rules

### Why never use your personal account for Terraform

| Personal account | Service principal |
|---|---|
| Tied to a human — breaks if they leave | Independent — survives staff changes |
| Full account permissions | Scoped to exactly what's needed |
| Hard to audit automation vs. human actions | Clearly auditable as automation |
| MFA prompts block automated runs | Non-interactive authentication |

### Minimum required role

**Contributor** — can create, modify, and delete resources, but cannot manage Azure AD or assign roles.

```bash
# Create a service principal and assign Contributor to a subscription
az ad sp create-for-rbac \
  --name "myapp-terraform-sp" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
```

### The four output values — save all four immediately

| Output key | Environment variable | Purpose |
|---|---|---|
| `appId` | `ARM_CLIENT_ID` | Who the SP is |
| `password` | `ARM_CLIENT_SECRET` | The SP's credential — shown only once |
| `tenant` | `ARM_TENANT_ID` | Which Azure AD tenant |
| (subscription) | `ARM_SUBSCRIPTION_ID` | Which Azure subscription |

```bash
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
export ARM_TENANT_ID="..."
export ARM_SUBSCRIPTION_ID="..."
```

**Rules:**
- Delete and recreate the service principal after any demo where credentials were exposed
- Never commit these four values to Git — not even in a `terraform.tfvars` file
- Set them as environment variables or store them in a CI/CD secrets manager (GitHub Secrets, Azure DevOps Library)
- Delete the service principal when the project is done — do not leave unused identities active

---

## Quick Reference Card

| Thing | Rule |
|---|---|
| `{}` | Block bodies and map literals |
| `()` | Function calls only |
| `[]` | Lists, type constraints, index access |
| `${}` | String interpolation inside `""` |
| `=>` | Key-value separator in `for` expressions |
| Variable names | `snake_case` always |
| Azure resource names | `{project}-{env}-{type}` pattern |
| Storage account names | Lowercase + numbers only, 3–24 chars, no hyphens |
| Tag keys | `PascalCase` |
| `ManagedBy` tag | Always `"Terraform"` exactly |
| Single resource label | Use `main` |
| Multiple resources | Use descriptive plural label |
| Single value variable | Singular name (`environment`) |
| Collection variable | Plural name (`subnets`, `allowed_ports`) |
| Secrets in variables | `sensitive = true` + no default |
| Secrets in outputs | Never output them — use Key Vault |
| `timestamp()` in tags | Must pair with `ignore_changes` on every resource |
| Subnet creation | Always `for_each`, never `count` |
| NSG dynamic rules | Always use `iterator` to name the loop variable |
| Workflow order | init → validate → plan → apply → destroy |
| Cleanup | Always `terraform destroy`, never manual deletion |

---

*This document covers every rule, convention, and gotcha from the learning series. When in doubt, come back here before writing code.*
