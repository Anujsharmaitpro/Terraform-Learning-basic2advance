# Terraform Meta-Arguments — count, for_each & for Loops
## Deep-Dive Learning Guide — Day 8 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure Storage Account Examples | PowerShell Throughout

---

## Before You Start

This is Day 8. By now you know:
- Day 1–3: Terraform fundamentals, providers, resources, dependencies
- Day 4: State file and remote backends
- Day 5: Input, output, and local variables
- Day 6: Professional file structure
- Day 7: All type constraints (string, number, bool, list, set, map, object, tuple)

Today is about **creating multiple resources from a single template**.
Instead of copy-pasting a resource block three times to create three
storage accounts, you write it once and let `count` or `for_each` repeat
it automatically. This is one of the most-used features in production Terraform.

---

## Table of Contents

1. What Are Meta-Arguments? (You've Already Used Two)
2. The Problem — Creating Multiple Resources Without Repetition
3. What Is `count`? — The Loop Counter
4. `count.index` — How Terraform Tracks Each Iteration
5. `count` with a List Variable — The Full Pattern
6. The `length()` Function — Dynamic Count
7. What Is `for_each`? — The Named Iterator
8. Why `for_each` Refuses Lists — The Duplicate Problem
9. `for_each` with a `set` — The Correct Approach
10. `each.key` and `each.value` — Accessing Values in `for_each`
11. `count` vs `for_each` — When to Use Which
12. The `for` Loop — Used Inside Output Variables
13. The Splat Expression `[*]` — Shorthand for All Elements
14. `for` Loop vs Splat — Side-by-Side Comparison
15. The Complete Working Code — All Files
16. Common Mistakes Beginners Make
17. Practice Exercises
18. Complete Cheat Sheet

---

## 1. What Are Meta-Arguments? (You've Already Used Two)

### The plain English definition

A **meta-argument** is a special argument that controls HOW Terraform
manages a resource — not WHAT the resource contains.

Regular arguments configure the resource itself:
```hcl
resource "azurerm_storage_account" "example" {
  name                     = "myaccount"       # regular argument
  location                 = "West Europe"     # regular argument
  account_tier             = "Standard"        # regular argument
}
```

Meta-arguments control Terraform's behaviour around the resource:
```hcl
resource "azurerm_storage_account" "example" {
  name  = "myaccount"
  count = 3                                    # meta-argument: create 3 copies
}
```

### Meta-arguments you have already used

The instructor pointed out you have been using meta-arguments all along:

| Meta-Argument | Covered In | What It Does |
|---|---|---|
| `depends_on` | Day 3 | Explicit dependency declaration |
| `provider` | Day 2 | Assign a specific provider configuration |
| `count` | **Today** | Create N copies of a resource |
| `for_each` | **Today** | Create one resource per item in a set/map |
| `lifecycle` | Next video | Control create/update/destroy behaviour |

Meta-arguments are NOT provider-specific — they work on ANY resource
from ANY provider, because they are part of Terraform core, not the
Azure RM plugin.

---

## 2. The Problem — Creating Multiple Resources Without Repetition

### The naive approach

You need three Azure Storage Accounts. Without meta-arguments:

```hcl
resource "azurerm_storage_account" "account1" {
  name                     = "techtutorials11"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "account2" {
  name                     = "techtutorials12"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "account3" {
  name                     = "techtutorials13"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**Problems with this:**
- 3 accounts = 3 blocks = copy-paste 3 times
- 10 accounts = 10 blocks = 10× the code
- Change `account_tier` → edit every single block
- Add a new tag → edit every single block
- Error-prone and hard to maintain

### The meta-argument solution

Write the resource once, tell Terraform how many times to create it:

```hcl
resource "azurerm_storage_account" "example" {
  count                    = 3                    # create 3 copies
  name                     = "account${count.index}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

One block. Three resources. Change anything once — all three update.

---

## 3. What Is `count`? — The Loop Counter

### The simple definition

`count` tells Terraform: "Create this many copies of this resource."

```hcl
count = 1    # create 1 resource (default behaviour — same as no count)
count = 2    # create 2 resources
count = 5    # create 5 resources
count = 0    # create 0 resources (useful for conditional creation)
```

### How Terraform tracks each copy

When `count` is used, Terraform tracks the resources using a numeric
index in square brackets:

```
count = 2 creates:
  azurerm_storage_account.example[0]   ← first copy
  azurerm_storage_account.example[1]   ← second copy
```

Without count, the resource address is just:
```
azurerm_storage_account.example
```

With count, it becomes:
```
azurerm_storage_account.example[0]
azurerm_storage_account.example[1]
```

This is why the terraform plan output showed `example[0]` when the
instructor added `count = 1` — even with count of 1, Terraform switches
to indexed tracking.

---

## 4. `count.index` — How Terraform Tracks Each Iteration

### What `count.index` is

Inside a resource block that uses `count`, a special value called
`count.index` is available. It holds the current iteration number:

```
First iteration:  count.index = 0
Second iteration: count.index = 1
Third iteration:  count.index = 2
```

### Why you need it

If you create 2 storage accounts with the same name, Azure will reject
the second one — storage account names must be globally unique. You need
`count.index` to make each name different:

```hcl
resource "azurerm_storage_account" "example" {
  count = 2
  name  = "techtutorials1${count.index}"
  # First iteration:  name = "techtutorials10"
  # Second iteration: name = "techtutorials11"
}
```

### The problem the instructor showed

```hcl
# count = 2 but SAME name for both — this will fail in Azure
resource "azurerm_storage_account" "example" {
  count = 2
  name  = "techtutorials11"    # ← same name both times!
  # Azure error: "Storage account name already exists"
}
```

The plan doesn't fail because Terraform validates names only at apply time
(when it actually calls the Azure API). But once the first account is
created, the second creation fails with a duplicate name error.

---

## 5. `count` with a List Variable — The Full Pattern

### The instructor's solution

Instead of hardcoding names, define them in a list variable and use
`count.index` to pick the right name for each iteration:

**`variables.tf`**
```hcl
variable "storage_account_names" {
  type        = list(string)
  description = "List of storage account names to create"
  default     = ["techtutorials11", "techtutorials12"]
}
```

**`storage_account.tf`**
```hcl
resource "azurerm_storage_account" "example" {
  count = length(var.storage_account_names)   # 2 (length of the list)

  name = var.storage_account_names[count.index]
  # count.index = 0 → var.storage_account_names[0] = "techtutorials11"
  # count.index = 1 → var.storage_account_names[1] = "techtutorials12"

  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

### Tracing through the two iterations

```
ITERATION 1:
  count.index = 0
  name = var.storage_account_names[0] = "techtutorials11"
  → Creates: azurerm_storage_account.example[0] named "techtutorials11"

ITERATION 2:
  count.index = 1
  name = var.storage_account_names[1] = "techtutorials12"
  → Creates: azurerm_storage_account.example[1] named "techtutorials12"

DONE: 2 storage accounts with unique names
```

### What `terraform plan` shows with this setup

```
Terraform will perform the following actions:

  # azurerm_storage_account.example[0] will be created
  + resource "azurerm_storage_account" "example" {
      + name = "techtutorials11"
      ...
    }

  # azurerm_storage_account.example[1] will be created
  + resource "azurerm_storage_account" "example" {
      + name = "techtutorials12"
      ...
    }

Plan: 3 to add, 0 to change, 0 to destroy.
(1 resource group + 2 storage accounts = 3)
```

---

## 6. The `length()` Function — Dynamic Count

### Why hardcoding count is bad

```hcl
count = 2    # hardcoded — fragile
```

If you add a third name to your list variable but forget to update `count = 2`,
only two storage accounts are created. The third name in the list is ignored.

### The `length()` function

`length()` returns the number of elements in a list, set, or map:

```hcl
length(["a", "b", "c"])     # returns 3
length(["x", "y"])          # returns 2
```

### Using `length()` with `count`

```hcl
variable "storage_account_names" {
  type    = list(string)
  default = ["techtutorials11", "techtutorials12"]  # 2 items
}

resource "azurerm_storage_account" "example" {
  count = length(var.storage_account_names)    # automatically = 2
  name  = var.storage_account_names[count.index]
  ...
}
```

Now add a third name to the variable:

```hcl
default = ["techtutorials11", "techtutorials12", "techtutorials13"]
```

Terraform automatically creates 3 accounts — `count` updates because
`length()` recalculates. No manual number changes needed.

### The pattern you should always use

```hcl
# ❌ Fragile — hardcoded count
count = 2

# ✅ Dynamic — always matches the list length
count = length(var.storage_account_names)
```

---

## 7. What Is `for_each`? — The Named Iterator

### The problem with `count`

`count` works great but has a significant limitation: it uses numeric
indexes (`[0]`, `[1]`, `[2]`). If you remove an item from the MIDDLE
of your list, the indexes shift, and Terraform may destroy and recreate
the wrong resources.

**Example of the `count` ordering problem:**
```
Before: ["accountA", "accountB", "accountC"]
  [0] = "accountA"
  [1] = "accountB"
  [2] = "accountC"

Remove "accountB":
After: ["accountA", "accountC"]
  [0] = "accountA"
  [1] = "accountC"   ← was [2], now [1]

Terraform sees: [1] changed from "accountB" to "accountC"
                [2] was destroyed (no longer in list)
Result: Terraform DESTROYS accountC and RENAMES accountB to accountC
        This is NOT what you wanted!
```

`for_each` solves this by using STRING KEYS instead of numeric indexes.
Resources are tracked by their name, not their position.

### How `for_each` works conceptually

Instead of "create N copies," `for_each` says: "create one resource for
each unique item in this collection, tracking each by its VALUE."

```
for_each = {"accountA", "accountB", "accountC"}
Creates:
  azurerm_storage_account.example["accountA"]
  azurerm_storage_account.example["accountB"]
  azurerm_storage_account.example["accountC"]
```

Remove "accountB":
```
for_each = {"accountA", "accountC"}
Terraform sees: ["accountB"] should be destroyed
                ["accountA"] unchanged
                ["accountC"] unchanged
Result: Only accountB is destroyed. Exactly what you wanted.
```

---

## 8. Why `for_each` Refuses Lists — The Duplicate Problem

### The restriction

`for_each` ONLY accepts:
- A `set` of strings
- A `map`

It does NOT accept a `list`.

### Why? — Duplicates

Lists can contain duplicate values:
```hcl
["accountA", "accountB", "accountA"]   # "accountA" appears twice!
```

If `for_each` used this list, which resource should "accountA" refer to?
The first one? The second one? There is no way to know — it's ambiguous.

For `for_each` to work, every key must be unique. Sets guarantee
uniqueness. Maps have unique keys by definition. Lists do not.

### The error the instructor hit

```hcl
variable "storage_account_names" {
  type    = list(string)     # ← list type
  default = ["techtutorials11", "techtutorials12"]
}

resource "azurerm_storage_account" "example" {
  for_each = var.storage_account_names   # ← using list with for_each
}
```

Error from Terraform:
```
Error: Invalid for_each argument

The given "for_each" argument value is unsuitable:
the "for_each" argument must be a map, or set of strings,
and you have provided a value of type list of string.
```

Then the instructor tried using `length(var.storage_account_names)` with
`for_each`:
```
Error: Invalid for_each argument
...you have provided a value of type number.
```

Because `length()` returns a NUMBER, and `for_each` needs a set or map.

### The fix — change the variable type to `set`

```hcl
variable "storage_account_names" {
  type    = set(string)    # ← changed from list to set
  default = ["techtutorials11", "techtutorials12"]
}
```

Sets automatically deduplicate and have no ordering — exactly what
`for_each` needs.

---

## 9. `for_each` with a `set` — The Correct Approach

### The complete syntax

```hcl
variable "storage_account_names" {
  type        = set(string)
  description = "Set of unique storage account names to create"
  default     = ["techtutorials11", "techtutorials12"]
}

resource "azurerm_storage_account" "example" {
  for_each = var.storage_account_names    # set variable

  name                     = each.value   # the current item in the set
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

### What Terraform creates

```
for_each = {"techtutorials11", "techtutorials12"}

Creates:
  azurerm_storage_account.example["techtutorials11"]
  azurerm_storage_account.example["techtutorials12"]
```

The resources are now tracked by their STRING NAME, not a number.

---

## 10. `each.key` and `each.value` — Accessing Values in `for_each`

### The two accessor expressions

Inside a resource block that uses `for_each`, two special values are
available:

| Expression | For a SET | For a MAP |
|---|---|---|
| `each.key` | The current element's value | The current entry's key |
| `each.value` | Same as `each.key` for sets | The current entry's value |

### For a SET (one value per item)

When `for_each` iterates over a set, each item has only one piece of
data — the value itself. Both `each.key` and `each.value` return the
same thing:

```hcl
for_each = toset(["techtutorials11", "techtutorials12"])

# Iteration 1:
each.key   = "techtutorials11"
each.value = "techtutorials11"   # same as each.key for sets

# Iteration 2:
each.key   = "techtutorials12"
each.value = "techtutorials12"
```

Use either — they're identical for sets.

### For a MAP (key + value per item)

When `for_each` iterates over a map, each item has two pieces of data:

```hcl
for_each = {
  "primary"   = "techtutorials11"
  "secondary" = "techtutorials12"
}

# Iteration 1:
each.key   = "primary"             # the map key
each.value = "techtutorials11"     # the map value

# Iteration 2:
each.key   = "secondary"           # the map key
each.value = "techtutorials12"     # the map value
```

### Practical Azure example with a map

```hcl
variable "storage_accounts" {
  type = map(string)
  default = {
    "primary"   = "techtutorials11"
    "secondary" = "techtutorials12"
    "backup"    = "techtutorials13"
  }
}

resource "azurerm_storage_account" "example" {
  for_each = var.storage_accounts

  name = each.value                          # the actual storage account name
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  account_tier        = "Standard"
  account_replication_type = "LRS"

  tags = {
    Role = each.key                          # "primary", "secondary", "backup"
    Name = each.value                        # the storage account name
  }
}
```

---

## 11. `count` vs `for_each` — When to Use Which

This is the most important decision. Here is the complete guide:

### Use `count` when:

```
✅ Resources are identical except for a sequential index
✅ You have a list of values and need index-based access
✅ You want to conditionally create a resource (count = condition ? 1 : 0)
✅ The number of resources comes from a simple number variable
```

Example — conditional resource creation with `count`:
```hcl
variable "create_backup_account" {
  type    = bool
  default = false
}

resource "azurerm_storage_account" "backup" {
  count = var.create_backup_account ? 1 : 0   # create 1 if true, 0 if false
  name  = "backupaccount2024"
  ...
}
```

### Use `for_each` when:

```
✅ Resources have meaningful names (not just index numbers)
✅ You may need to add/remove individual resources without affecting others
✅ You're working with a set or map of values
✅ Each resource needs to be identifiable by a human-readable key
```

### Side-by-side comparison

```
SCENARIO: Create 2 storage accounts named "techtutorials11" and "techtutorials12"

WITH count:
  resource "azurerm_storage_account" "example" {
    count = length(var.storage_account_names)
    name  = var.storage_account_names[count.index]
  }
  Tracked as: example[0], example[1]

WITH for_each:
  resource "azurerm_storage_account" "example" {
    for_each = var.storage_account_names  # set type variable
    name     = each.value
  }
  Tracked as: example["techtutorials11"], example["techtutorials12"]
```

### The ordering danger with `count`

```
Remove "techtutorials11" from the beginning of the list:

count — DANGEROUS:
  Before: [0]="techtutorials11"  [1]="techtutorials12"
  After:  [0]="techtutorials12"
  Terraform: "account at [0] changed name" → DESTROYS AND RECREATES!

for_each — SAFE:
  Before: {"techtutorials11", "techtutorials12"}
  After:  {"techtutorials12"}
  Terraform: "techtutorials11" should be destroyed, "techtutorials12" unchanged
  → Only deletes the right one. No unexpected recreations.
```

### Quick decision rule

```
Question: "If I remove one item from my collection, should ALL the
           other resources be unaffected?"

YES → Use for_each (tracked by name, immune to ordering)
NO  → count may be fine (tracked by index)

Question: "Are my resources identical except for a number?"
YES → count is perfect
NO  → for_each with set or map
```

---

## 12. The `for` Loop — Used Inside Output Variables

### What is the `for` loop in Terraform?

The `for` loop in Terraform is NOT used to create resources (that's what
`count` and `for_each` are for). It is used to **transform or extract
values from a collection** — most commonly inside output variable values.

Think of it as "process each item in this collection and build a result."

### The syntax

```hcl
# Produce a list
[for item in collection : expression]

# Produce a map
{for item in collection : key_expression => value_expression}
```

### Simple example — extract all storage account names

```hcl
# In outputs.tf
output "storage_names" {
  value = [for i in azurerm_storage_account.example : i.name]
}
```

Breaking it down:
```
[                                     ← result is a list
  for i                               ← "i" is the loop counter/variable
  in azurerm_storage_account.example  ← iterate over all instances of this resource
  : i.name                            ← for each instance, take the name attribute
]
```

When Terraform runs this with two storage accounts:
```
i → azurerm_storage_account.example["techtutorials11"]  → i.name = "techtutorials11"
i → azurerm_storage_account.example["techtutorials12"]  → i.name = "techtutorials12"

Result: ["techtutorials11", "techtutorials12"]
```

### The instructor's full output variable example

```hcl
# outputs.tf

# Simple resource group name (single resource, no loop needed)
output "rg_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.example.name
}

# All storage account names using for loop
output "storage_name" {
  description = "All created storage account names"
  value       = [for i in azurerm_storage_account.example : i.name]
}
```

**`terraform plan` output:**
```
Changes to Outputs:
  + rg_name      = "staging-resources"
  + storage_name = [
      + "techtutorials11",
      + "techtutorials12",
    ]
```

### The loop variable name is your choice

The instructor used `i` as the loop variable. You can use any name:

```hcl
[for account in azurerm_storage_account.example : account.name]
[for sa in azurerm_storage_account.example : sa.name]
[for item in azurerm_storage_account.example : item.name]
[for i in azurerm_storage_account.example : i.name]
# All produce the same result — the variable name is just a placeholder
```

### For loop producing a map (key → value)

```hcl
output "storage_name_to_location" {
  description = "Map of storage account name to its location"
  value = {
    for i in azurerm_storage_account.example :
    i.name => i.location
  }
}

# Result:
# {
#   "techtutorials11" = "westeurope"
#   "techtutorials12" = "westeurope"
# }
```

---

## 13. The Splat Expression `[*]` — Shorthand for All Elements

### What it is

The splat expression `[*]` is a shortcut that collects one specific
attribute from ALL instances of a resource into a list. It's a shorter
alternative to a `for` loop when you just need one field from every instance.

### The syntax

```hcl
resource_type.name[*].attribute
```

### Example — all storage account names

```hcl
# Using for loop (longer):
output "storage_names" {
  value = [for i in azurerm_storage_account.example : i.name]
}

# Using splat (shorter, same result):
output "storage_names" {
  value = azurerm_storage_account.example[*].name
}

# Both produce: ["techtutorials11", "techtutorials12"]
```

### The instructor's Resource Group splat example

```hcl
output "rg_name" {
  value = azurerm_resource_group.example[*].name
}
# Produces: ["staging-resources"]
# (array with one element because only one resource group)

# Access first element:
output "rg_name_first" {
  value = azurerm_resource_group.example[*].name[0]
}
# Produces: "staging-resources"
```

### Splat with count-based resources

```hcl
resource "azurerm_storage_account" "example" {
  count = 3
  name  = "account${count.index}"
  ...
}

output "all_names" {
  value = azurerm_storage_account.example[*].name
}
# Produces: ["account0", "account1", "account2"]

output "all_ids" {
  value = azurerm_storage_account.example[*].id
}
# Produces: ["/subscriptions/.../account0", "/.../account1", "/.../account2"]
```

### Splat with for_each resources

Note: Splat `[*]` works with `count` resources directly. For `for_each`
resources, you need `values()` first:

```hcl
# With count — splat works directly
azurerm_storage_account.example[*].name

# With for_each — use values() then splat, or use for loop
[for i in azurerm_storage_account.example : i.name]
# OR
values(azurerm_storage_account.example)[*].name
```

---

## 14. `for` Loop vs Splat — Side-by-Side Comparison

```
GOAL: Get the names of all storage accounts

SPLAT (simple, one field):
  value = azurerm_storage_account.example[*].name
  Result: ["techtutorials11", "techtutorials12"]

FOR LOOP (flexible, can transform):
  value = [for i in azurerm_storage_account.example : i.name]
  Result: ["techtutorials11", "techtutorials12"]

FOR LOOP with transformation:
  value = [for i in azurerm_storage_account.example : upper(i.name)]
  Result: ["TECHTUTORIALS11", "TECHTUTORIALS12"]

FOR LOOP with filter:
  value = [for i in azurerm_storage_account.example : i.name if i.account_tier == "Standard"]
  Result: only names where tier is Standard

WHEN TO USE WHICH:
  Splat   → when you need ONE field from ALL instances, no transformation
  For Loop → when you need to transform, filter, or build a different structure
```

---

## 15. The Complete Working Code — All Files

**`provider.tf`**
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

---

**`variables.tf`**
```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "staging"
}

variable "location" {
  type        = list(string)
  description = "Allowed Azure regions"
  default     = ["West Europe", "North Europe", "East US"]
}

# For COUNT example — list type, access by index
variable "storage_account_names_list" {
  type        = list(string)
  description = "Storage account names for count-based creation"
  default     = ["techtutorials11", "techtutorials12"]
}

# For FOR_EACH example — set type, guarantees uniqueness
variable "storage_account_names_set" {
  type        = set(string)
  description = "Unique storage account names for for_each creation"
  default     = ["techtutorials11", "techtutorials12"]
}
```

---

**`resource_group.tf`**
```hcl
resource "azurerm_resource_group" "example" {
  name     = "${var.environment}-resources"
  location = var.location[0]    # "West Europe" (index 0)
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

---

**`storage_account_count.tf`** — demonstrates `count`
```hcl
# EXAMPLE A: Using count with a list variable
# Use this OR the for_each version, not both at once
resource "azurerm_storage_account" "by_count" {
  count = length(var.storage_account_names_list)
  # count = 2 (because the list has 2 items)

  name = var.storage_account_names_list[count.index]
  # Iteration 0: name = "techtutorials11"
  # Iteration 1: name = "techtutorials12"

  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.environment
    Index       = count.index    # shows which iteration created this
  }
}
```

---

**`storage_account_foreach.tf`** — demonstrates `for_each`
```hcl
# EXAMPLE B: Using for_each with a set variable
resource "azurerm_storage_account" "by_foreach" {
  for_each = var.storage_account_names_set
  # Iterates: "techtutorials11", "techtutorials12"

  name = each.value
  # each.value = "techtutorials11" (first iteration)
  # each.value = "techtutorials12" (second iteration)

  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment   = var.environment
    AccountName   = each.key    # same as each.value for sets
  }
}
```

---

**`outputs.tf`**
```hcl
# Simple single value
output "rg_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.example.name
}

# Using splat — all names from count-based resources
output "storage_names_via_splat" {
  description = "All storage account names (via splat)"
  value       = azurerm_storage_account.by_count[*].name
}

# Using for loop — all names from for_each-based resources
output "storage_names_via_for_loop" {
  description = "All storage account names (via for loop)"
  value       = [for i in azurerm_storage_account.by_foreach : i.name]
}

# For loop producing a map
output "storage_name_to_id" {
  description = "Map of storage account name to Azure resource ID"
  value = {
    for i in azurerm_storage_account.by_foreach :
    i.name => i.id
  }
}

# All resource group names with splat
output "rg_names_list" {
  description = "Resource group names as a list"
  value       = azurerm_resource_group.example[*].name
}
```

---

**`terraform.tfvars`**
```hcl
environment = "staging"

location = ["West Europe", "North Europe", "East US"]

storage_account_names_list = ["techtutorials11", "techtutorials12"]

storage_account_names_set  = ["techtutorials11", "techtutorials12"]
```

---

**PowerShell — full workflow:**

```powershell
# Navigate to project folder
Set-Location "day08"

# Set Azure Service Principal credentials
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# Step 1: Initialise providers
terraform init

# Step 2: Validate syntax
terraform validate

# Step 3: Preview what will be created
terraform plan

# Step 4: Check which resources will be created (filter plan output)
terraform plan | Select-String "will be created"

# Step 5: Apply
terraform apply --auto-approve

# Step 6: View outputs
terraform output

# Step 7: View a specific output
terraform output storage_names_via_splat

# Step 8: Get output in JSON format (useful for scripts)
terraform output -json

# Step 9: Clean up ALL resources
terraform destroy --auto-approve

# Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 16. Common Mistakes Beginners Make

### Mistake 1 — Using `for_each` with a list

```hcl
# ❌ FAILS — for_each doesn't accept list
variable "names" {
  type    = list(string)    # ← list
  default = ["acc1", "acc2"]
}

resource "azurerm_storage_account" "example" {
  for_each = var.names    # ❌ Error: must be map or set of string
}

# ✅ FIXED — change variable type to set
variable "names" {
  type    = set(string)    # ← set
  default = ["acc1", "acc2"]
}

resource "azurerm_storage_account" "example" {
  for_each = var.names    # ✅ Works
  name     = each.value
}
```

---

### Mistake 2 — Using `length()` as the value for `for_each`

```hcl
# ❌ FAILS — length() returns a number, for_each needs set/map
for_each = length(var.names)    # Error: you provided type number

# ✅ For for_each, pass the collection directly
for_each = var.names            # The set or map itself
```

---

### Mistake 3 — Accessing count resources without an index in outputs

```hcl
# If you created with count:
resource "azurerm_storage_account" "example" {
  count = 2
  ...
}

# ❌ WRONG — no index specified
output "name" {
  value = azurerm_storage_account.example.name    # Error: use index or splat
}

# ✅ Specific index
output "first_name" {
  value = azurerm_storage_account.example[0].name
}

# ✅ All names via splat
output "all_names" {
  value = azurerm_storage_account.example[*].name
}
```

---

### Mistake 4 — Same name for all count iterations

```hcl
# ❌ All resources get the same name — Azure will reject duplicates
resource "azurerm_storage_account" "example" {
  count = 3
  name  = "myaccount"    # same for all 3 iterations!
}

# ✅ Use count.index to make names unique
resource "azurerm_storage_account" "example" {
  count = 3
  name  = "myaccount${count.index}"    # "myaccount0", "myaccount1", "myaccount2"
}
```

---

### Mistake 5 — Using `count.index` inside `for_each`

```hcl
# ❌ count.index is only available inside count blocks
resource "azurerm_storage_account" "example" {
  for_each = var.names
  name     = "account${count.index}"    # Error: count.index not available here
}

# ✅ Use each.value (or each.key) inside for_each blocks
resource "azurerm_storage_account" "example" {
  for_each = var.names
  name     = each.value
}
```

---

### Mistake 6 — Using `each.key`/`each.value` inside count

```hcl
# ❌ each.key/each.value only available inside for_each blocks
resource "azurerm_storage_account" "example" {
  count = 2
  name  = each.value    # Error: each is not available in count blocks
}

# ✅ Use count.index inside count blocks
resource "azurerm_storage_account" "example" {
  count = 2
  name  = var.names[count.index]
}
```

---

### Mistake 7 — Mixing `count` and `for_each` on the same resource

```hcl
# ❌ Cannot use both on the same resource
resource "azurerm_storage_account" "example" {
  count    = 2
  for_each = var.names    # Error: cannot use both
}

# ✅ Use one or the other
resource "azurerm_storage_account" "example" {
  count = 2              # ← only count
}
```

---

## 17. Practice Exercises

### Exercise 1 — `count` with a list

You have this variable:
```hcl
variable "environment_names" {
  type    = list(string)
  default = ["dev", "staging", "prod"]
}
```

Write a resource block that creates ONE Azure Resource Group per environment
using `count`, where each group is named `"rg-dev"`, `"rg-staging"`, `"rg-prod"`.

**Answer:**
```hcl
resource "azurerm_resource_group" "envs" {
  count    = length(var.environment_names)
  name     = "rg-${var.environment_names[count.index]}"
  location = "West Europe"
  tags = {
    Environment = var.environment_names[count.index]
  }
}
```

---

### Exercise 2 — `for_each` with a set

Rewrite Exercise 1 using `for_each` instead of `count`.
First, decide what type the variable should be.

**Answer:**
```hcl
variable "environment_names" {
  type    = set(string)    # Changed from list to set for for_each
  default = ["dev", "staging", "prod"]
}

resource "azurerm_resource_group" "envs" {
  for_each = var.environment_names
  name     = "rg-${each.value}"
  location = "West Europe"
  tags = {
    Environment = each.key
  }
}
```

---

### Exercise 3 — Output with `for` loop

After creating the resource groups in Exercise 2, write an output that
produces a list of all resource group names.

**Answer:**
```hcl
output "rg_names" {
  description = "List of all created resource group names"
  value       = [for rg in azurerm_resource_group.envs : rg.name]
}
# Result: ["rg-dev", "rg-staging", "rg-prod"]
```

---

### Exercise 4 — Splat expression

After creating storage accounts with `count = 3`, write outputs for:
a) All storage account names
b) All storage account primary blob endpoints

**Answer:**
```hcl
# a) All names via splat
output "all_storage_names" {
  value = azurerm_storage_account.example[*].name
}

# b) All endpoints via splat
output "all_blob_endpoints" {
  value = azurerm_storage_account.example[*].primary_blob_endpoint
}
```

---

### Exercise 5 — Predict the Error

What error does this produce, and how do you fix it?

```hcl
variable "accounts" {
  type    = list(string)
  default = ["account1", "account2", "account3"]
}

resource "azurerm_storage_account" "example" {
  for_each = var.accounts
  name     = each.value
}
```

**Answer:**
```
Error: Invalid for_each argument
The "for_each" argument must be a map, or set of strings,
and you have provided a value of type list of string.

Fix: Change the variable type from list(string) to set(string):

variable "accounts" {
  type    = set(string)    ← changed
  default = ["account1", "account2", "account3"]
}
```

---

## 18. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║       TERRAFORM count, for_each, for — DAY 8 QUICK REFERENCE                ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  META-ARGUMENTS OVERVIEW                                                     ║
║  depends_on  → explicit dependency (Day 3)                                   ║
║  provider    → assign specific provider (Day 2)                             ║
║  count       → create N copies of a resource                                ║
║  for_each    → create one resource per item in set/map                      ║
║  lifecycle   → control create/update/destroy (next video)                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  count                                                                       ║
║                                                                              ║
║  count = 3                           # hardcoded (fragile)                  ║
║  count = length(var.names)           # dynamic (recommended)                ║
║                                                                              ║
║  Inside the block:                                                           ║
║    count.index = 0, 1, 2, ...        # current iteration number             ║
║    var.names[count.index]            # access list item by index             ║
║                                                                              ║
║  Resource addresses: resource.name[0], resource.name[1]                     ║
║  Works with: list variables, number variables                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  for_each                                                                    ║
║                                                                              ║
║  for_each = var.names_set            # set(string) variable                 ║
║  for_each = var.names_map            # map(string) variable                 ║
║  for_each = toset(["a","b","c"])     # inline set                           ║
║                                                                              ║
║  Inside the block:                                                           ║
║    each.key   = current key (or value for sets)                             ║
║    each.value = current value (same as key for sets)                        ║
║                                                                              ║
║  Resource addresses: resource.name["key1"], resource.name["key2"]           ║
║  ONLY works with: set(string), map — NOT list!                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  count vs for_each                                                           ║
║                                                                              ║
║  count:    tracked by index [0][1][2] — removing middle item shifts indexes ║
║  for_each: tracked by key  ["a"]["b"] — removing one key doesn't affect     ║
║            others ← SAFER for collections that change over time             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  for LOOP (in outputs, locals — NOT for creating resources)                  ║
║                                                                              ║
║  List result:                                                                ║
║  [for item in resource.name : item.attribute]                               ║
║                                                                              ║
║  Map result:                                                                 ║
║  {for item in resource.name : item.key => item.value}                       ║
║                                                                              ║
║  With filter:                                                                ║
║  [for item in resource.name : item.name if item.tier == "Standard"]         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SPLAT EXPRESSION [*]                                                        ║
║                                                                              ║
║  resource.name[*].attribute  → list of that attribute from ALL instances    ║
║  resource.name[*].name       → all names                                    ║
║  resource.name[*].id         → all IDs                                      ║
║                                                                              ║
║  Works directly with count resources.                                        ║
║  For for_each: use values(resource.name)[*].attribute                       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMON ERRORS AND FIXES                                                     ║
║                                                                              ║
║  "for_each must be map or set ... provided list"                             ║
║  → Change variable type from list(string) to set(string)                    ║
║                                                                              ║
║  "for_each must be map or set ... provided number"                           ║
║  → You passed length(var.x) instead of var.x to for_each                   ║
║                                                                              ║
║  "count.index not available"                                                 ║
║  → You're inside for_each, use each.value instead                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL COMMANDS                                                         ║
║                                                                              ║
║  Set credentials:  $env:ARM_CLIENT_ID = "..."                               ║
║  Init:             terraform init                                            ║
║  Validate:         terraform validate                                        ║
║  Plan:             terraform plan                                            ║
║  Filter plan:      terraform plan | Select-String "will be created"         ║
║  Apply:            terraform apply --auto-approve                           ║
║  Outputs:          terraform output                                          ║
║  Output JSON:      terraform output -json                                    ║
║  Destroy:          terraform destroy --auto-approve                         ║
║  Clear creds:      Remove-Item Env:ARM_CLIENT_ID                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
Meta-arguments control HOW Terraform manages resources, not WHAT they contain.

count    = a loop that runs N times, numbered 0, 1, 2...
           "make 3 copies of this, numbered 0, 1, 2"
           Use count.index to access the current number
           Use var.list[count.index] to access list items

for_each = a loop that runs once per NAMED item
           "make one copy for each item in this collection"
           Use each.value to access the current item's value
           Resources tracked by NAME not number — safer to add/remove

for loop  = transform a collection into output values
            NOT for creating resources — only for expressions in
            output blocks, locals, and variable defaults

[*] splat = "take THIS ONE field from ALL instances"
            Shorthand for a simple for loop with one field
```

---

*Guide covers: Terraform meta-arguments, count meta-argument, count.index,
count with list variable, length() function, dynamic count, for_each meta-argument,
for_each with set, for_each with map, each.key, each.value, list vs set for for_each,
count vs for_each comparison, index ordering problem, for loop in output variables,
for loop syntax, for loop producing list, for loop producing map, splat expression
[*], values() function for for_each resources, conditional resource creation with
count, Azure storage account naming uniqueness, azurerm_storage_account, terraform
plan output reading, Plan N to add, Select-String PowerShell, ARM_* environment
variables in PowerShell, terraform init/validate/plan/apply/destroy.*
