# NorthWind Retail — Terraform Solution Implementation Plan

> This document is a **detailed engineering plan**, not a finished configuration. Every code
> block is a working reference you should adapt and understand — not copy-paste blindly.
> Decisions that the brief intentionally left open are called out explicitly, with a
> recommendation and the reasoning behind it.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Part 1 — Foundation: Resource Groups, Variables, Locals](#2-part-1--foundation)
3. [Part 2 — Networking: VNet and Subnets](#3-part-2--networking)
4. [Part 3 — Security: NSG Rules from Data](#4-part-3--security)
5. [Part 4 — Storage and Naming Constraints](#5-part-4--storage-and-naming-constraints)
6. [Part 5 — Secrets and Key Vault](#6-part-5--secrets-and-key-vault)
7. [Part 6 — Data-Driven Store Resources (CSV)](#7-part-6--data-driven-store-resources)
8. [Part 7 — Guardrails and Lifecycle Rules](#8-part-7--guardrails-and-validation)
9. [Part 8 — Outputs](#9-part-8--outputs)
10. [Stretch Goals](#10-stretch-goals)
11. [Execution Order and Dependency Map](#11-execution-order-and-dependency-map)
12. [Common Pitfalls to Avoid](#12-common-pitfalls-to-avoid)

---

## 1. Project Structure

Before writing a single resource block, lay out a clean directory structure. This is not
cosmetic — the file layout directly determines how Terraform loads variables, modules, and
backends.

```
northwind-retail/
├── main.tf                  # Root-level resource orchestration
├── variables.tf             # All input variable declarations
├── locals.tf                # All locals (tags, derived names, parsed CSV)
├── outputs.tf               # All output declarations
├── terraform.tf             # terraform{} block: required_providers, backend config
│
├── terraform.tfvars         # ← NEVER COMMIT. Local dev values only.
├── .gitignore               # Must include: *.tfvars, .terraform/, *.tfstate*
│
├── environments/
│   ├── dev.tfvars           # Dev-specific variable values (no secrets)
│   └── prod.tfvars          # Prod-specific variable values (no secrets)
│
├── stores.csv               # Provided sample data — commit this, it's not sensitive
│
└── modules/
    └── network/             # (Stretch goal) reusable networking module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**Why separate `dev.tfvars` / `prod.tfvars` instead of one big map?**
Because it forces you to run `terraform apply -var-file="environments/prod.tfvars"`
deliberately — there's no way to accidentally apply prod settings to dev. The secret
(`ARM_CLIENT_SECRET`, API key) is always passed as an environment variable or a
`-var` flag at runtime, never in any committed file.

---

## 2. Part 1 — Foundation

### 2.1 The `terraform.tf` block

```hcl
# terraform.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Stretch goal: remote backend per environment
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "nwrtfstate"
  #   container_name       = "tfstate"
  #   key                  = "dev.terraform.tfstate"  # change per env
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
```

### 2.2 Input Variables — `variables.tf`

Design your variables to be the **single source of truth**. Everything else derives
from them. The `environment` variable is the master key — almost every name and tag
flows from it.

```hcl
# variables.tf

variable "environment" {
  type        = string
  description = "Deployment environment. Must be 'dev' or 'prod'."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be exactly 'dev' or 'prod'. Got: '${var.environment}'."
  }
}

variable "project" {
  type        = string
  description = "Short project identifier used in all resource names."
  default     = "nwretail"
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "eastus"
}

variable "cost_center" {
  type        = string
  description = "Finance cost center tag value. Provided per deployment."
}

variable "env_config" {
  description = "Per-environment configuration object."
  type = object({
    instance_count  = number
    vm_size         = string
    address_space   = string
    allowed_ports   = list(number)
  })

  validation {
    condition     = var.env_config.instance_count >= 1 && var.env_config.instance_count <= 10
    error_message = "instance_count must be between 1 and 10. Values above 10 require a capacity review."
  }
}

variable "subnets" {
  description = "List of subnet names to create inside the VNet."
  type        = list(string)
  default     = ["app", "data", "mgmt"]
  # At least three per environment as required. Add more here — cidrsubnet() handles the rest.
}

variable "third_party_api_key" {
  type        = string
  description = "Third-party API key. Pass via TF_VAR_third_party_api_key env variable. Never set a default."
  sensitive   = true
  # NO default = "..." here, ever.
}
```

**Important decision — `env_config` as an `object` not a flat variable set:**
The brief provides a map keyed by environment. Using a single `object` variable means
each environment's `.tfvars` file contains exactly the right shape, and you can't
accidentally mix dev's `instance_count` with prod's `vm_size`. The alternative (a
`map(object(...))` containing both environments) would mean both environments' data
are always loaded — wasteful and slightly riskier.

**Why `instance_count` capped at 10?**
Unconstrained VM counts could create unexpected Azure quota usage or cost spikes.
10 is a defensible upper bound for a retail expansion project. Document your reasoning
in a comment — the brief explicitly says to do this.

### 2.3 Locals — `locals.tf`

```hcl
# locals.tf

locals {
  # Consistent naming prefix: "nwretail-dev" or "nwretail-prod"
  name_prefix = "${var.project}-${var.environment}"

  # Common tag map — Finance requirement.
  # IMPORTANT: timestamp() is evaluated at plan time. See the warning below.
  common_tags = {
    Environment = var.environment
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
    CreatedOn   = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  }
}
```

**⚠️ Critical Design Warning — `timestamp()` and Re-runs**

`timestamp()` returns the current time at plan time. Every time you run
`terraform apply`, `CreatedOn` will show a new value — Terraform will see a diff
on every resource on every subsequent apply, even if nothing actually changed.

This is almost certainly **not** what Finance wants. There are two honest solutions:

**Option A (recommended):** Use `timestamp()` only when creating a resource, and
pin it using `ignore_changes` in a lifecycle block on every resource:

```hcl
resource "azurerm_resource_group" "main" {
  # ...
  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["CreatedOn"]]
  }
}
```

This means `CreatedOn` is set once at creation and never changed again by Terraform,
which is the semantically correct behaviour. The tag reflects actual creation time.

**Option B:** Remove `CreatedOn` from Terraform tags entirely and rely on Azure's
built-in `createdAt` metadata on the resource object. This is more reliable but
doesn't satisfy the Finance requirement literally.

**Option A is the correct choice. Apply the `ignore_changes` lifecycle rule to
every resource's `CreatedOn` tag.**

### 2.4 Resource Group

```hcl
# In main.tf

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags["CreatedOn"]]
  }
}
```

**Naming convention:** `nwretail-dev-rg` / `nwretail-prod-rg`. Derived from one
`local.name_prefix` value — not two independent hardcoded strings.

### 2.5 Environment `.tfvars` Files

```hcl
# environments/dev.tfvars
environment = "dev"
location    = "eastus"
cost_center = "CC-DEV-001"

env_config = {
  instance_count = 1
  vm_size        = "Standard_B1s"
  address_space  = "10.0.0.0/16"
  allowed_ports  = [22, 80, 443, 8080]
}
```

```hcl
# environments/prod.tfvars
environment = "prod"
location    = "eastus"
cost_center = "CC-PROD-002"

env_config = {
  instance_count = 3
  vm_size        = "Standard_D2s_v3"
  address_space  = "10.1.0.0/16"
  allowed_ports  = [80, 443]
}
```

**Run commands:**
```bash
# Dev
terraform apply -var-file="environments/dev.tfvars" \
                -var="third_party_api_key=$THIRD_PARTY_API_KEY"

# Prod
terraform apply -var-file="environments/prod.tfvars" \
                -var="third_party_api_key=$THIRD_PARTY_API_KEY"
```

---

## 3. Part 2 — Networking

### 3.1 The `count` vs. `for_each` Decision

**Use `for_each` here. Here is why this matters.**

Suppose your subnet list is `["app", "data", "mgmt"]` and you use `count`:
- `count.index` 0 = app, 1 = data, 2 = mgmt

Now someone removes `"data"` from the middle:
- `count.index` 0 = app, 1 = mgmt

Terraform sees index 1 changed from `"data"` to `"mgmt"` and index 2 disappeared.
It will **destroy and recreate** the `mgmt` subnet even though nothing about it changed.
In a live environment this is destructive and causes downtime for anything attached to mgmt.

With `for_each`, each subnet is keyed by its name (`"app"`, `"data"`, `"mgmt"`).
Removing `"data"` only destroys exactly `"data"` — `"mgmt"` is untouched.

**`for_each` is the correct choice whenever the identity of an item matters more than
its position.** Subnets have names; names are identities.

### 3.2 Virtual Network and Subnets

```hcl
# main.tf — Networking section

resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.env_config.address_space]
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags["CreatedOn"]]
  }
}

resource "azurerm_subnet" "subnets" {
  # for_each: keyed by subnet name (string), resilient to list reordering
  for_each = toset(var.subnets)

  name                 = each.key
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  # cidrsubnet(base_cidr, newbits, netnum)
  # newbits=8 carves a /24 from a /16 base.
  # index(var.subnets, each.key) gives a stable position number per name.
  address_prefixes = [
    cidrsubnet(var.env_config.address_space, 8, index(var.subnets, each.key))
  ]
}
```

**How `cidrsubnet` works:**
- Base: `10.0.0.0/16`
- `cidrsubnet("10.0.0.0/16", 8, 0)` → `10.0.0.0/24` (app subnet)
- `cidrsubnet("10.0.0.0/16", 8, 1)` → `10.0.1.0/24` (data subnet)
- `cidrsubnet("10.0.0.0/16", 8, 2)` → `10.0.2.0/24` (mgmt subnet)

If someone adds a 4th subnet to `var.subnets`, they change exactly one list in
`dev.tfvars` — no CIDR math is required. `cidrsubnet` handles it automatically.

**⚠️ Caveat with `for_each` + `index()`:**
`index()` still depends on position, so removing `"data"` from the middle would
change the `netnum` for `"mgmt"` (from 2 to 1) and Terraform would want to update
its CIDR. For subnet CIDRs this is actually destructive (changing a subnet's address
prefix requires recreation in Azure). A more robust solution is to use a
`map(string)` variable instead of a list, keyed by name with explicit CIDR values:

```hcl
# Safer alternative in variables.tf
variable "subnets" {
  type = map(string)
  default = {
    app  = "10.0.0.0/24"
    data = "10.0.1.0/24"
    mgmt = "10.0.2.0/24"
  }
}

# Then in the resource:
resource "azurerm_subnet" "subnets" {
  for_each             = var.subnets
  name                 = each.key
  address_prefixes     = [each.value]
  # ...
}
```

This decouples CIDR assignment entirely from list position — the safest design.
Use this if your environment expects subnets to ever be reordered or removed mid-project.

---

## 4. Part 3 — Security (NSG Rules from Data)

### 4.1 The Priority Problem

The brief warns: rule priorities must not collide and must be computed. Two approaches:

**Option A — position-based (simpler, fragile):**
Priority = `100 + (index * 10)`. If someone inserts port 8443 between 80 and 443,
every port after it silently changes priority on next apply.

**Option B — port-number-based (more stable, recommended):**
Priority = `100 + port_number`. Port 80 → priority 180. Port 443 → priority 543.
Port 8080 → priority 8180. No two standard ports share a number, so no collision.
Adding a new port doesn't change any other port's priority.

**Recommendation: use port-number-based priorities.** Document this choice in a comment.
The main risk is port numbers above ~64000 (Azure max priority is 4096), so add a
precondition in Part 7 to catch that.

### 4.2 NSG with Dynamic Block

```hcl
# main.tf — Security section

resource "azurerm_network_security_group" "main" {
  name                = "${local.name_prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Dynamic block — the textbook use case.
  # One security_rule block per port, generated from var.env_config.allowed_ports.
  dynamic "security_rule" {
    for_each = var.env_config.allowed_ports
    iterator = port  # explicit iterator name avoids confusion with outer scope

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

  lifecycle {
    ignore_changes = [tags["CreatedOn"]]
  }
}
```

**Why this is correct:**
- Dev's `allowed_ports = [22, 80, 443, 8080]` → generates 4 rules
- Prod's `allowed_ports = [80, 443]` → generates 2 rules
- Same HCL, genuinely different output per environment — driven purely by input data
- The `iterator = port` argument names the loop variable explicitly; without it,
  Terraform uses `security_rule` as the variable name, which is confusing

---

## 5. Part 4 — Storage and Naming Constraints

### 5.1 The Naming Constraint Problem

Azure storage account naming rules:
- Lowercase letters and numbers only
- 3 to 24 characters
- Globally unique across all of Azure

Your derived name might be something like `nwretail-dev-storage`, which fails immediately
(hyphens not allowed). You need to sanitize it programmatically.

```hcl
# In locals.tf — add this to your existing locals block

locals {
  # ... existing locals ...

  # Step 1: build raw name from components
  storage_name_raw = "${var.project}${var.environment}sa"
  # e.g.: "nwretaildevsa" (13 chars — within 3-24 limit)

  # Step 2: sanitize — lowercase, strip hyphens
  storage_name = substr(
    lower(replace(local.storage_name_raw, "-", "")),
    0,   # start index
    24   # max length
  )
  # "nwretaildevsa" → already valid. If it were longer: silently truncated to 24 chars.
}
```

**⚠️ Silent truncation is a real risk.** If two environments produce names that are
both truncated to the same 24 characters, you get a naming collision on the next apply.
The safer design is to fail loudly:

```hcl
# In variables.tf — add validation to the project variable
variable "project" {
  type        = string
  description = "Short project identifier. Maximum 8 characters to allow room for env suffix in storage names."

  validation {
    condition     = length(var.project) <= 8 && can(regex("^[a-z0-9]+$", var.project))
    error_message = "project must be lowercase alphanumeric, max 8 characters (enforced to prevent storage account name truncation)."
  }
}
```

This prevents the truncation problem entirely by catching it at input time. With
`project = "nwretail"` (8 chars) + `environment = "prod"` (4 chars) + `"sa"` (2 chars)
= 14 chars — well within the 24-char limit.

### 5.2 Storage Account and Container

```hcl
# main.tf — Storage section

resource "azurerm_storage_account" "main" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = var.environment == "prod" ? "GRS" : "LRS"
  tags                     = local.common_tags

  lifecycle {
    ignore_changes = [tags["CreatedOn"]]
    # Prevent accidental deletion of prod storage (also covered in Part 7)
  }
}

resource "azurerm_storage_container" "product_images" {
  name                  = "product-images"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
```

---

## 6. Part 5 — Secrets and Key Vault

### 6.1 Understanding the `sensitive` Keyword — Three Levels

This is the conceptually hardest part. The brief is testing whether you understand that
`sensitive = true` means **different things in different places**:

| Where you set `sensitive` | What it actually does |
|---|---|
| On a `variable` | Masks the value in plan/apply terminal output |
| On an `output` | Prevents the value appearing in `terraform output` unless you explicitly pass `-json` or use it in automation |
| Inside state file | **Does nothing.** The value is ALWAYS stored in plaintext in the state file. Key Vault is required for actual security. |

**The state file risk is real and commonly misunderstood.** Anyone with access to your
`.tfstate` file can read the API key. This is why:
1. The state file must be stored in a secure remote backend (Azure Blob Storage with
   restricted access, encryption at rest, and soft delete enabled)
2. The Key Vault secret is the authoritative storage; the state file entry is ephemeral

### 6.2 Key Vault and Secret

```hcl
# main.tf — Key Vault section

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "${local.name_prefix}-kv"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Soft delete protects against accidental or malicious deletion.
  soft_delete_retention_days = 7

  tags = local.common_tags

  lifecycle {
    ignore_changes    = [tags["CreatedOn"]]
    prevent_destroy   = true  # See Part 7 justification
  }
}

# RBAC approach: grant the deploying identity the minimum role required
# "Key Vault Secrets Officer" can set/get/delete secrets — that's all we need here.
resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "third-party-api-key"
  value        = var.third_party_api_key  # from sensitive variable, never hardcoded
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.common_tags

  # Depends on the role assignment being in place before writing the secret
  depends_on = [azurerm_role_assignment.kv_secrets_officer]
}
```

**Access policy vs. RBAC — the brief asks you to decide:**

Use RBAC role assignments (`azurerm_role_assignment`). Here's why:
- Azure access policies are a legacy model being deprecated
- RBAC integrates with Azure AD PIM (Privileged Identity Management) for just-in-time access
- The minimum role is **"Key Vault Secrets Officer"** — it can read and write secrets
  but cannot manage vault configuration or keys
- If your deployer only needs to read secrets (e.g. an app reading the API key), use
  **"Key Vault Secrets User"** instead — even more minimal

### 6.3 How the Secret Gets There Without Being Hardcoded

```bash
# Set in your shell session before running Terraform — NEVER write this in a file
export TF_VAR_third_party_api_key="sk_live_51NxYzABCDEF1234567890abcdefGHIJ"

terraform apply -var-file="environments/dev.tfvars"
# Terraform picks up TF_VAR_third_party_api_key automatically
```

The flow is:
1. You have the key in your terminal environment
2. Terraform reads it from `TF_VAR_third_party_api_key` into the sensitive variable
3. The sensitive variable is passed to `azurerm_key_vault_secret.api_key`
4. Azure stores it in Key Vault
5. Your application reads it directly from Key Vault at runtime — **never** from Terraform outputs

---

## 7. Part 6 — Data-Driven Store Resources

### 7.1 Reading and Filtering the CSV

```hcl
# In locals.tf — add to existing locals block

locals {
  # ... existing locals ...

  # Step 1: read and parse the CSV file
  all_stores = csvdecode(file("${path.module}/stores.csv"))

  # Step 2: filter to active stores only using a for expression with if clause.
  # Result is a map keyed by store_id (string) — stable, unique key for for_each.
  active_stores = {
    for store in local.all_stores :
    store.store_id => store
    if store.is_active == "true"  # csvdecode returns strings, not booleans
  }
}
```

**Why `for_each` and not `count` here:**
The brief explicitly asks you to justify this. The answer:
- Each store has a **meaningful, stable identity**: its `store_id` (`"101"`, `"104"`, etc.)
- If store 102 is deactivated in the CSV, `for_each` destroys exactly the resource for 102
- With `count`, removing store 102 would shift all subsequent indices, potentially
  destroying and recreating stores 104, 105, 106, 107, 108 — catastrophic for active stores

**Why is the key `store_id` and not `store_name`?**
`store_name` contains spaces ("Downtown Flagship") which would need sanitizing before
use as a resource name. `store_id` is a clean numeric string — safer as a map key.

### 7.2 Store Storage Containers

The brief says "your choice of resource type — a Storage Container per store is reasonable."
A storage container is the right choice here because:
- It's lightweight (no quota impact, no cost per container)
- It naturally scopes under your existing storage account
- It's trivially destroyed when a store is deactivated

```hcl
# main.tf — Store resources section

resource "azurerm_storage_container" "stores" {
  for_each = local.active_stores

  # Name must be lowercase alphanumeric + hyphens, 3-63 chars
  name = lower(
    replace("store-${each.value.store_id}-${each.value.region}", " ", "-")
  )

  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"

  # Store metadata — incorporates actual name and region per requirement
  # Note: azurerm_storage_container doesn't support tags natively;
  # if you need tagging, use a different resource type (e.g. an Azure resource tag)
}
```

**What happens when a store is deactivated?**
If `is_active` flips from `"true"` to `"false"` for store 102 and you re-run `apply`:
- The `local.active_stores` map will no longer contain `"102"`
- `for_each` will detect the missing key
- `terraform plan` will show: `azurerm_storage_container.stores["102"]` will be destroyed
- Exactly one resource is removed, nothing else is touched — this is the correct behaviour

This handles itself gracefully. No manual cleanup required.

---

## 8. Part 7 — Guardrails and Validation

### 8.1 Variable Validations (already covered above)

| Variable | Validation | Error message |
|---|---|---|
| `environment` | `contains(["dev", "prod"], ...)` | "Environment must be exactly 'dev' or 'prod'." |
| `project` | max 8 chars, alphanumeric | "project must be lowercase alphanumeric, max 8 chars." |
| `env_config.instance_count` | `>= 1 && <= 10` | "instance_count must be between 1 and 10." |

### 8.2 Precondition — Something That Cannot Be Checked at Variable Level

The brief asks for a `precondition` on a `lifecycle` block checking "something that
genuinely can't be validated at the variable level alone."

A good candidate: ensure the derived storage account name is actually valid
(after `lower()` and `replace()` transformations) and does not exceed 24 characters.
This depends on the *combination* of `var.project` and `var.environment` — not either
alone — so it can't be expressed in a single variable's `validation` block.

```hcl
resource "azurerm_storage_account" "main" {
  name                = local.storage_name
  # ... other args ...

  lifecycle {
    ignore_changes = [tags["CreatedOn"]]

    precondition {
      condition = (
        length(local.storage_name) >= 3 &&
        length(local.storage_name) <= 24 &&
        can(regex("^[a-z0-9]+$", local.storage_name))
      )
      error_message = "Derived storage account name '${local.storage_name}' is invalid. It must be 3-24 lowercase alphanumeric characters with no hyphens. Check the 'project' and 'environment' variable lengths."
    }
  }
}
```

### 8.3 `prevent_destroy` — Which Resource and Why

**Resource: `azurerm_key_vault.main` (prod only in spirit, but applied literally in HCL)**

Justification (write this as a comment in your code):

```hcl
# prevent_destroy is set on the Key Vault because:
# 1. Key Vault deletion triggers a soft-delete period during which the name is reserved.
#    Accidentally destroying and re-creating a prod Key Vault would make its secrets
#    temporarily inaccessible and require manual purge + recovery steps.
# 2. All application secrets are stored here. An accidental destroy would cause
#    immediate production outage for any service reading from this vault.
# 3. The Key Vault is not the kind of resource that gets "replaced" — it accumulates
#    secrets over time. It should only ever be decommissioned intentionally.
```

**The conditional `prevent_destroy` problem (the brief calls this "genuinely non-obvious"):**

Lifecycle arguments **cannot** reference variables. You cannot write:

```hcl
lifecycle {
  prevent_destroy = var.environment == "prod"  # THIS DOES NOT WORK
}
```

Terraform will error: lifecycle arguments must be literal values.

Your honest options are:
1. Apply `prevent_destroy = true` to both environments and accept that — it prevents
   dev Key Vault from being accidentally destroyed too, which is arguably fine
2. Use a separate `azurerm_key_vault` resource block for prod (duplicating code) — ugly
3. Use workspaces or separate state files per environment, and only set
   `prevent_destroy` in the prod configuration file — this is the cleanest approach
   and aligns with the stretch goal of separate state per environment

**Recommendation: option 1 for now, option 3 as the correct long-term architecture.**
Document your reasoning in a comment — the brief says this is a genuine constraint,
not something with an easy answer.

---

## 9. Part 8 — Outputs

```hcl
# outputs.tf

# Map of active store name → storage container resource ID
output "store_containers" {
  description = "Map of active store names to their storage container resource IDs."
  value = {
    for store_id, container in azurerm_storage_container.stores :
    local.active_stores[store_id].store_name => container.id
  }
}

# Summary of the tag set applied to resources in this environment
output "applied_tags" {
  description = "Tag set applied to all resources in this environment."
  value       = local.common_tags
  # Note: this WILL show CreatedOn timestamp — that is expected and not sensitive.
}

# Confirm resource group was created
output "resource_group_name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.main.name
}

# Key Vault URI — applications read secrets from here, not from Terraform outputs
output "key_vault_uri" {
  description = "URI of the Key Vault. Use this to read secrets from application code."
  value       = azurerm_key_vault.main.vault_uri
}

# Explicitly DO NOT output the API key value — not even as sensitive.
# The application reads the secret directly from Key Vault at runtime.
# There is no legitimate reason to output it from Terraform.
# If you added output { value = var.third_party_api_key } here,
# it would still be readable via: terraform output -json | jq .
```

**Verifying the API key doesn't leak:**
After running `apply`, run:
```bash
terraform output           # Should not show the key
terraform output -json     # Should not show the key (it's not an output)
grep -r "sk_live" .terraform/  # Should return nothing
```

The key only exists in: your environment variable, the Key Vault, and the state file
(unavoidable — this is why the state backend must be secured).

---

## 10. Stretch Goals

### 10.1 Reusable Network Module

Create `modules/network/` with the VNet + subnet + NSG resources. The module accepts:

```hcl
# modules/network/variables.tf
variable "name_prefix"    { type = string }
variable "location"       { type = string }
variable "resource_group" { type = string }
variable "address_space"  { type = string }
variable "subnets"        { type = map(string) }  # name → CIDR
variable "allowed_ports"  { type = list(number) }
variable "tags"           { type = map(string) }
```

Call it in `main.tf`:
```hcl
module "network" {
  source         = "./modules/network"
  name_prefix    = local.name_prefix
  location       = azurerm_resource_group.main.location
  resource_group = azurerm_resource_group.main.name
  address_space  = var.env_config.address_space
  subnets        = var.subnets  # if using map approach
  allowed_ports  = var.env_config.allowed_ports
  tags           = local.common_tags
}
```

### 10.2 Nested Dynamic Block with `iterator`

```hcl
dynamic "security_rule" {
  for_each = var.env_config.allowed_ports
  iterator = port

  content {
    name     = "allow-${port.value}"
    priority = 100 + port.value
    # ...

    # Example of a nested dynamic (contrived but valid):
    # If you had a list of destination address prefixes per port:
    dynamic "filter" {
      for_each = ["10.0.0.0/8"]
      iterator = addr_range   # 'iterator' prevents naming collision with outer 'port'
      content {
        address_prefix = addr_range.value
      }
    }
  }
}
```

### 10.3 Remote Backend with Separate State Per Environment

```hcl
# terraform.tf — backend block
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "nwrtfstate"
    container_name       = "tfstate"
    # The key changes per environment:
    # dev:  key = "dev.terraform.tfstate"
    # prod: key = "prod.terraform.tfstate"
    key = "REPLACE_AT_INIT_TIME"
  }
}
```

Initialize with:
```bash
terraform init -backend-config="key=dev.terraform.tfstate"
terraform init -backend-config="key=prod.terraform.tfstate"
```

This guarantees prod state and dev state are completely separate files. A mistake
in the dev run cannot touch prod state.

### 10.4 `templatefile()` for VM Startup Script

```hcl
# templates/startup.sh.tftpl
#!/bin/bash
echo "Environment: ${environment}"
echo "Debug mode: ${debug_enabled}"
%{ if debug_enabled }
set -x  # verbose logging in dev only
%{ endif }
```

```hcl
# In main.tf
resource "azurerm_linux_virtual_machine" "app" {
  # ...
  custom_data = base64encode(
    templatefile("${path.module}/templates/startup.sh.tftpl", {
      environment   = var.environment
      debug_enabled = var.environment == "dev"
    })
  )
}
```

### 10.5 `try()` for Missing Map Keys

```hcl
# Safe access to an optional config key that might not exist in all environments
local {
  backup_retention = try(var.env_config.backup_days, 7)  # default to 7 if not specified
}
```

---

## 11. Execution Order and Dependency Map

Build and run in this order to avoid dependency errors:

```
1. terraform init
   └── Downloads azurerm provider, creates lock file

2. terraform validate
   └── Catches syntax errors and variable validation failures before any API calls

3. terraform plan -var-file="environments/dev.tfvars"
   └── Review: 0 to destroy? CreatedOn diff? NSG rule count matches allowed_ports count?

4. terraform apply -var-file="environments/dev.tfvars"
   └── Resource creation order (Terraform resolves this automatically, but understand it):
       azurerm_resource_group.main
           ├── azurerm_virtual_network.main
           │   └── azurerm_subnet.subnets (for_each)
           ├── azurerm_network_security_group.main
           ├── azurerm_storage_account.main
           │   ├── azurerm_storage_container.product_images
           │   └── azurerm_storage_container.stores (for_each)
           └── azurerm_key_vault.main
               ├── azurerm_role_assignment.kv_secrets_officer
               └── azurerm_key_vault_secret.api_key (depends_on role assignment)

5. terraform apply -var-file="environments/prod.tfvars"  (repeat for prod)

6. terraform destroy -var-file="environments/dev.tfvars"  (cleanup when done)
```

---

## 12. Common Pitfalls to Avoid

| Pitfall | What actually happens | How to prevent it |
|---|---|---|
| `timestamp()` in tags without `ignore_changes` | Every apply shows a diff on every resource, even with no real changes | Add `ignore_changes = [tags["CreatedOn"]]` to every resource lifecycle |
| `count` for subnets instead of `for_each` | Removing a subnet from the middle destroys and recreates later subnets | Use `for_each = toset(var.subnets)` |
| Hardcoding storage account name | Name fails Azure validation silently or collides across environments | Derive from `lower(replace(...))` + validate in precondition |
| `sensitive = true` on variable = secret is safe | Value still stored in plaintext in state file | Secure the backend; Key Vault is the actual secret store |
| Access policy instead of RBAC on Key Vault | Legacy model, not compatible with PIM, harder to audit | Use `azurerm_role_assignment` with "Key Vault Secrets Officer" |
| `prevent_destroy = var.environment == "prod"` | Terraform errors — lifecycle args are not expressions | Accept it applies to both envs, or use separate configs per env |
| Priority = `100 + index * 10` for NSG rules | Adding a port in the middle shifts all subsequent priorities on next apply | Use `100 + port.value` (port-number-based priorities) |
| Committing `.tfvars` with secrets | Credentials in Git history forever | Add `*.tfvars` to `.gitignore`; pass secrets via `TF_VAR_*` env vars |
| Not running `terraform validate` before `plan` | Confusing API-level errors instead of clear Terraform validation messages | Always: init → validate → plan → apply |
| Filtering CSV with `count` instead of a `for` expression | Inactive stores either error or produce resources | Use `for store in local.all_stores : ... if store.is_active == "true"` |

---

*This plan covers every requirement in the brief. The code blocks are reference
implementations — you will need to wire them together into complete files, test them
against a real Azure subscription, and adapt them as you discover edge cases. The
act of doing that wiring and debugging is where the actual learning happens.*
