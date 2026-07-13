# Terraform Built-in Functions — Complete Practical Guide
## Deep-Dive Learning Guide — Day 11 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure Examples | PowerShell Commands Throughout

---

## Before You Start

This is Day 11. By now you know:
- Day 1–3: Fundamentals, providers, resources, dependencies
- Day 4: State file and remote backends
- Day 5: Variables (input, output, local)
- Day 6: Professional file structure
- Day 7: Type constraints
- Day 8: `count`, `for_each`, `for` loops
- Day 9: Lifecycle meta-arguments
- Day 10: Dynamic blocks, conditional expressions, splat

Today is about **built-in functions** — pre-built tools that transform,
manipulate, and validate your data. You don't need to write the logic.
You just call the function with your data and get the result.

This is a **heavy practice video**. The instructor works through 4 real
assignments — each one solving a genuine Azure infrastructure naming or
configuration challenge using functions. Every iteration, every mistake,
and every fix is documented here so you learn from the process, not just
the final answer.

---

## Table of Contents

1. What Are Functions in Terraform? (And What Makes Them Special)
2. The `terraform console` — Your Function Playground
3. Function Categories — The Full Map
4. Numeric Functions — `max`, `min`, `abs`, `ceil`, `floor`
5. String Functions — `lower`, `upper`, `replace`, `trim`, `substr`, `chomp`
6. Collection Functions — `merge`, `concat`, `contains`, `length`, `flatten`
7. Type Conversion Functions — `tostring`, `tonumber`, `tolist`, `toset`
8. Date & Time Functions — `timestamp`, `formatdate`
9. Function Nesting — Calling Functions Inside Functions
10. ASSIGNMENT 1 — Resource Name Formatter (`lower` + `replace`)
11. ASSIGNMENT 2 — Resource Tag Merger (`merge`)
12. ASSIGNMENT 3 — Storage Account Name Validator (`substr` + `lower` + `replace`)
13. ASSIGNMENT 4 — NSG Rule Name Generator (`split` + `for` loop + maps)
14. The `split` vs `join` Functions — Critical Difference
15. Common Function Mistakes and Fixes
16. The Complete Working Code — All Files
17. Practice Exercises
18. Complete Cheat Sheet

---

## 1. What Are Functions in Terraform?

### The plain English definition

A **function** is a named, pre-built operation that takes one or more
inputs and returns a result. You call it by writing its name followed
by parentheses containing the input values.

```hcl
function_name(input1, input2, ...)
```

Think of functions like appliances in a kitchen:
- `lower()` is like a blender that liquifies everything into lowercase
- `replace()` is like a search-and-replace in Word
- `merge()` is like combining two ingredient lists into one
- `length()` is like counting items in a bowl

### Why functions exist

Without functions, you'd have to hardcode every variation of every
resource name. With functions, you transform data programmatically:

```hcl
# Without functions — fragile, manual, error-prone
name = "project-alpha-resource"

# With functions — dynamic, safe, consistent
name = lower(replace(var.project_name, " ", "-"))
# If project_name = "Project Alpha Resource"
# Result: "project-alpha-resource"
```

### The critical limitation — no custom functions

Terraform does NOT allow you to create your own functions. You are
limited to the built-in functions provided by HashiCorp. This is
intentional — it keeps Terraform configurations portable and predictable.

If you need custom logic, you build it by combining multiple built-in
functions together (function nesting — covered in Section 9).

---

## 2. The `terraform console` — Your Function Playground

### What it is

`terraform console` opens an interactive command-line where you can
test Terraform expressions and functions WITHOUT modifying any `.tf` files
and WITHOUT creating any real Azure resources.

It's like a calculator for Terraform expressions.

### How to open it

**PowerShell:**
```powershell
# Navigate to your project folder (must have been terraform init'd)
Set-Location "C:\projects\day11"
terraform init    # if not already done
terraform console # opens the interactive console
```

You'll see a `>` prompt:
```
>
```

Type any Terraform expression and press Enter to see the result immediately.

### Basic usage examples

```
> max(2, 4, 1)
4

> min(2, 5, 3)
2

> lower("HELLO WORLD")
"hello world"

> length(["a", "b", "c"])
3
```

### How to exit the console

```
> exit
# OR press Ctrl+C
# OR press Ctrl+D (on Mac/Linux)
```

**PowerShell equivalent (exit the console):**
```powershell
# Inside terraform console, type:
exit
```

### Why the instructor used it

The console lets you test a function before putting it in your code.
If you're unsure about the argument order for `split()`, test it in
the console first. Get the right result there, then paste it into
your `.tf` file.

```
> split(",", "80,443,3306")
tolist([
  "80",
  "443",
  "3306",
])
```

This is much faster than writing code → running `terraform plan` →
reading an error → fixing → repeating.

---

## 3. Function Categories — The Full Map

```
TERRAFORM BUILT-IN FUNCTIONS
│
├── NUMERIC FUNCTIONS
│   max(), min(), abs(), ceil(), floor(), log(), pow(), signum()
│
├── STRING FUNCTIONS
│   lower(), upper(), replace(), trim(), trimprefix(), trimsuffix()
│   substr(), split(), join(), chomp(), format(), formatlist()
│   regex(), regexall(), startswith(), endswith()
│
├── COLLECTION FUNCTIONS
│   length(), merge(), concat(), flatten(), contains(), distinct()
│   element(), index(), keys(), values(), lookup(), zipmap()
│   tolist(), toset(), tomap(), sort(), reverse()
│
├── TYPE CONVERSION FUNCTIONS
│   tostring(), tonumber(), tobool(), tolist(), toset(), tomap()
│
├── DATE & TIME FUNCTIONS
│   timestamp(), timeadd(), formatdate()
│
├── FILESYSTEM FUNCTIONS
│   file(), fileexists(), fileset(), filebase64()
│
├── ENCODING FUNCTIONS
│   base64encode(), base64decode(), jsonencode(), jsondecode()
│   urlencode(), yamlencode(), yamldecode()
│
└── HASH & CRYPTO FUNCTIONS
    md5(), sha1(), sha256(), sha512(), bcrypt(), uuid(), uuidv5()
```

This guide focuses on the ones you'll use in real Azure projects:
numeric, string, collection, type conversion, and date/time.

---

## 4. Numeric Functions

### `max(number, number, ...)` — highest value

```hcl
# In terraform console:
max(2, 4, 1)     # → 4
max(10, 5, 8)    # → 10

# Practical use: maximum replica count
locals {
  replica_count = max(var.min_replicas, 2)   # always at least 2
}
```

### `min(number, number, ...)` — lowest value

```hcl
min(2, 5, 3)     # → 2
min(100, 50)     # → 50

# Practical use: cap disk size at a maximum
locals {
  disk_size = min(var.requested_disk_gb, 1024)   # never exceed 1TB
}
```

### `abs(number)` — absolute value (removes negative sign)

```hcl
abs(-5)    # → 5
abs(3)     # → 3
```

### `ceil(number)` — round UP to nearest integer

```hcl
ceil(1.1)   # → 2
ceil(4.0)   # → 4
ceil(4.9)   # → 5
```

### `floor(number)` — round DOWN to nearest integer

```hcl
floor(4.9)   # → 4
floor(4.1)   # → 4
```

---

## 5. String Functions

### `lower(string)` — converts to lowercase

```hcl
lower("HELLO WORLD")        # → "hello world"
lower("West Europe")        # → "west europe"
lower("Project-Alpha")      # → "project-alpha"

# Azure storage accounts require all lowercase
name = lower(var.storage_name)
```

### `upper(string)` — converts to uppercase

```hcl
upper("hello")     # → "HELLO"
upper("dev")       # → "DEV"
```

### `replace(string, old, new)` — replaces substrings

**Argument order:** `replace(original_string, what_to_replace, replace_with)`

```hcl
replace("hello world", " ", "-")   # → "hello-world"
replace("my.resource", ".", "-")   # → "my-resource"
replace("dev env", " ", "")        # → "devenv"  (remove spaces)

# Azure resource names can't have spaces
name = replace(var.project_name, " ", "-")
```

### `trim(string, chars_to_remove)` — removes characters from start AND end

**Important:** `trim()` removes every occurrence of specified characters
from the BEGINNING AND END of the string only — NOT from the middle.

```hcl
trim("hello!", "!")     # → "hello"    (removes ! from end)
trim("xxhelloxx", "x")  # → "hello"    (removes x from both ends)
trim("   hello   ", " ") # → "hello"   (removes spaces from edges)

# Does NOT remove from the middle:
trim("h!ell!o", "!")    # → "h!ell!o"  (! in middle stays!)
```

### `trimprefix(string, prefix)` — removes prefix

```hcl
trimprefix("rg-my-resource", "rg-")    # → "my-resource"
trimprefix("dev-server", "dev-")        # → "server"
```

### `trimsuffix(string, suffix)` — removes suffix

```hcl
trimsuffix("my-resource-rg", "-rg")    # → "my-resource"
trimsuffix("server.local", ".local")   # → "server"
```

### `substr(string, offset, length)` — extracts a substring

**Argument order:** `substr(string, start_position, max_length)`

```hcl
substr("hello world", 0, 5)    # → "hello"   (start=0, length=5)
substr("hello world", 6, 5)    # → "world"   (start=6, length=5)
substr("abcdefghij", 0, 23)    # → "abcdefghij" (fewer than 23 chars — takes all)

# Azure storage accounts: max 24 chars
name = substr(var.account_name, 0, 23)   # truncate to 23 chars
```

### `chomp(string)` — removes trailing newline characters

```hcl
chomp("hello\n")    # → "hello"
chomp("hello\r\n")  # → "hello"

# Useful when reading file contents
```

### `split(separator, string)` — splits a string into a list

**Argument order:** `split(separator, string)` — separator FIRST, string SECOND

```hcl
split(",", "80,443,3306")    # → ["80", "443", "3306"]
split("/", "a/b/c")          # → ["a", "b", "c"]
split(" ", "hello world")    # → ["hello", "world"]
```

**The instructor's mistake:** He initially called `split(string, separator)` —
wrong order. The error gave `","` as the result because the entire
original string was treated as the separator. Always: separator first.

### `join(separator, list)` — joins a list into a string

```hcl
join(",", ["80", "443", "3306"])    # → "80,443,3306"
join("-", ["project", "alpha"])     # → "project-alpha"
join("", ["a", "b", "c"])           # → "abc"
```

### `format(spec, values...)` — sprintf-style string formatting

```hcl
format("Hello, %s!", "world")          # → "Hello, world!"
format("Port %d", 443)                 # → "Port 443"
format("%s-%s-rg", "myapp", "staging") # → "myapp-staging-rg"
```

---

## 6. Collection Functions

### `length(collection)` — count of elements

```hcl
length(["a", "b", "c"])          # → 3
length({ a = 1, b = 2 })         # → 2
length("hello")                   # → 5 (characters in string)

# Dynamic count based on list size
count = length(var.storage_names)
```

### `merge(map1, map2, ...)` — combines maps

**When maps have the same key, the LAST map's value wins:**

```hcl
merge(
  { env = "staging", team = "platform" },
  { env = "prod",    owner = "alice" }
)
# → { env = "prod", team = "platform", owner = "alice" }
# env from first map overwritten by second map
```

### `concat(list1, list2, ...)` — combines lists

```hcl
concat(["a", "b"], ["c", "d"])     # → ["a", "b", "c", "d"]
concat([1, 2], [3, 4], [5])        # → [1, 2, 3, 4, 5]
```

### `contains(collection, value)` — checks if value exists

```hcl
contains(["dev", "staging", "prod"], "staging")  # → true
contains(["dev", "staging"], "prod")             # → false

# Used in preconditions
condition = contains(var.allowed_locations, var.location)
```

### `distinct(list)` — removes duplicates from a list

```hcl
distinct(["a", "b", "a", "c", "b"])    # → ["a", "b", "c"]
```

### `flatten(list_of_lists)` — collapses nested lists into one

```hcl
flatten([["a", "b"], ["c", "d"]])    # → ["a", "b", "c", "d"]
flatten([[1, 2], [3], [4, 5]])       # → [1, 2, 3, 4, 5]
```

### `keys(map)` — returns all keys of a map

```hcl
keys({ name = "alice", role = "admin", env = "prod" })
# → ["env", "name", "role"]  (alphabetical order)
```

### `values(map)` — returns all values of a map

```hcl
values({ name = "alice", role = "admin" })
# → ["alice", "admin"]
```

### `lookup(map, key, default)` — safe map access with a fallback

```hcl
lookup({ env = "staging" }, "env", "unknown")     # → "staging"
lookup({ env = "staging" }, "owner", "unknown")   # → "unknown" (key doesn't exist)
# Without lookup: accessing missing key causes an error
```

---

## 7. Type Conversion Functions

### `tostring(value)` — converts to string

```hcl
tostring(80)     # → "80"
tostring(true)   # → "true"
tostring(3.14)   # → "3.14"
```

### `tonumber(value)` — converts to number

```hcl
tonumber("80")    # → 80
tonumber("3.14")  # → 3.14
```

### `tolist(set_or_tuple)` — converts to list

```hcl
tolist(toset(["c", "a", "b"]))    # → ["a", "b", "c"] (sorted)
```

### `toset(list)` — converts to set (deduplicates)

```hcl
toset(["a", "b", "a", "c"])    # → {"a", "b", "c"} (duplicate removed)
```

---

## 8. Date & Time Functions

### `timestamp()` — current UTC time as a string

```hcl
timestamp()    # → "2024-01-15T10:30:00Z"

# Tag resources with creation time
tags = {
  CreatedAt = timestamp()
}
```

### `formatdate(format, timestamp)` — format a timestamp

```hcl
formatdate("YYYY-MM-DD", timestamp())     # → "2024-01-15"
formatdate("DD MMM YYYY", timestamp())    # → "15 Jan 2024"
```

---

## 9. Function Nesting — Calling Functions Inside Functions

This is the most powerful technique with functions. You can chain them
by wrapping one function call inside another.

### The concept

```hcl
outer_function(inner_function(input))
```

The inner function runs first, its result becomes the input to the outer function.

### The example from the instructor

```hcl
# Goal: lowercase AND replace spaces with hyphens

# Step 1 — replace spaces with hyphens:
replace("Project Alpha Resource", " ", "-")
# Result: "Project-Alpha-Resource"

# Step 2 — lowercase the result:
lower("Project-Alpha-Resource")
# Result: "project-alpha-resource"

# Nested version (both in one expression):
lower(replace("Project Alpha Resource", " ", "-"))
# Result: "project-alpha-resource"  ← same result, one line
```

### Three-level nesting (Assignment 3)

```hcl
# Goal: lowercase, remove spaces, remove special chars, max 23 chars

substr(
  lower(
    replace(
      replace(var.storage_account_name, " ", ""),
      "!@#$%^&*()", ""
    )
  ),
  0,
  23
)
```

Execution order (inside-out):
1. `replace(var.storage_account_name, " ", "")` — remove spaces
2. `replace(result, "!@#$%^&*()", "")` — remove special chars
3. `lower(result)` — make lowercase
4. `substr(result, 0, 23)` — truncate to 23 chars

---

## 10. ASSIGNMENT 1 — Resource Name Formatter

### The requirement

Your company requires all Azure resource names to be:
- Lowercase only
- Spaces replaced with hyphens
- Example: `"Project Alpha Resource"` → `"project-alpha-resource"`

Functions needed: `lower()`, `replace()`

### The solution — step by step

**`variables.tf`**
```hcl
variable "project_name" {
  type        = string
  description = "Name of the project (will be formatted automatically)"
  default     = "Project Alpha Resource"
}
```

**`locals.tf`**
```hcl
locals {
  # Step 1: Replace spaces with hyphens
  # replace(string, " ", "-") → "Project-Alpha-Resource"

  # Step 2: Make lowercase (wraps step 1)
  # lower(result) → "project-alpha-resource"

  formatted_name = lower(replace(var.project_name, " ", "-"))
  # "Project Alpha Resource" → "project-alpha-resource"
}
```

**`main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${local.formatted_name}-rg"
  # → "project-alpha-resource-rg"

  location = "West US 2"

  tags = {
    OriginalName  = var.project_name
    FormattedName = local.formatted_name
  }
}
```

**`outputs.tf`**
```hcl
output "rg_name" {
  description = "The formatted Resource Group name"
  value       = azurerm_resource_group.rg.name
}
# Output: "project-alpha-resource-rg"
```

**Test in terraform console first:**
```
> lower(replace("Project Alpha Resource", " ", "-"))
"project-alpha-resource"
```

---

## 11. ASSIGNMENT 2 — Resource Tag Merger

### The requirement

You have two maps of tags:
- `default_tags` — applied to all resources in the organisation
- `environment_tags` — specific to this deployment environment

Merge them into one combined map and apply to the Resource Group.
Functions needed: `merge()`

### The solution

**`variables.tf`**
```hcl
variable "default_tags" {
  type        = map(string)
  description = "Organisation-wide default tags"
  default = {
    ManagedBy   = "Terraform"
    Owner       = "Platform Team"
  }
}

variable "environment_tags" {
  type        = map(string)
  description = "Environment-specific tags"
  default = {
    Environment = "staging"
    CostCentre  = "IT-001"
  }
}
```

**`locals.tf`**
```hcl
locals {
  # merge() combines multiple maps into one
  # If same key appears in multiple maps, the LAST map wins
  merged_tags = merge(var.default_tags, var.environment_tags)
  # Result:
  # {
  #   ManagedBy   = "Terraform"
  #   Owner       = "Platform Team"
  #   Environment = "staging"
  #   CostCentre  = "IT-001"
  # }
}
```

**`main.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${local.formatted_name}-rg"
  location = "West US 2"
  tags     = local.merged_tags    # all four tags applied at once
}
```

**`outputs.tf`**
```hcl
output "applied_tags" {
  description = "All tags applied to resources"
  value       = local.merged_tags
}
```

**Test in terraform console:**
```
> merge({"a" = "1", "b" = "2"}, {"c" = "3", "b" = "overridden"})
{
  "a" = "1"
  "b" = "overridden"
  "c" = "3"
}
```

### Why use a local instead of merge() directly in the resource?

If you call `merge(var.default_tags, var.environment_tags)` in every
resource block, you repeat that function call everywhere. Using a local
means you compute the merged result once and reference `local.merged_tags`
everywhere — cleaner, faster, and consistent.

---

## 12. ASSIGNMENT 3 — Storage Account Name Validator

### The requirement

Azure Storage Account naming rules:
- Maximum 24 characters
- Lowercase letters and numbers ONLY
- No hyphens, spaces, special characters

Your input variable might be messy (has uppercase, spaces, special chars).
Clean it up automatically using functions.

Functions needed: `lower()`, `replace()`, `substr()`

### The instructor's journey — all iterations shown

**The input variable:**
```hcl
variable "storage_account_name" {
  type    = string
  default = "Tech Tutorials! 2024 Special"
  # Problems: uppercase, spaces, special char (!), too long
}
```

**Iteration 1 — truncate to 23 chars:**
```hcl
locals {
  storage_formatted = substr(var.storage_account_name, 0, 23)
  # "Tech Tutorials! 2024 Sp"
  # Still has uppercase, spaces, special char!
}
```

Result from plan:
```
Error: "name" may only contain lowercase letters and numbers
```

**Iteration 2 — add lowercase:**
```hcl
locals {
  storage_formatted = substr(lower(var.storage_account_name), 0, 23)
  # "tech tutorials! 2024 sp"
  # Still has spaces and special char!
}
```

Still fails — spaces aren't allowed.

**Iteration 3 — remove spaces with replace:**
```hcl
locals {
  storage_formatted = substr(
    lower(replace(var.storage_account_name, " ", "")),
    0, 23
  )
  # replace removes spaces: "TechTutorials!2024Special"
  # lower makes it: "techtutorials!2024special"
  # substr truncates: "techtutorials!2024spec"  ← still has !
}
```

Still fails — `!` is not allowed.

**Final Solution — remove special chars with second replace:**
```hcl
locals {
  storage_formatted = substr(
    lower(
      replace(
        replace(var.storage_account_name, " ", ""),
        "!", ""
      )
    ),
    0, 23
  )
}
```

For production, use a more comprehensive special character removal:
```hcl
locals {
  # Step 1: Remove spaces
  no_spaces = replace(var.storage_account_name, " ", "")

  # Step 2: Remove common special characters one by one
  no_special_1 = replace(local.no_spaces, "!", "")
  no_special_2 = replace(local.no_special_1, "@", "")
  no_special_3 = replace(local.no_special_2, "#", "")

  # Step 3: Lowercase
  lowercased = lower(local.no_special_3)

  # Step 4: Truncate to 23 characters (max 24, leave 1 for safety)
  storage_formatted = substr(local.lowercased, 0, 23)
}
```

**Complete storage account resource:**
```hcl
resource "azurerm_storage_account" "example" {
  name                     = local.storage_formatted
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.merged_tags
}
```

**`outputs.tf`**
```hcl
output "storage_account_name" {
  description = "The validated and formatted storage account name"
  value       = azurerm_storage_account.example.name
}
```

**Test in console before writing code:**
```
> substr(lower(replace(replace("Tech Tutorials! 2024", " ", ""), "!", "")), 0, 23)
"techtutorials2024"
```

---

## 13. ASSIGNMENT 4 — NSG Rule Name Generator

### The requirement

Given a list of ports (`80`, `443`, `3306`), automatically generate
NSG security rule names in the format `"port-80"`, `"port-443"`, `"port-3306"`.

Functions needed: `split()`, `join()`, `for` loop, nested maps

### Understanding `split()` — argument order matters!

```hcl
# CORRECT order: separator FIRST, then the string
split(",", "80,443,3306")
# → ["80", "443", "3306"]

# WRONG order (instructor's mistake):
split("80,443,3306", ",")
# → ["80,443,3306"] (entire string becomes one element, comma is "separator")
```

The instructor made this mistake in the video. Always remember:
**separator first**, string second.

### The solution

**`variables.tf`**
```hcl
variable "allowed_ports" {
  type        = string
  description = "Comma-separated list of allowed ports"
  default     = "80,443,3306"
  # Stored as a string, will be split into a list
}
```

**`locals.tf`**
```hcl
locals {
  # Step 1: Split comma-separated string into a list
  # split(separator, string) → separator FIRST
  formatted_ports = split(",", var.allowed_ports)
  # → ["80", "443", "3306"]

  # Step 2: Build a map of NSG rules using for loop
  # Each port gets a rule with name, port, and description
  nsg_rules = {
    for port in local.formatted_ports : "port-${port}" => {
      name        = "port-${port}"
      port        = port
      description = "Allow traffic on port ${port}"
      priority    = 100 + index(local.formatted_ports, port) * 10
    }
  }
  # Result:
  # {
  #   "port-80" = { name="port-80", port="80", description="Allow...80", priority=100 }
  #   "port-443" = { name="port-443", port="443", description="Allow...443", priority=110 }
  #   "port-3306" = { name="port-3306", port="3306", description="Allow...3306", priority=120 }
  # }
}
```

**`nsg.tf`**
```hcl
resource "azurerm_network_security_group" "example" {
  name                = "${local.formatted_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.merged_tags

  dynamic "security_rule" {
    for_each = local.nsg_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = security_rule.value.description
    }
  }
}
```

**`outputs.tf`** additions:
```hcl
output "nsg_rules" {
  description = "Map of all generated NSG rules"
  value       = local.nsg_rules
}

output "security_group_name" {
  description = "Name of the Network Security Group"
  value       = azurerm_network_security_group.example.name
}
```

**Test the `split` in console:**
```
> split(",", "80,443,3306")
tolist([
  "80",
  "443",
  "3306",
])
```

**Test the rule generation in console:**
```
> [for p in split(",", "80,443,3306") : "port-${p}"]
[
  "port-80",
  "port-443",
  "port-3306",
]
```

---

## 14. The `split` vs `join` Functions — Critical Difference

These two functions are opposites of each other:

```
split(separator, string) → takes ONE string, gives back a LIST
join(separator, list)    → takes a LIST, gives back ONE string
```

```hcl
# split: "80,443" → ["80", "443"]
split(",", "80,443")       # string → list

# join: ["80", "443"] → "80,443"
join(",", ["80", "443"])   # list → string
```

### When to use each

```
split() → You receive a comma-separated string and need to loop over each item
           e.g., var.ports = "80,443,3306" → need to iterate over each port

join()  → You have a list and need to produce a readable string
           e.g., ["port-80","port-443"] → "port-80, port-443" for a description
```

### The instructor's confusion

He tried using `join()` inside the for loop to add hyphens between
values. But `join()` produces a string, and the dynamic block needed
a map. Once he converted the for loop result to a proper map structure
(with name, port, description fields), the `join()` was no longer needed.

The lesson: choose the right function for what the receiving end expects.
A dynamic block's `for_each` needs a map. A `join()` produces a string.
They're incompatible — don't mix them up.

---

## 15. Common Function Mistakes and Fixes

### Mistake 1 — Wrong argument order for `split`

```hcl
# ❌ WRONG — string first, separator second
split("80,443,3306", ",")    # Returns one-element list!

# ✅ CORRECT — separator first, string second
split(",", "80,443,3306")    # → ["80", "443", "3306"]
```

**How to remember:** Think `split(",", string)` — the separator is
between the parentheses first, like a knife you use to cut.

---

### Mistake 2 — Wrong argument order for `trim`

```hcl
# trim(string, chars_to_remove) — string first, chars second
trim("hello!", "!")    # ✅ → "hello"
trim("!", "hello!")    # ❌ wrong order — will trim "h", "e", "l", "o" from "!"
```

---

### Mistake 3 — Expecting `trim` to remove middle characters

```hcl
# trim only removes from START and END, not the middle
trim("h!ell!o", "!")    # → "h!ell!o"  ← unchanged! ! in middle stays
trim("!hello!", "!")    # → "hello"     ← works, ! only at edges
```

To remove a character from ALL positions, use `replace`:
```hcl
replace("h!ell!o", "!", "")    # → "hello"  ← removes all occurrences
```

---

### Mistake 4 — Using `where.` instead of `local.` for locals

```hcl
# ❌ Wrong
name = where.formatted_name    # "where" is for variables (var.)

# ✅ Correct
name = local.formatted_name    # locals use "local."
```

---

### Mistake 5 — Nesting functions in the wrong order

```hcl
# Goal: lowercase then truncate

# ❌ Wrong order — truncates FIRST then lowercases
# (truncated text might still be too long after lowercase changes nothing)
lower(substr(var.name, 0, 23))

# ✅ Better — lowercase FIRST then truncate
# (ensures the full lowercase string before trimming to max length)
substr(lower(var.name), 0, 23)
```

---

### Mistake 6 — Using `join` where a map is needed for `for_each`

```hcl
# ❌ join() returns a STRING — for_each needs a map or set
locals {
  nsg_rules = join("-", [for p in local.ports : "port-${p}"])
  # → "port-80-port-443-port-3306"  (a string, not a map!)
}

resource "azurerm_network_security_group" "example" {
  dynamic "security_rule" {
    for_each = local.nsg_rules    # ❌ Error: can't iterate a string
  }
}

# ✅ Use a for loop that produces a MAP
locals {
  nsg_rules = {
    for p in local.ports : "port-${p}" => { port = p, priority = 100 }
  }
}
```

---

## 16. The Complete Working Code — All Files

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
# Assignment 1 — Resource Name Formatter
variable "project_name" {
  type        = string
  description = "Project name (will be auto-formatted: lowercase + hyphens)"
  default     = "Project Alpha Resource"
}

# Assignment 2 — Tag Merger
variable "default_tags" {
  type        = map(string)
  description = "Organisation-wide default tags"
  default = {
    ManagedBy = "Terraform"
    Owner     = "Platform Team"
  }
}

variable "environment_tags" {
  type        = map(string)
  description = "Environment-specific tags"
  default = {
    Environment = "staging"
    CostCentre  = "IT-001"
  }
}

# Assignment 3 — Storage Account Validator
variable "storage_account_name" {
  type        = string
  description = "Raw storage account name (will be auto-formatted)"
  default     = "Tech Tutorials! 2024 Special"
}

# Assignment 4 — NSG Port Rules
variable "allowed_ports" {
  type        = string
  description = "Comma-separated ports to allow inbound (e.g. 80,443,3306)"
  default     = "80,443,3306"
}
```

---

**`locals.tf`**
```hcl
# ── Assignment 1: Name Formatting ──────────────────────────────────────
locals {
  # Replace spaces with hyphens, then lowercase everything
  formatted_name = lower(replace(var.project_name, " ", "-"))
  # "Project Alpha Resource" → "project-alpha-resource"
}

# ── Assignment 2: Tag Merging ───────────────────────────────────────────
locals {
  # Merge default + environment tags into one map
  merged_tags = merge(var.default_tags, var.environment_tags)
  # { ManagedBy="Terraform", Owner="Platform Team",
  #   Environment="staging", CostCentre="IT-001" }
}

# ── Assignment 3: Storage Account Name Validation ──────────────────────
locals {
  # Chain of operations: remove spaces → remove special chars → lowercase → truncate
  sa_no_spaces   = replace(var.storage_account_name, " ", "")
  sa_no_special  = replace(local.sa_no_spaces, "!", "")
  sa_lowercased  = lower(local.sa_no_special)
  storage_formatted = substr(local.sa_lowercased, 0, 23)
  # "Tech Tutorials! 2024 Special" → "techtutorials2024spec"
}

# ── Assignment 4: NSG Rule Generation ──────────────────────────────────
locals {
  # Split comma-separated port string into a list
  formatted_ports = split(",", var.allowed_ports)
  # "80,443,3306" → ["80", "443", "3306"]

  # Generate a map of NSG rules from the ports list
  nsg_rules = {
    for port in local.formatted_ports :
    "port-${port}" => {
      name        = "port-${port}"
      port        = port
      description = "Allow inbound traffic on port ${port}"
      priority    = 100 + index(local.formatted_ports, port) * 10
    }
  }
  # {
  #   "port-80"   = { name="port-80",   port="80",   description="...", priority=100 }
  #   "port-443"  = { name="port-443",  port="443",  description="...", priority=110 }
  #   "port-3306" = { name="port-3306", port="3306", description="...", priority=120 }
  # }
}
```

---

**`resource_group.tf`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "${local.formatted_name}-rg"
  location = "West US 2"
  tags     = local.merged_tags
}
```

---

**`storage_account.tf`**
```hcl
resource "azurerm_storage_account" "example" {
  name                     = local.storage_formatted
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.merged_tags
}
```

---

**`nsg.tf`**
```hcl
resource "azurerm_network_security_group" "example" {
  name                = "${local.formatted_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.merged_tags

  dynamic "security_rule" {
    for_each = local.nsg_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = security_rule.value.description
    }
  }
}
```

---

**`outputs.tf`**
```hcl
output "rg_name" {
  description = "Formatted Resource Group name"
  value       = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  description = "Validated and formatted Storage Account name"
  value       = azurerm_storage_account.example.name
}

output "nsg_name" {
  description = "Network Security Group name"
  value       = azurerm_network_security_group.example.name
}

output "nsg_rules_output" {
  description = "All generated NSG rules"
  value       = local.nsg_rules
}

output "applied_tags" {
  description = "All merged tags applied to resources"
  value       = local.merged_tags
}
```

---

**`terraform.tfvars`**
```hcl
project_name          = "Project Alpha Resource"
storage_account_name  = "Tech Tutorials! 2024 Special"
allowed_ports         = "80,443,3306"

default_tags = {
  ManagedBy = "Terraform"
  Owner     = "Platform Team"
}

environment_tags = {
  Environment = "staging"
  CostCentre  = "IT-001"
}
```

---

**PowerShell — full workflow:**

```powershell
# Navigate to project
Set-Location "C:\projects\day11"

# Set Azure authentication
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# Initialise
terraform init

# Open the console to test functions before coding
terraform console
# Inside console, test functions:
# > lower(replace("Project Alpha Resource", " ", "-"))
# > split(",", "80,443,3306")
# > merge({"a"="1"}, {"b"="2"})
# > substr("techtutorials2024special", 0, 23)
# > exit

# Validate
terraform validate

# Plan and review function outputs
terraform plan

# Apply
terraform apply --auto-approve

# View outputs to confirm function results
terraform output

# Specific outputs
terraform output rg_name
terraform output storage_account_name
terraform output nsg_rules_output

# Clean up
terraform destroy --auto-approve

# Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 17. Practice Exercises

### Exercise 1 — Console Practice

Open `terraform console` and evaluate these expressions:

```
a) max(5, 2, 8, 1)
b) lower("AZURE WEST EUROPE")
c) replace("my resource group", " ", "-")
d) length(["dev", "staging", "prod"])
e) split(",", "eastus,westeurope,northeurope")
f) join(" | ", ["port-80", "port-443"])
g) substr("verylongstorageaccountname", 0, 23)
h) merge({"a"="1"}, {"b"="2", "a"="overridden"})
```

**Answers:**
```
a) 8
b) "azure west europe"
c) "my-resource-group"
d) 3
e) ["eastus", "westeurope", "northeurope"]
f) "port-80 | port-443"
g) "verylongstorageaccountna"
h) { a = "overridden", b = "2" }
```

---

### Exercise 2 — Fix the Broken Functions

Find the error in each expression:

```hcl
a) split("80,443", ",")
b) lower(replace("Hello World", "-", " "))
c) substr("hello", 3)       ← missing argument
d) merge(["tag1", "tag2"])  ← wrong type
```

**Answers:**
```hcl
a) Argument order wrong — separator must be first:
   split(",", "80,443")

b) Arguments to replace are wrong — should replace space with hyphen:
   lower(replace("Hello World", " ", "-"))

c) substr needs 3 arguments: string, offset, length:
   substr("hello", 0, 3)   → "hel"

d) merge() takes maps, not lists:
   merge({tag1 = "value1"}, {tag2 = "value2"})
```

---

### Exercise 3 — Write the Function Chain

Given `var.env_name = "  Development Environment!! "`, write a local
that produces a clean storage account name: no spaces, no `!`, lowercase,
max 23 chars.

**Answer:**
```hcl
locals {
  clean_env = substr(
    lower(
      replace(
        replace(
          replace(var.env_name, " ", ""),
          "!", ""
        ),
        "  ", ""
      )
    ),
    0, 23
  )
}
# "  Development Environment!! " → "developmentenvironmen"
```

---

### Exercise 4 — Tag Merge with Override

Write a locals block that merges three tag maps:
- `base_tags` = `{Team = "Infra", ManagedBy = "Terraform"}`
- `dept_tags` = `{Department = "Engineering", Team = "Platform"}`
- `env_tags`  = `{Environment = "prod"}`

The final `Team` value should be `"Platform"` (from dept_tags, which
overrides base_tags).

**Answer:**
```hcl
locals {
  all_tags = merge(
    { Team = "Infra", ManagedBy = "Terraform" },
    { Department = "Engineering", Team = "Platform" },
    { Environment = "prod" }
  )
}
# Result:
# { Team = "Platform", ManagedBy = "Terraform",
#   Department = "Engineering", Environment = "prod" }
# Team = "Platform" because the second merge argument overrides the first
```

---

## 18. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║           TERRAFORM BUILT-IN FUNCTIONS — DAY 11 QUICK REFERENCE             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CONSOLE: terraform console → test functions without writing files           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  NUMERIC                                                                     ║
║  max(a,b,c)     → highest value                                              ║
║  min(a,b,c)     → lowest value                                               ║
║  abs(n)         → remove negative sign                                       ║
║  ceil(n)        → round up                                                   ║
║  floor(n)       → round down                                                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  STRING                                                                      ║
║  lower(s)           → all lowercase                                          ║
║  upper(s)           → all uppercase                                          ║
║  replace(s,old,new) → swap substrings                                        ║
║  trim(s,chars)      → remove chars from START and END only                  ║
║  trimprefix(s,pre)  → remove prefix                                          ║
║  trimsuffix(s,suf)  → remove suffix                                          ║
║  substr(s,0,23)     → extract substring (offset, max length)                ║
║  split(",",s)       → string → list  ← SEPARATOR FIRST                      ║
║  join(",",list)     → list → string                                          ║
║  chomp(s)           → remove trailing newline                               ║
║  format("%s-%s",a,b)→ sprintf-style formatting                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COLLECTION                                                                  ║
║  length(x)          → count elements                                        ║
║  merge(m1,m2,...)   → combine maps (later keys win)                         ║
║  concat(l1,l2)      → combine lists                                         ║
║  contains(list,val) → true if val in list                                   ║
║  distinct(list)     → remove duplicates                                     ║
║  flatten(nested)    → collapse nested lists                                  ║
║  keys(map)          → list of map keys                                       ║
║  values(map)        → list of map values                                    ║
║  lookup(map,k,dflt) → safe map access with fallback                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  FUNCTION NESTING (inner runs first, result passes to outer)                 ║
║  lower(replace(var.name, " ", "-"))                                          ║
║  substr(lower(replace(var.name, " ", "")), 0, 23)                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMON MISTAKES                                                             ║
║  split wrong order:  split("str",",")  → ✅ split(",","str")               ║
║  trim removes middle: NO — use replace() for middle characters              ║
║  join returns string — NOT usable in for_each (needs map)                   ║
║  local. vs var. — locals use local. (singular, no s)                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  AZURE NAMING RULES (enforced via functions)                                 ║
║  Storage Account: 3–24 chars, lowercase letters+numbers, no hyphens        ║
║  Resource Group:  1–90 chars, alphanumerics, hyphens, underscores, periods  ║
║  NSG:             1–80 chars, alphanumerics, hyphens, underscores, periods  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL                                                                  ║
║  Open console:    terraform console                                          ║
║  Exit console:    exit (or Ctrl+C)                                          ║
║  Run plan:        terraform plan                                             ║
║  View outputs:    terraform output                                           ║
║  One output:      terraform output rg_name                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
Functions = Kitchen Appliances for Your Data

lower()    = blender: takes any text, outputs all-lowercase
replace()  = Word's Find & Replace: swap one thing for another
substr()   = scissors: cut out exactly the length you need
split()    = knife: chop a string at every separator → list of pieces
join()     = glue: stick a list back together with a separator
merge()    = combine two ingredient lists into one (later list wins ties)
length()   = counting: how many items are in this collection?

Nesting = Chaining appliances in sequence:
  substr(lower(replace(name, " ", "")), 0, 23)
  First: replace removes spaces
  Then: lower makes it lowercase
  Then: substr cuts it to max 23 chars

terraform console = The Test Kitchen
  Try any function before putting it in your code.
  Get the right result first, THEN write it to your .tf file.
  Saves you from the cycle: write → plan → error → fix → repeat.
```

---

*Guide covers: Terraform built-in functions, terraform console, function
categories, numeric functions (max, min, abs, ceil, floor), string functions
(lower, upper, replace, trim, trimprefix, trimsuffix, substr, split, join,
chomp, format), collection functions (length, merge, concat, contains,
distinct, flatten, keys, values, lookup), type conversion (tostring, tonumber,
tolist, toset), date functions (timestamp, formatdate), function nesting,
function argument order, split separator-first rule, trim middle-character
limitation, join vs split, merge key precedence, Assignment 1 resource name
formatter, Assignment 2 tag merger, Assignment 3 storage account validator,
Assignment 4 NSG rule generator with split and for loop, Azure storage account
naming rules, local vs var reference, PowerShell terraform console workflow.*
