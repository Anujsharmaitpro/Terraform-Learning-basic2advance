# Terraform Functions — Day 11-12 Deep Dive
### Based on piyushsachdeva/Terraform-Full-Course-Azure → `lessons/day11-12`

> I pulled the actual files from this lesson folder (`readme.md`, `main.tf`, `variables.tf`, `provider.tf`) directly from GitHub. This lecture teaches functions through **12 assignments**, each built around 2-3 specific functions, all wired into real Azure resources (Resource Group, Storage Account, Network Security Group). This guide walks through every single one, from zero, and also fixes two real bugs I found in the source `main.tf` (called out explicitly so you learn to spot them yourself).

---

## 0. The Setup Every Assignment Builds On

The lesson uses three Azure resources as the "canvas" it keeps decorating with function outputs:

```hcl
# provider.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.8.0"
    }
  }
  required_version = ">= 1.9.0"
}

provider "azurerm" {
  features {}
}
```

**What this means in plain English:** before Terraform can talk to Azure, you tell it *which* plugin to use (`azurerm`, the official Azure provider) and *which version*. `features {}` is just a required empty block the Azure provider insists on, even if you don't configure anything special inside it.

Throughout this guide, every function's output eventually lands inside one of these three resources:

```hcl
resource "azurerm_resource_group" "rg" { ... }
resource "azurerm_storage_account" "example" { ... }
resource "azurerm_network_security_group" "example" { ... }
```

This mirrors real enterprise practice: functions are rarely "interesting" on their own — they're plumbing that feeds clean values into resources.

---

## 1. Warm-Up: `terraform console` Commands

Before any assignment, the lecture has you type these into `terraform console` — Terraform's interactive playground (open a terminal, run `terraform console`, type, press Enter, see the result instantly):

```hcl
> lower("HELLO WORLD")
"hello world"

> max(5, 12, 9)
12

> trim("  hello  ", " ")
"hello"

> chomp("hello\n")
"hello"

> reverse(["a", "b", "c"])
["c", "b", "a"]
```

**Beginner note on `trim`:** the lecture's console snippet shows `trim("  hello  ")` with only one argument, but `trim()` actually **requires two arguments**: the string, and the set of characters to strip (`trim(str, cutset)`). If you only want to strip whitespace, the correct function is `trimspace("  hello  ")`. This is a small but important distinction — `trim` strips specific characters you name; `trimspace` strips whitespace specifically. Try both in console and compare.

```hcl
> trim("xxhelloxx", "x")
"hello"

> trimspace("  hello  ")
"hello"
```

---

## 2. Assignment 1 — Project Naming Convention

**Functions:** `lower`, `replace`
**Business rule:** all Azure resource names must be lowercase, with spaces replaced by hyphens.

### Explain it like you've never coded

Azure doesn't care about your nicely capitalized project name like `"Project ALPHA Resource"` — it wants something like `project-alpha-resource`: no capitals, no spaces. You need two tools chained together: one to fix the casing, one to fix the spaces.

### The working code

```hcl
# variables.tf
variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "Project ALPHA Resource"
}
```

```hcl
# main.tf
locals {
  formatted_name = lower(replace(var.project_name, " ", "-"))
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.formatted_name}-rg"
  location = "westus2"
}

output "rgname" {
  value = azurerm_resource_group.rg.name
}
```

### How to read nested functions (this trips up every beginner once)

```
lower( replace( var.project_name, " ", "-" ) )
```

Terraform evaluates **inside out**, exactly like math parentheses:
1. `replace(var.project_name, " ", "-")` runs first → `"Project-ALPHA-Resource"`
2. `lower(...)` wraps around that result → `"project-alpha-resource"`

Final resource group name: `"project-alpha-resource-rg"`. That's the whole assignment — two functions, chained, solving a real Azure constraint.

---

## 3. Assignment 2 — Resource Tagging

**Function:** `merge`
**Business rule:** combine company-wide default tags with environment-specific tags into one tag set.

### Explain it like you've never coded

Picture two sticky notes. One says "Company: TechCorp, ManagedBy: Terraform" (the rules every resource must follow). The other says "Environment: Production, CostCenter: cc-123" (specific to this deployment). `merge()` glues both sticky notes into one, so you don't have to retype the company-wide rules every single time.

```hcl
# variables.tf
variable "default_tags" {
  type = map(string)
  default = {
    company    = "CloudOps"
    managed_by = "terraform"
  }
}

variable "environment_tags" {
  type = map(string)
  default = {
    environment = "production"
    cost_center = "cc-123"
  }
}
```

```hcl
# main.tf
locals {
  merge_tags = merge(var.default_tags, var.environment_tags)
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.formatted_name}-rg"
  location = "westus2"
  tags     = local.merge_tags
}

output "merged_tags" {
  value = local.merge_tags
}
```

Result: one combined map with all four keys — `company`, `managed_by`, `environment`, `cost_center`. **Rule to remember:** if both maps had a key with the same name, the *second* argument (`var.environment_tags`) would win, because `merge()` always lets later arguments override earlier ones.

---

## 4. Assignment 3 — Storage Account Naming

**Function:** `substr`
**Business rule:** Azure Storage Account names must be ≤24 characters, lowercase letters and numbers only, no special characters.

### Explain it like you've never coded

`substr(string, offset, length)` is like using scissors on a string: "starting at character position `offset`, cut out exactly `length` characters." It's how you guarantee a name never exceeds Azure's hard limit, no matter how long the input is.

### ⚠️ Bug found in the source repo — and the fix

The lecture's actual `main.tf` has this line:

```hcl
# ORIGINAL (has a problem)
storage_formatted = replace(replace(lower(substr(var.storage_account_name,0,23))," ",""),"!","")
```

This *does* work, but it's fragile: it manually chains `replace()` once per unwanted character (first spaces, then `!`). If tomorrow someone passes a name with a `#` or `@` in it, this silently lets bad characters through. The robust, professional way to do this is with `regexall` or `regex` to strip **any** non-alphanumeric character in one shot:

```hcl
# variables.tf
variable "storage_account_name" {
  type    = string
  default = "techtutorIALS with!piyushthis should be formatted"
}
```

```hcl
# main.tf — corrected, robust version
locals {
  # Step 1: keep only lowercase letters and digits, no matter what junk is in the input
  storage_clean = lower(replace(var.storage_account_name, "/[^a-zA-Z0-9]/", ""))

  # Step 2: enforce Azure's 24-character hard limit (use 23 for safety margin)
  storage_formatted = substr(local.storage_clean, 0, 23)
}

resource "azurerm_storage_account" "example" {
  name                     = local.storage_formatted
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags                     = local.merge_tags
}

output "storage_name" {
  value = azurerm_storage_account.example.name
}
```

The `"/[^a-zA-Z0-9]/"` part is a **regular expression** (regex) — a mini pattern language. `[^a-zA-Z0-9]` means "anything that is NOT a letter or digit." Replacing every match of that pattern with `""` strips spaces, `!`, `#`, `@`, literally anything unwanted, in one line, regardless of what shows up in the input. This is more enterprise-safe than the original chained-`replace()` approach.

---

## 5. Assignment 4 — Network Security Group Rules

**Functions:** `split`, `join`
**Business rule:** transform a comma-separated port list into both (a) a readable joined string, and (b) structured rules for an actual NSG.

### Explain it like you've never coded

`split(separator, string)` is scissors that cut a single string into a list wherever it sees the separator. `join(separator, list)` is glue that does the reverse — takes a list and welds it into one string with your separator in between.

```hcl
# variables.tf
variable "allowed_ports" {
  type    = string
  default = "80,443,3306"
}
```

```hcl
# main.tf
locals {
  formatted_ports = split(",", var.allowed_ports)
  # "80,443,3306" -> ["80", "443", "3306"]

  # Required-output part of the assignment: a joined, documentation-friendly string
  ports_documentation = join("-", [for p in local.formatted_ports : "port-${p}"])
  # -> "port-80-port-443-port-3306"

  # Bonus: structured data, used to actually build NSG rules dynamically
  nsg_rules = [for port in local.formatted_ports : {
    name        = "port-${port}"
    port        = port
    description = "Allowed traffic on port: ${port}"
  }]
}

output "ports_documentation" {
  value = local.ports_documentation
}
```

Then the **structured** version (`nsg_rules`) feeds a `dynamic` block — this is the payoff of doing the transformation correctly:

```hcl
resource "azurerm_network_security_group" "example" {
  name                = "${local.formatted_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = 100 + index(local.nsg_rules, security_rule.value)
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

**Bug fix note:** the original lecture file used `priority = 100` (a fixed, hardcoded number) for every single rule inside the `dynamic` block. Azure NSG rules require **unique priorities** — deploying that as-written would fail once there's more than one rule. The fix above adds `index(...)` so each rule gets `100`, `101`, `102`, etc.

A "dynamic block" is just a loop that generates multiple copies of a nested configuration block (`security_rule { ... }`) — one per item in `local.nsg_rules` — instead of you hand-writing three nearly-identical blocks.

---

## 6. Assignment 5 — Resource Lookup

**Function:** `lookup`
**Business rule:** map environment names to configuration, with a safe fallback if an unknown environment is passed.

### Explain it like you've never coded

`lookup(map, key, default)` is like asking a librarian for a book by title: if the book exists, you get it. If not, instead of the librarian shrugging and crashing your whole afternoon, they hand you a default book so you can keep going.

```hcl
variable "environments" {
  type = map(object({
    instance_size = string
    redundancy    = string
  }))
  default = {
    dev = {
      instance_size = "small"
      redundancy    = "low"
    }
    prod = {
      instance_size = "large"
      redundancy    = "high"
    }
  }
}

variable "environment" {
  type    = string
  default = "dev"
}
```

```hcl
locals {
  # lookup() on a map of objects — third arg is the fallback if the key is missing
  env_config = lookup(var.environments, var.environment, {
    instance_size = "small"
    redundancy    = "low"
  })
}

output "instance_size" {
  value = local.env_config.instance_size
}

output "redundancy" {
  value = local.env_config.redundancy
}
```

If `var.environment = "staging"` (a key that doesn't exist in the map), instead of erroring out, `lookup()` quietly returns the fallback object — your deployment keeps working instead of breaking a pipeline at 2am.

The lecture's actual VM-sizing version of this same pattern:

```hcl
variable "vm_sizes" {
  type = map(string)
  default = {
    dev     = "standard_D2s_v3"
    staging = "standard_D4s_v3"
    prod    = "standard_D8s_v3"
  }
}

locals {
  vm_size = lookup(var.vm_sizes, var.environment, "standard_D2s_v3")
}

output "vm_size" {
  value = local.vm_size
}
```

---

## 7. Assignment 6 — VM Size Validation

**Functions:** `length`, `contains` (the lecture's variables.tf actually implements this with `strcontains`, a close cousin)
**Business rule:** VM size string must be 2–20 characters long AND contain the word "standard".

### Explain it like you've never coded

`length()` counts characters in a string (or items in a list/map). `contains(list, value)` checks if a value exists *inside a list*. `strcontains(string, substring)` checks if one string exists *inside another string* — that's the one you actually want here, since you're checking for a substring of text, not searching through a list.

```hcl
variable "vm_size" {
  type    = string
  default = "standard_D2s_v3"

  validation {
    condition     = length(var.vm_size) >= 2 && length(var.vm_size) <= 20
    error_message = "vm_size must be between 2 and 20 characters."
  }

  validation {
    condition     = strcontains(lower(var.vm_size), "standard")
    error_message = "vm_size must contain the word 'standard'."
  }
}
```

**Why two separate `validation` blocks instead of one combined condition?** Because each block gives its own tailored `error_message`. If you combined both rules into one `condition` with `&&`, a user violating either rule would see the *same* generic error message, even if the actual problem was totally different (too long vs. wrong VM family). Splitting them gives precise, actionable errors — something every enterprise pipeline needs so engineers aren't left guessing.

Test it yourself: change the default to `"basic_A0"` (fails rule 2 — no "standard") or `"standard_D2s_v3_extra_long_name"` (fails rule 1 — too long) and run `terraform plan` to see Terraform reject it before touching Azure at all.

---

## 8. Assignment 7 — Backup Configuration

**Functions:** `endswith`, `sensitive`
**Business rule:** backup names must end in `_backup`; credentials must never appear in plaintext output.

### Explain it like you've never coded

`endswith(string, suffix)` is a true/false check: does this string finish with that exact text? `sensitive()` is a privacy stamp Terraform puts on a value, so it shows up as `(sensitive value)` in `plan`/`apply` output and logs instead of the real text — critical for compliance.

```hcl
variable "backup_name" {
  type    = string
  default = "daily_backup"

  validation {
    condition     = endswith(var.backup_name, "_backup")
    error_message = "backup_name must end with '_backup'."
  }
}

variable "credential" {
  type      = string
  default   = "xyz123"
  sensitive = true
}
```

```hcl
output "backup" {
  value = var.backup_name
}

output "credential" {
  value     = var.credential
  sensitive = true   # required: re-declare sensitive on the OUTPUT too
}
```

**Important beginner point:** marking a *variable* as `sensitive = true` does **not** automatically make every output referencing it safe — if you forget `sensitive = true` on the `output` block itself, Terraform will actually throw an error telling you to add it, specifically to prevent accidental secret leaks. This double-marking is intentional friction, by design, for safety.

---

## 9. Assignment 8 — File Path Processing

**Functions:** `fileexists`, `dirname`
**Business rule:** validate that Terraform config file paths exist before relying on them, and extract their directory names.

> **Note:** the lesson's `main.tf` doesn't actually implement this assignment (it's listed in the README but skipped in the reference code) — so here's the missing piece, built from scratch.

### Explain it like you've never coded

`fileexists(path)` is a true/false check — "is there really a file sitting at this location on disk?" — useful so Terraform fails with a clear error *before* a deployment, instead of crashing mid-apply. `dirname(path)` strips the filename and gives you just the folder portion of a path.

```hcl
variable "config_paths" {
  type    = list(string)
  default = ["./configs/main.tf", "./configs/variables.tf"]
}

locals {
  path_status = {
    for p in var.config_paths : p => fileexists(p)
  }

  config_directories = distinct([
    for p in var.config_paths : dirname(p)
  ])
}

output "path_status" {
  value = local.path_status
  # e.g. { "./configs/main.tf" = true, "./configs/variables.tf" = false }
}

output "config_directories" {
  value = local.config_directories
  # -> ["./configs"]
}
```

`dirname("./configs/main.tf")` returns `"./configs"` — it has no idea whether that folder actually exists, it's pure text manipulation. That's why `fileexists` and `dirname` are usually used *together*: one validates reality, the other extracts structure.

---

## 10. Assignment 9 — Resource Set Management

**Functions:** `toset`, `concat`
**Business rule:** combine user-chosen and default Azure regions into one de-duplicated set.

### Explain it like you've never coded

`concat(list1, list2)` glues two lists end-to-end (duplicates and all). `toset(list)` then converts that combined list into a **set** — and a defining property of sets in Terraform (and math in general) is that they automatically drop duplicates and don't preserve order.

```hcl
locals {
  user_locations    = ["eastus", "westus", "eastus"]   # "eastus" appears twice
  default_locations = ["centralus"]

  unique_locations = toset(concat(local.user_locations, local.default_locations))
}

output "unique_locations" {
  value = local.unique_locations
  # -> ["centralus", "eastus", "westus"]  (duplicate "eastus" gone, order not guaranteed)
}
```

**Why this matters for Azure specifically:** sets are also exactly what `for_each` requires when looping over simple lists of strings (Azure region names, subnet names, NSG rule names) — so `toset()` is frequently the bridge between "a list someone gave me" and "something `for_each` will actually accept."

---

## 11. Assignment 10 — Cost Calculation

**Functions:** `abs`, `max` (plus `sum` and basic arithmetic for the "average" requirement)

### Explain it like you've never coded

`abs(number)` strips the negative sign off a number — `-50` becomes `50`, `75` stays `75`. `max(a, b, c, ...)` returns the largest value. The `...` syntax after a list "spreads" it into individual arguments, since `max()` expects them comma-separated, not bundled as one list.

```hcl
locals {
  monthly_costs = [-50, 100, 75, 200]

  # abs() applied to every item via a "for expression" (a loop that builds a new list)
  positive_costs = [for cost in local.monthly_costs : abs(cost)]
  # -> [50, 100, 75, 200]

  max_cost = max(local.positive_costs...)
  # -> 200

  total_cost   = sum(local.positive_costs)
  average_cost = local.total_cost / length(local.positive_costs)
}

output "cost_report" {
  value = {
    positive_costs = local.positive_costs
    max_cost       = local.max_cost
    total_cost     = local.total_cost
    average_cost   = local.average_cost
  }
}
```

`local.positive_costs...` (note the three dots) means "take this list and spread its items out as separate arguments" — without the `...`, calling `max(local.positive_costs)` with a single list argument would error, because `max` expects individual numbers, not one list object.

---

## 12. Assignment 11 — Timestamp Management

**Functions:** `timestamp`, `formatdate`

### Explain it like you've never coded

`timestamp()` returns the current UTC date/time, in a fixed standard format (RFC3339), the moment Terraform runs. `formatdate(layout, timestamp)` reformats that into whatever pattern you actually need — Terraform uses a slightly unusual layout language (`YYYY` = 4-digit year, `MM` = month, `DD` = day) rather than the `%Y-%m-%d` style you may have seen in other tools.

```hcl
locals {
  current_time = timestamp()

  resource_name_date = formatdate("YYYYMMDD", local.current_time)   # for resource names
  tag_date            = formatdate("DD-MM-YYYY", local.current_time) # for human-readable tags
}

output "resource_name_date" {
  value = local.resource_name_date  # e.g. "20260630"
}

output "tag_date" {
  value = local.tag_date  # e.g. "30-06-2026"
}
```

**Critical beginner warning, worth repeating:** `timestamp()` returns a *new* value every single time you run `terraform plan` or `apply`. If you feed it directly into a resource's `name` argument, Terraform will think the name "changed" on every single run and want to recreate the resource — even though nothing about your actual infrastructure changed. The safe pattern is to use it only for things genuinely meant to change each run (tags, SAS token expiry), and to wrap any resource argument that uses it in a `lifecycle { ignore_changes = [...] }` block if you don't want that constant churn.

---

## 13. Assignment 12 — File Content Handling

**Functions:** `file`, `sensitive` (plus `jsondecode`/`nonsensitive` from the lecture's actual output)

### ⚠️ Bug found in the source repo — and the fix

The lecture's literal `main.tf` line was:

```hcl
# ORIGINAL — this will not compile
config_content = sensitive(file(config.json))
```

This fails for a simple but very common beginner reason: `config.json` is written **without quotes**, so Terraform tries to interpret it as a reference to some resource/variable named `config` with an attribute `json` — which doesn't exist anywhere. File paths must always be a quoted string.

```hcl
# CORRECTED
locals {
  config_content = sensitive(file("${path.module}/config.json"))
}

output "config_loaded" {
  value = nonsensitive(jsondecode(local.config_content))
}
```

### Explain it like you've never coded

- `file(path)` reads a file's raw text content off disk (the machine running `terraform apply`, not Azure itself).
- `sensitive(value)` stamps that content as private, so if `config.json` happens to contain secrets, it won't leak into your terminal or CI/CD logs.
- `jsondecode(string)` parses JSON text into a structured Terraform object you can actually reference (`local.config.some_key`).
- `nonsensitive(value)` deliberately *removes* the sensitive stamp — used here because once you've parsed the JSON into something you actually want to display (e.g., non-secret config like region names), you may intentionally want it visible in outputs. **Use this with real caution** — only strip the sensitive marking from data you're certain is safe to show.

`${path.module}` is a built-in Terraform value (not a function) meaning "the folder this `.tf` file lives in" — using it makes file paths work correctly regardless of which directory you happen to run `terraform apply` from.

---

## 14. The Fully Corrected, Consolidated File

Putting every fixed assignment together the way a real reviewed PR would look:

```hcl
# variables.tf
variable "project_name" {
  type    = string
  default = "Project ALPHA Resource"
}

variable "default_tags" {
  type = map(string)
  default = {
    company    = "CloudOps"
    managed_by = "terraform"
  }
}

variable "environment_tags" {
  type = map(string)
  default = {
    environment = "production"
    cost_center = "cc-123"
  }
}

variable "storage_account_name" {
  type    = string
  default = "techtutorIALS with!piyushthis should be formatted"
}

variable "allowed_ports" {
  type    = string
  default = "80,443,3306"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vm_sizes" {
  type = map(string)
  default = {
    dev     = "standard_D2s_v3"
    staging = "standard_D4s_v3"
    prod    = "standard_D8s_v3"
  }
}
```

```hcl
# main.tf
locals {
  formatted_name      = lower(replace(var.project_name, " ", "-"))
  merge_tags           = merge(var.default_tags, var.environment_tags)
  storage_clean        = lower(replace(var.storage_account_name, "/[^a-zA-Z0-9]/", ""))
  storage_formatted     = substr(local.storage_clean, 0, 23)
  formatted_ports      = split(",", var.allowed_ports)
  vm_size              = lookup(var.vm_sizes, var.environment, "standard_D2s_v3")

  nsg_rules = [for port in local.formatted_ports : {
    name        = "port-${port}"
    port        = port
    description = "Allowed traffic on port: ${port}"
  }]
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.formatted_name}-rg"
  location = "westus2"
  tags     = local.merge_tags
}

resource "azurerm_storage_account" "example" {
  name                     = local.storage_formatted
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags                     = local.merge_tags
}

resource "azurerm_network_security_group" "example" {
  name                = "${local.formatted_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                        = security_rule.value.name
      priority                    = 100 + index(local.nsg_rules, security_rule.value)
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = security_rule.value.port
      source_address_prefix       = "*"
      destination_address_prefix  = "*"
      description                 = security_rule.value.description
    }
  }
}

output "rg_name"      { value = azurerm_resource_group.rg.name }
output "storage_name" { value = azurerm_storage_account.example.name }
output "vm_size"      { value = local.vm_size }
output "merged_tags"  { value = local.merge_tags }
```

---

## 15. Function Index for This Lecture

| Function | Assignment | What it does |
|---|---|---|
| `lower` | 1, 3, 6 | force lowercase |
| `replace` | 1, 3 | find & replace text |
| `merge` | 2 | combine maps, later wins |
| `substr` | 3 | cut a fixed-length piece of a string |
| `split` | 4 | string → list |
| `join` | 4 | list → string |
| `lookup` | 5 | safe map read with fallback |
| `length` | 6 | count characters/items |
| `strcontains` | 6 | substring check |
| `contains` | environment validation | is value in a list |
| `endswith` | 7 | suffix check |
| `sensitive` | 7, 12 | hide a value from output/logs |
| `fileexists` | 8 | does a file exist on disk |
| `dirname` | 8 | extract folder from a path |
| `toset` | 9 | list → set (dedupes) |
| `concat` | 9 | combine lists |
| `abs` | 10 | strip negative sign |
| `max` | 10 | largest value |
| `sum` | 10 (bonus) | total of a list |
| `timestamp` | 11 | current UTC time |
| `formatdate` | 11 | reformat a timestamp |
| `file` | 12 | read raw file content |
| `jsondecode` | 12 | JSON string → object |
| `nonsensitive` | 12 | remove the sensitive marking |

---

## 16. Practice Plan

1. Spin up a real (or sandbox) Azure subscription, drop the corrected files from Section 14 into a folder, run `terraform init` then `terraform plan`, and read every line of output — match it back to the function that produced it.
2. Deliberately reintroduce the two bugs from Sections 4 and 13 (`priority = 100` static, and `file(config.json)` without quotes) and watch Terraform's exact error messages — recognizing these error patterns instantly is what separates someone who's "seen functions" from someone who can debug enterprise Terraform under pressure.
3. Do Assignment 8 (Section 9) yourself before reading it — it's the one piece the original lecture skipped, so building it from the function descriptions alone is the best test of whether this guide actually stuck.
