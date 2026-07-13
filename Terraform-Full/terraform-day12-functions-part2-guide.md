# Terraform Functions — Assignments 5 to 12 (Complete)
## Deep-Dive Learning Guide — Day 12 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure Examples | PowerShell Commands Throughout

---

## Before You Start

This is Day 12 — a direct continuation of Day 11.
Day 11 covered assignments 1–4: `lower`, `replace`, `merge`, `substr`, `split`.

Today covers assignments 5–12:
- **Assignment 5:** `lookup` — environment config mapping with fallback
- **Assignment 6:** `strcontains` + `length` — VM size validation
- **Assignment 7:** `endswith` + `sensitive` — backup config and secret handling
- **Assignment 8:** `fileexists` — path validation (self-study)
- **Assignment 9:** `concat` + `toset` — unique location management
- **Assignment 10:** `abs` + `max` — cost calculation
- **Assignment 11:** `timestamp` + `formatdate` — time-based tagging
- **Assignment 12:** `sensitive` + `jsondecode` — secure file content handling

Each assignment uses the **`terraform console`** for testing first,
then real `.tf` code. Every mistake the instructor made is documented
with the fix.

---

## Table of Contents

1. Quick Recap — Functions and Validation Syntax
2. ASSIGNMENT 5 — Environment Config Mapping with `lookup`
3. The `lookup` Function — Deep Dive
4. Variable Validation with `contains` — For Lists and Maps
5. ASSIGNMENT 6 — VM Size Validation with `strcontains` + `length`
6. The Difference: `contains` vs `strcontains`
7. ASSIGNMENT 7 — Backup Config with `endswith` + `sensitive`
8. The `sensitive` Keyword — Protecting Secret Values
9. ASSIGNMENT 8 — Path Validation with `fileexists` (Self-Study)
10. ASSIGNMENT 9 — Unique Location Management with `concat` + `toset`
11. ASSIGNMENT 10 — Cost Calculation with `abs` + `max`
12. The Three-Dots `...` Operator — Expanding Collections
13. ASSIGNMENT 11 — Timestamp Management with `timestamp` + `formatdate`
14. ASSIGNMENT 12 — Secure File Content with `sensitive` + `jsondecode`
15. All Functions Covered — Reference Summary
16. The Complete Working Code — All Files
17. Common Mistakes and Fixes
18. Practice Exercises
19. Complete Cheat Sheet

---

## 1. Quick Recap — Functions and Validation Syntax

Before diving into the assignments, here is the key syntax you need:

### Variable validation block

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {                                    # validation block
    condition     = contains(["dev","prod"], var.environment)
    error_message = "Must be dev or prod."
  }
}
```

### Local variable

```hcl
locals {
  my_value = some_function(var.something)
}
# Reference: local.my_value
```

### Output variable

```hcl
output "result" {
  value = local.my_value
}
```

---

## 2. ASSIGNMENT 5 — Environment Config Mapping with `lookup`

### The requirement

You have three environments: `dev`, `staging`, `prod`. Each environment
should use a different Azure VM size:
- `dev` → `Standard_D2s_v3`
- `staging` → `Standard_D4s_v3`
- `prod` → `Standard_D8s_v3`

If someone provides an invalid environment name (e.g., `"prods"`), show
a validation error. If no environment is provided, default to `dev`.

### Why not use a conditional expression?

You COULD write:
```hcl
size = var.environment == "dev" ? "Standard_D2s_v3" :
       var.environment == "staging" ? "Standard_D4s_v3" : "Standard_D8s_v3"
```

But this becomes unreadable with more than 2 conditions. `lookup` is
designed for this exact use case — a map where you find a value by key.

### The `lookup` function explained

```
lookup(map, key, default_value)
  ↑        ↑    ↑
  │        │    └── What to return if the key is not found
  │        └────── The key to search for in the map
  └─────────────── The map to search in
```

```hcl
lookup({"dev" = "Small", "prod" = "Large"}, "dev", "Small")
# → "Small"   (key "dev" found, returns its value)

lookup({"dev" = "Small", "prod" = "Large"}, "test", "Small")
# → "Small"   (key "test" not found, returns default "Small")
```

### The solution

**`variables.tf`**
```hcl
variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "dev"

  # Validation: must be one of the three valid environments
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Enter a valid value for environment: dev, staging, or prod."
  }
}

variable "vm_sizes" {
  type        = map(string)
  description = "Map of environment name to VM size"
  default = {
    dev     = "Standard_D2s_v3"
    staging = "Standard_D4s_v3"
    prod    = "Standard_D8s_v3"
  }
}
```

**`locals.tf`**
```hcl
locals {
  # lookup(map, key, default_if_key_missing)
  # Finds the VM size for the current environment
  # Falls back to "dev" size if environment not found in map
  vm_size = lookup(var.vm_sizes, var.environment, "Standard_D2s_v3")
}
```

**`outputs.tf`**
```hcl
output "vm_size" {
  description = "VM size selected for the current environment"
  value       = local.vm_size
}
```

**`terraform.tfvars`**
```hcl
environment = "prod"
# → vm_size output will be "Standard_D8s_v3"
```

### Testing in terraform console

```powershell
terraform console
```

```
> lookup({"dev"="D2","staging"="D4","prod"="D8"}, "prod", "D2")
"D8"

> lookup({"dev"="D2","staging"="D4","prod"="D8"}, "unknown", "D2")
"D2"

> exit
```

### Verifying the validation error

```powershell
# In terraform.tfvars, set: environment = "prods"
terraform plan
```

```
Error: Invalid value for variable

  with var.environment,
  on variables.tf line 1:
   1: variable "environment" {

Enter a valid value for environment: dev, staging, or prod.

This was checked by the validation rule at variables.tf:8,3-13.
```

### Plan results for each environment

```powershell
# For dev (default):
terraform plan
# Output: vm_size = "Standard_D2s_v3"

# For prod (via tfvars):
terraform plan
# Output: vm_size = "Standard_D8s_v3"

# For invalid (via -var flag):
terraform plan -var="environment=prods"
# Error: validation fails immediately
```

---

## 3. The `lookup` Function — Deep Dive

### When to use `lookup` vs conditional expressions

```
1 or 2 conditions:   Use conditional expression (? :)
3+ conditions:       Use lookup with a map variable
```

### The fallback value is critical

Without a fallback, `lookup` errors if the key doesn't exist:
```hcl
# This errors if environment = "staging" and staging is not in the map
lookup({"dev" = "Small"}, "staging")   # Error: key not found

# This returns "Small" if staging is not found
lookup({"dev" = "Small"}, "staging", "Small")   # "Small"
```

Always provide a sensible fallback — usually the value for your
most conservative/cheapest environment.

### Why `lookup` vs direct map access

```hcl
# Direct map access — errors if key doesn't exist
var.vm_sizes["staging"]    # Error if "staging" not in map

# lookup — returns fallback if key doesn't exist
lookup(var.vm_sizes, "staging", "Standard_D2s_v3")   # Safe
```

---

## 4. Variable Validation with `contains` — For Lists and Maps

The `contains()` function works on **lists, sets, and tuples** — NOT strings.

```hcl
# ✅ Valid — checking a list
contains(["dev", "staging", "prod"], var.environment)

# ❌ Invalid — checking inside a string
contains("standard_d2s", "standard")   # Error: argument must be list/set/tuple
```

For strings, you need `strcontains()` (covered in Assignment 6).

### Multiple validations on one variable

```hcl
variable "environment" {
  type = string

  # Validation 1: must be a valid environment name
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }

  # Validation 2: can't be empty
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty."
  }
}
```

Each validation block is checked independently. All must pass.

---

## 5. ASSIGNMENT 6 — VM Size Validation with `strcontains` + `length`

### The requirement

Validate that a VM size string:
1. Is between 2 and 20 characters long
2. Contains the keyword `"standard"` (case-insensitive)

### The instructor's mistake — using `contains` on a string

```hcl
# ❌ WRONG — contains() doesn't work on strings
condition = contains(lower(var.vm_size), "standard")
# Error: argument must be list, tuple, or set
```

The fix — use `strcontains()` for string substring checking:

```hcl
# ✅ CORRECT — strcontains() checks if a string contains a substring
condition = strcontains(lower(var.vm_size), "standard")
```

### The solution

**`variables.tf`**
```hcl
variable "vm_size" {
  type        = string
  description = "Azure VM size (must contain 'standard', 2–20 chars)"
  default     = "Standard_D2s_v3"

  # Validation 1: length check
  validation {
    condition = (
      length(var.vm_size) >= 2 &&
      length(var.vm_size) <= 20
    )
    error_message = "VM size must be between 2 and 20 characters."
  }

  # Validation 2: must contain "standard" keyword
  validation {
    condition     = strcontains(lower(var.vm_size), "standard")
    error_message = "VM size must contain the keyword 'standard'."
  }
}
```

### Testing both validation errors

```powershell
# Test invalid — too long AND no "standard":
# In terraform.tfvars: vm_size = "SuperPowerfulUltraMaxGigaVM"
terraform plan
```

```
Error: Invalid value for variable
  VM size must be between 2 and 20 characters.

Error: Invalid value for variable
  VM size must contain the keyword 'standard'.
```

### Why `lower()` is used with `strcontains`

The Azure VM size format is `"Standard_D2s_v3"` with a capital S.
If someone types `"standard_d2s_v3"` in lowercase, we still want to
accept it. `lower()` normalises the case before checking:

```hcl
strcontains(lower("Standard_D2s_v3"), "standard")
# lower("Standard_D2s_v3") = "standard_d2s_v3"
# strcontains("standard_d2s_v3", "standard") = true ✓

strcontains(lower("STANDARD_D4s_v3"), "standard")
# lower("STANDARD_D4s_v3") = "standard_d4s_v3"
# strcontains("standard_d4s_v3", "standard") = true ✓
```

### Testing in console

```powershell
terraform console
```

```
> strcontains("Standard_D2s_v3", "standard")
false   ← case-sensitive! capital S doesn't match lowercase "standard"

> strcontains(lower("Standard_D2s_v3"), "standard")
true    ← correct: lowercase first, then check

> length("Standard_D2s_v3")
16      ← within 2-20 range ✓

> exit
```

---

## 6. The Difference: `contains` vs `strcontains`

| Function | Works On | Purpose |
|---|---|---|
| `contains(list, value)` | Lists, sets, tuples | Does this VALUE exist IN this collection? |
| `strcontains(string, substring)` | Strings only | Does this STRING contain this SUBSTRING? |

```hcl
# contains — is "prod" in this list?
contains(["dev", "staging", "prod"], "prod")   # true

# strcontains — does this string contain "standard"?
strcontains("Standard_D2s_v3", "Standard")    # true
strcontains("Standard_D2s_v3", "premium")     # false
```

**Memory trick:**
- `contains` = "is it in the **box**?" (checking membership in a collection)
- `strcontains` = "is it in the **word**?" (checking substring inside a string)

---

## 7. ASSIGNMENT 7 — Backup Config with `endswith` + `sensitive`

### The requirement

1. A backup name must end with `"-backup"` or `"_backup"`
2. A credential value must be marked sensitive so it never appears in logs

### The `endswith` function

```
endswith(string, suffix)
→ true if the string ends with the suffix
→ false otherwise
```

```hcl
endswith("mybackup-backup", "-backup")    # true
endswith("mybackup_backup", "_backup")    # true
endswith("mybackup", "-backup")           # false
```

### The `sensitive` keyword for variables

When you mark a variable as `sensitive = true`:
- Its value is HIDDEN in `terraform plan` and `terraform apply` output
- It still appears in the state file (encrypt your state file!)
- Any output that shows this variable must ALSO be marked sensitive

### The solution

**`variables.tf`**
```hcl
variable "backup_name" {
  type        = string
  description = "Backup resource name (must end with -backup or _backup)"
  default     = "test_backup"

  validation {
    condition = (
      endswith(var.backup_name, "-backup") ||
      endswith(var.backup_name, "_backup")
    )
    error_message = "Backup name must end with '-backup' or '_backup'."
  }
}

variable "credential" {
  type        = string
  description = "Secret credential value"
  default     = "my-secret-password-xyz123"
  sensitive   = true    # ← this value will be hidden in all output
}
```

**`outputs.tf`**
```hcl
output "backup_name_display" {
  description = "The validated backup name"
  value       = var.backup_name
}

# When showing a sensitive variable, the OUTPUT must also be sensitive
output "credential_display" {
  description = "The credential (hidden in output)"
  value       = var.credential
  sensitive   = true    # ← required when value comes from a sensitive variable
}
```

### What happens if you forget `sensitive = true` on the output

```
Error: Output refers to sensitive values

  with output.credential_display,
  on outputs.tf line 7:
   7:   value = var.credential

To reduce the risk of accidentally exporting sensitive data that was
intended to be internal, Terraform requires that any root module output
containing sensitive data be explicitly marked as sensitive, to confirm
your intent. If you do intend to export this data, annotate the output
value as sensitive by adding `sensitive = true`.
```

This is Terraform's safety mechanism — it forces you to acknowledge that
you're intentionally exposing sensitive data.

### What the terraform plan output shows

```
Changes to Outputs:
  + backup_name_display = "test_backup"
  + credential_display  = (sensitive value)    ← value is hidden
```

### Testing the validation error

```powershell
# In terraform.tfvars: backup_name = "test-archive"  (wrong suffix)
terraform plan
```

```
Error: Invalid value for variable
  with var.backup_name
  Backup name must end with '-backup' or '_backup'.
```

---

## 8. ASSIGNMENT 8 — Path Validation with `fileexists` (Self-Study)

### What `fileexists` does

```hcl
fileexists(path)
# → true if the file exists at the given path
# → false if the file doesn't exist
```

### Using it in a validation

```hcl
variable "config_file_path" {
  type    = string
  default = "./config/main.tf"

  validation {
    condition     = fileexists(var.config_file_path)
    error_message = "Config file does not exist at the specified path."
  }
}
```

### Checking multiple files

```hcl
locals {
  files_exist = {
    main      = fileexists("./config/main.tf")
    variables = fileexists("./config/variables.tf")
    outputs   = fileexists("./config/outputs.tf")
  }
}

output "file_status" {
  value = local.files_exist
}
# → { main = true, variables = true, outputs = false }
```

### Extracting directory from a path

```hcl
locals {
  config_dir = dirname("./config/main.tf")
  # → "./config"
}
```

### PowerShell — create the test config folder structure

```powershell
# Create the config directory and files for testing
New-Item -ItemType Directory -Path ".\config" -Force
New-Item -ItemType File     -Path ".\config\main.tf" -Force
New-Item -ItemType File     -Path ".\config\variables.tf" -Force
# outputs.tf intentionally NOT created to test the false case

terraform plan
# files_exist = { main=true, variables=true, outputs=false }
```

---

## 9. ASSIGNMENT 9 — Unique Location Management with `concat` + `toset`

### The requirement

- User has a list of preferred locations (may have duplicates)
- System has default locations
- Combine both lists, remove duplicates, produce a clean unique set

### The problem with duplicates

```
user_locations    = ["East US", "West US", "East US"]   ← "East US" twice
default_locations = ["Central US"]

Concatenated: ["East US", "West US", "East US", "Central US"]
← still has duplicate "East US"
```

### The solution — `concat` then `toset`

```hcl
# Step 1: concat joins two lists into one
concat(list1, list2)

# Step 2: toset removes duplicates (sets only allow unique values)
toset(concat(list1, list2))
```

### The complete solution

**`locals.tf`**
```hcl
locals {
  # Raw location lists (may have duplicates)
  user_locations    = ["East US", "West US", "East US"]   # duplicate "East US"
  default_locations = ["Central US"]

  # Step 1: Concatenate both lists into one
  all_locations = concat(local.user_locations, local.default_locations)
  # → ["East US", "West US", "East US", "Central US"]  ← still has duplicate

  # Step 2: Convert to set to remove duplicates
  unique_locations = toset(local.all_locations)
  # → {"Central US", "East US", "West US"}  ← sorted, no duplicates
}
```

**`outputs.tf`**
```hcl
output "unique_locations" {
  description = "All unique Azure regions after deduplication"
  value       = local.unique_locations
}
```

### What `terraform plan` shows

```
Changes to Outputs:
  + unique_locations = toset([
      + "Central US",
      + "East US",
      + "West US",
    ])
```

Three values — duplicate "East US" removed. The instructor confirmed:
"So it removed the duplicate value and concatenated both lists together in a set."

### Testing in console

```powershell
terraform console
```

```
> toset(concat(["East US","West US","East US"], ["Central US"]))
toset([
  "Central US",
  "East US",
  "West US",
])

> exit
```

### Key insight — list vs set behaviour

```
list → ordered, duplicates allowed, accessed by index [0]
set  → unordered, UNIQUE values only, cannot access by index

toset() converts any list to a set, removing duplicates in the process.
```

---

## 10. ASSIGNMENT 10 — Cost Calculation with `abs` + `max`

### The requirement

Given a list of monthly costs (some negative due to credits/refunds):
1. Convert all negative values to positive using `abs()`
2. Find the maximum cost

### The `abs` function

```hcl
abs(-500)    # → 500   (removes the negative sign)
abs(75)      # → 75    (positive stays positive)
abs(-200)    # → 200
abs(0)       # → 0
```

### The solution

**`locals.tf`**
```hcl
locals {
  # Raw costs — some are negative (refunds/credits)
  monthly_costs = [-500, 75, -200, 150]

  # Convert all to positive using abs() inside a for loop
  positive_costs = [for cost in local.monthly_costs : abs(cost)]
  # → [500, 75, 200, 150]

  # Find the maximum using max()
  # IMPORTANT: use ... (three dots) to expand the list into individual arguments
  max_cost = max(local.positive_costs...)
  # → 500
}
```

### The three-dots operator `...` — critical for max/min on lists

This is where the instructor hit an error and is one of the most
important techniques in this video.

```hcl
# max() normally takes individual numbers:
max(2, 4, 1)   # → 4   ✓

# But if you have a list, you can't pass it directly:
max([2, 4, 1])   # ❌ Error: expected number, got list

# Use three dots (...) to "expand" the list into individual arguments:
max([2, 4, 1]...)   # → 4   ✓
```

Think of `...` as saying: "unpack this list and pass each item as
a separate argument."

### The instructor's error and fix

**Error:**
```
Error: Invalid value for function parameter
  while calling max(numbers...), the argument "numbers" must be a number,
  got tuple with 4 elements.
```

**Fix — add `...` after the list:**
```hcl
# ❌ Without three dots — passes the whole list as one argument
max_cost = max(local.positive_costs)      # Error

# ✅ With three dots — expands list into individual numbers
max_cost = max(local.positive_costs...)   # Works
```

**Same applies to `min()`:**
```hcl
min_cost = min(local.positive_costs...)   # Find minimum
```

### Testing in console

```powershell
terraform console
```

```
> [for c in [-500, 75, -200, 150] : abs(c)]
[
  500,
  75,
  200,
  150,
]

> max([500, 75, 200, 150]...)
500

> min([500, 75, 200, 150]...)
75

> exit
```

### Outputs

**`outputs.tf`**
```hcl
output "positive_costs" {
  description = "All monthly costs converted to positive values"
  value       = local.positive_costs
}

output "max_cost" {
  description = "The highest monthly cost"
  value       = local.max_cost
}
```

**`terraform plan` output:**
```
Changes to Outputs:
  + max_cost       = 500
  + positive_costs = [
      + 500,
      + 75,
      + 200,
      + 150,
    ]
```

---

## 11. The Three-Dots `...` Operator — Expanding Collections

This deserves its own section because it's non-obvious and the instructor
hit this exact error.

### What it does

The `...` operator expands a list or set into individual arguments when
calling a function that expects separate values.

```hcl
# Function signature: max(number, number, ...)
# → expects individual numbers, not a list

numbers = [10, 5, 8, 3]

max(numbers)     # ❌ Error: passing a list where numbers expected
max(numbers...)  # ✅ Expands to: max(10, 5, 8, 3)  → 8
```

### Functions that need `...` for lists

```hcl
max(my_list...)      # greatest value
min(my_list...)      # smallest value
concat(list_a..., list_b...)  # (concat already takes lists natively)
```

### Where you DON'T need `...`

Functions already designed to accept collections don't need `...`:
```hcl
length(my_list)      # no ... needed — length takes a list directly
contains(my_list, x) # no ... needed
toset(my_list)       # no ... needed
```

---

## 12. ASSIGNMENT 11 — Timestamp Management with `timestamp` + `formatdate`

### The requirement

1. Capture the current timestamp
2. Format it in two different ways for resource naming and tagging
3. Use the formatted date in resource tags

### The `timestamp()` function

```hcl
timestamp()
# → "2024-01-15T10:30:00Z"
# Returns current UTC time in ISO 8601 format
# NOTE: This is evaluated at apply time, not plan time
#       That's why terraform plan shows "known after apply"
```

### The `formatdate` function

```
formatdate(format_string, timestamp_string)
```

**Format codes:**

| Code | Meaning | Example |
|---|---|---|
| `YYYY` | 4-digit year | `2024` |
| `YY` | 2-digit year | `24` |
| `MM` | 2-digit month | `01` |
| `MMM` | 3-letter month | `Jan` |
| `DD` | 2-digit day | `15` |
| `hh` | Hour (24h) | `10` |
| `mm` | Minutes | `30` |
| `ss` | Seconds | `00` |

### The solution

**`locals.tf`**
```hcl
locals {
  # Capture current UTC timestamp
  current_time = timestamp()
  # → "2024-01-15T10:30:00Z"

  # Format 1: YYYYMMDD — compact, good for resource names
  resource_name_date = formatdate("YYYYMMDD", local.current_time)
  # → "20240115"

  # Format 2: DD-MM-YYYY — readable, good for tags
  tag_date = formatdate("DD-MM-YYYY", local.current_time)
  # → "15-01-2024"

  # Format 3: human-readable with time
  full_timestamp = formatdate("DD MMM YYYY hh:mm", local.current_time)
  # → "15 Jan 2024 10:30"
}
```

**`outputs.tf`**
```hcl
output "resource_tag" {
  description = "Human-readable date for tagging"
  value       = local.tag_date
}

output "resource_name_date" {
  description = "Compact date for resource name suffixes"
  value       = local.resource_name_date
}
```

### Why `terraform plan` shows "known after apply"

```
Changes to Outputs:
  + resource_tag       = (known after apply)
  + resource_name_date = (known after apply)
```

The `timestamp()` function is evaluated at **apply time** — when
Terraform is actually making changes. During `plan`, Terraform can't
know what the timestamp will be because it hasn't started the apply yet.

```powershell
# To see the actual timestamp values:
terraform apply --auto-approve

# Outputs will show real values:
# resource_tag = "15-01-2024"
# resource_name_date = "20240115"
```

### Using the timestamp in resource tags

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-myapp-${formatdate("YYYYMMDD", timestamp())}"
  location = "West Europe"

  tags = {
    Environment = var.environment
    CreatedDate = formatdate("DD-MM-YYYY", timestamp())
    ManagedBy   = "Terraform"
  }
}
```

---

## 13. ASSIGNMENT 12 — Secure File Content with `sensitive` + `jsondecode`

### The requirement

1. Read a JSON configuration file from disk
2. Mark the content as sensitive so it doesn't appear in logs
3. Decode the JSON and use specific fields from it

### The `file()` function

```hcl
file("./config.json")
# Reads the entire file content as a string
```

### The `sensitive()` function wrapper

```hcl
sensitive(value)
# Marks ANY value as sensitive — it will be hidden in output
# Even if the original value wasn't marked sensitive
```

### The `jsondecode()` function

```hcl
jsondecode(json_string)
# Converts a JSON string into a Terraform object/map
# Then you can access fields with dot notation
```

### Setup — create the config file

**PowerShell — create `config.json`:**
```powershell
@"
{
  "app_name": "MyAzureApp",
  "database_url": "postgresql://db.example.com:5432/mydb",
  "api_key": "super-secret-api-key-12345",
  "max_connections": 100
}
"@ | Out-File -FilePath ".\config.json" -Encoding utf8
```

### The solution

**`locals.tf`**
```hcl
locals {
  # Step 1: Read the JSON file content as a string
  # Wrap in sensitive() so the raw content is never logged
  config_content = sensitive(file("./config.json"))

  # Step 2: Decode the JSON into a Terraform object
  # jsondecode returns a map/object you can access with dot notation
  # nonsensitive() temporarily reveals for JSON parsing
  config_parsed = jsondecode(nonsensitive(local.config_content))

  # Step 3: Extract individual fields (these will inherit sensitivity)
  app_name       = local.config_parsed.app_name
  database_url   = sensitive(local.config_parsed.database_url)
  max_connections = local.config_parsed.max_connections
}
```

**`outputs.tf`**
```hcl
# Public output — app name is not sensitive
output "config_app_name" {
  description = "Application name from config"
  value       = local.app_name
}

# Sensitive output — database URL should not appear in logs
output "config_database_url" {
  description = "Database connection URL (sensitive)"
  value       = local.database_url
  sensitive   = true
}

# Public output — connection count is not sensitive
output "config_max_connections" {
  description = "Maximum database connections"
  value       = local.max_connections
}
```

### What terraform plan shows

```
Changes to Outputs:
  + config_app_name        = "MyAzureApp"
  + config_database_url    = (sensitive value)
  + config_max_connections = 100
```

### Testing in console

```powershell
terraform console
```

```
> jsondecode("{\"name\":\"test\",\"port\":8080}")
{
  "name" = "test"
  "port" = 8080
}

> jsondecode("{\"name\":\"test\",\"port\":8080}").name
"test"

> exit
```

---

## 14. All Functions Covered — Reference Summary

| Assignment | Function(s) | Purpose |
|---|---|---|
| 1 (Day 11) | `lower()`, `replace()` | Resource name formatting |
| 2 (Day 11) | `merge()` | Combining tag maps |
| 3 (Day 11) | `substr()`, `lower()`, `replace()` | Storage account name validation |
| 4 (Day 11) | `split()`, `join()`, `for` loop | NSG rule name generation |
| 5 | `lookup()` | Environment-to-VM-size mapping with fallback |
| 6 | `strcontains()`, `length()` | VM size string validation |
| 7 | `endswith()`, `sensitive` | Backup naming and secret protection |
| 8 | `fileexists()`, `dirname()` | File path validation |
| 9 | `concat()`, `toset()` | Unique location deduplication |
| 10 | `abs()`, `max()`, `...` | Cost calculation and expansion |
| 11 | `timestamp()`, `formatdate()` | Time-based tagging |
| 12 | `sensitive()`, `jsondecode()`, `file()` | Secure config file handling |

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
# Assignment 5: Environment + VM sizes map
variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Enter a valid value for environment: dev, staging, or prod."
  }
}

variable "vm_sizes" {
  type        = map(string)
  description = "VM size map per environment"
  default = {
    dev     = "Standard_D2s_v3"
    staging = "Standard_D4s_v3"
    prod    = "Standard_D8s_v3"
  }
}

# Assignment 6: VM size with validation
variable "vm_size" {
  type        = string
  description = "Azure VM size"
  default     = "Standard_D2s_v3"

  validation {
    condition = (
      length(var.vm_size) >= 2 &&
      length(var.vm_size) <= 20
    )
    error_message = "VM size must be between 2 and 20 characters."
  }

  validation {
    condition     = strcontains(lower(var.vm_size), "standard")
    error_message = "VM size must contain the keyword 'standard'."
  }
}

# Assignment 7: Backup name and credential
variable "backup_name" {
  type        = string
  description = "Backup name (must end with -backup or _backup)"
  default     = "test_backup"

  validation {
    condition = (
      endswith(var.backup_name, "-backup") ||
      endswith(var.backup_name, "_backup")
    )
    error_message = "Backup name must end with '-backup' or '_backup'."
  }
}

variable "credential" {
  type        = string
  description = "Secret credential (sensitive)"
  default     = "my-secret-xyz123"
  sensitive   = true
}
```

---

**`locals.tf`**
```hcl
# Assignment 5: VM size lookup with fallback
locals {
  vm_size_for_env = lookup(var.vm_sizes, var.environment, "Standard_D2s_v3")
}

# Assignment 9: Unique location management
locals {
  user_locations    = ["East US", "West US", "East US"]
  default_locations = ["Central US"]
  all_locations     = concat(local.user_locations, local.default_locations)
  unique_locations  = toset(local.all_locations)
}

# Assignment 10: Cost calculation
locals {
  monthly_costs  = [-500, 75, -200, 150]
  positive_costs = [for cost in local.monthly_costs : abs(cost)]
  max_cost       = max(local.positive_costs...)
  min_cost       = min(local.positive_costs...)
}

# Assignment 11: Timestamp management
locals {
  current_time       = timestamp()
  resource_name_date = formatdate("YYYYMMDD", local.current_time)
  tag_date           = formatdate("DD-MM-YYYY", local.current_time)
}
```

---

**`outputs.tf`**
```hcl
# Assignment 5
output "vm_size_for_env" {
  description = "VM size selected for the current environment via lookup"
  value       = local.vm_size_for_env
}

# Assignment 7
output "backup_name_display" {
  value = var.backup_name
}

output "credential_display" {
  value     = var.credential
  sensitive = true
}

# Assignment 9
output "unique_locations" {
  description = "Deduplicated list of Azure regions"
  value       = local.unique_locations
}

# Assignment 10
output "positive_costs" {
  value = local.positive_costs
}

output "max_cost" {
  value = local.max_cost
}

output "min_cost" {
  value = local.min_cost
}

# Assignment 11
output "tag_date" {
  description = "Formatted date for resource tags (known after apply)"
  value       = local.tag_date
}
```

---

**`terraform.tfvars`**
```hcl
environment = "prod"
vm_size     = "Standard_D2s_v3"
backup_name = "test_backup"
credential  = "my-secret-xyz123"
```

---

**PowerShell — full workflow:**

```powershell
# Navigate to project
Set-Location "C:\projects\day12"

# Set Azure credentials
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# Create config.json for Assignment 12
@"
{
  "app_name": "MyAzureApp",
  "database_url": "postgresql://db.example.com:5432/mydb",
  "api_key": "super-secret-api-key-12345",
  "max_connections": 100
}
"@ | Out-File -FilePath ".\config.json" -Encoding utf8

# Initialise
terraform init

# Open console to test functions
terraform console
# Test: lookup({"dev"="D2","prod"="D8"}, "prod", "D2")
# Test: strcontains(lower("Standard_D2s_v3"), "standard")
# Test: endswith("test_backup", "_backup")
# Test: toset(concat(["East US","West US","East US"], ["Central US"]))
# Test: max([-500,75,-200,150]...)
# Type exit to leave

# Validate
terraform validate

# Plan — review all outputs
terraform plan

# Test validation errors
terraform plan -var="environment=prods"    # Should fail validation
terraform plan -var="vm_size=Banana"       # Should fail two validations
terraform plan -var="backup_name=myarchive"  # Should fail endswith validation

# Apply to see timestamp values (known after apply)
terraform apply --auto-approve

# View all outputs
terraform output

# Check specific sensitive output
terraform output -raw credential_display

# Clean up
terraform destroy --auto-approve

# Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 16. Common Mistakes and Fixes

### Mistake 1 — Using `contains` on a string (need `strcontains`)

```hcl
# ❌ WRONG — contains() expects a collection, not a string
condition = contains(lower(var.vm_size), "standard")
# Error: argument must be list, tuple, or set

# ✅ CORRECT — strcontains() is for strings
condition = strcontains(lower(var.vm_size), "standard")
```

---

### Mistake 2 — Using `var.` inside validation condition (must use `var.varname`)

```hcl
# ❌ WRONG — "vm." doesn't reference the variable
condition = length(vm.vm_size) >= 2

# ✅ CORRECT — use var.vm_size
condition = length(var.vm_size) >= 2
```

The instructor wrote `vm.vm_size` instead of `var.vm_size`. The
error was: "The condition for variable vm_size must refer to var.vm_size."

---

### Mistake 3 — Forgetting `sensitive = true` on outputs that show sensitive variables

```hcl
# ❌ WRONG — Terraform will error
output "secret" {
  value = var.credential    # var.credential is sensitive
}
# Error: Output refers to sensitive values

# ✅ CORRECT — mark the output as sensitive too
output "secret" {
  value     = var.credential
  sensitive = true
}
```

---

### Mistake 4 — Passing a list to `max()` without `...`

```hcl
# ❌ WRONG — passes the list as ONE argument
max_cost = max(local.positive_costs)
# Error: local positive_costs is a tuple with 4 elements, number required

# ✅ CORRECT — use ... to expand into individual arguments
max_cost = max(local.positive_costs...)
```

---

### Mistake 5 — Expecting `timestamp()` to show a value in `terraform plan`

```hcl
output "created_at" {
  value = timestamp()
}
```

```
# terraform plan shows:
+ created_at = (known after apply)
```

This is normal — `timestamp()` only resolves during `terraform apply`.
Don't worry if your plan shows "known after apply" for timestamp outputs.

---

### Mistake 6 — Wrong argument order in `lookup`

```hcl
# ❌ WRONG — arguments in wrong order
lookup("dev", var.vm_sizes, "Standard_D2s_v3")

# ✅ CORRECT — map first, key second, default third
lookup(var.vm_sizes, var.environment, "Standard_D2s_v3")
```

---

## 17. Practice Exercises

### Exercise 1 — Console Practice

```powershell
terraform console
```

Test these in the console:

```
a) lookup({"a"="apple","b"="banana"}, "b", "cherry")
b) lookup({"a"="apple","b"="banana"}, "z", "cherry")
c) strcontains("Standard_D4s_v3", "standard")
d) strcontains(lower("Standard_D4s_v3"), "standard")
e) endswith("prod-backup", "-backup")
f) endswith("prod-archive", "-backup")
g) max([10, -5, 8, -3, 15]...)
h) toset(concat(["a","b","a"], ["c","b"]))
i) formatdate("DD-MM-YYYY", "2024-01-15T10:30:00Z")
```

**Answers:**
```
a) "banana"          (key "b" found)
b) "cherry"          (key "z" not found, returns default)
c) false             (case-sensitive — capital S doesn't match)
d) true              (lower() normalises case first)
e) true
f) false
g) 15
h) {"a", "b", "c"}  (duplicates removed)
i) "15-01-2024"
```

---

### Exercise 2 — Write the Validation

Write a validation for a variable `"resource_prefix"` that:
- Must be between 3 and 10 characters
- Must not contain spaces
- Must start with a letter (hint: use `substr` and check first character)

**Answer:**
```hcl
variable "resource_prefix" {
  type = string

  validation {
    condition     = length(var.resource_prefix) >= 3 && length(var.resource_prefix) <= 10
    error_message = "Resource prefix must be between 3 and 10 characters."
  }

  validation {
    condition     = !strcontains(var.resource_prefix, " ")
    error_message = "Resource prefix must not contain spaces."
  }
}
```

---

### Exercise 3 — Predict the Error

```hcl
variable "vm_size" {
  type = string
  default = "Standard_D2s_v3"

  validation {
    condition = contains(var.vm_size, "standard")  # ← what's wrong?
    error_message = "Must contain standard."
  }
}
```

**Answer:**
```
Error: Invalid function argument

  while calling contains(list, value), the argument "list" must be a list,
  set, or tuple.

Fix: change contains() to strcontains() for string substring checking:
  condition = strcontains(lower(var.vm_size), "standard")
```

---

### Exercise 4 — Cost Analysis

Given monthly costs: `[-1200, 450, -300, 800, -150, 600]`

Write locals to:
a) Get all positive values
b) Find the maximum
c) Find the minimum
d) Calculate the count of positive values

**Answer:**
```hcl
locals {
  raw_costs      = [-1200, 450, -300, 800, -150, 600]

  # a) All positive
  positive_costs = [for c in local.raw_costs : abs(c)]
  # → [1200, 450, 300, 800, 150, 600]

  # b) Maximum
  max_cost = max(local.positive_costs...)
  # → 1200

  # c) Minimum
  min_cost = min(local.positive_costs...)
  # → 150

  # d) Count (same as original list length since abs() doesn't filter)
  cost_count = length(local.positive_costs)
  # → 6
}
```

---

## 18. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║         TERRAFORM FUNCTIONS PART 2 — DAY 12 QUICK REFERENCE                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LOOKUP — map-based value selection                                          ║
║  lookup(map, key, default)                                                   ║
║  lookup(var.vm_sizes, var.environment, "Standard_D2s_v3")                   ║
║  → Finds key in map; returns default if not found                           ║
║  → Use for 3+ conditions instead of nested ternary                          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  STRING CHECKING                                                             ║
║  strcontains(string, substring) → true if string contains substring         ║
║  startswith(string, prefix)    → true if string starts with prefix          ║
║  endswith(string, suffix)      → true if string ends with suffix            ║
║                                                                              ║
║  contains(list, value) → for COLLECTIONS (lists, sets, tuples)             ║
║  DO NOT use contains() on strings — use strcontains() instead               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SENSITIVE DATA                                                              ║
║  variable "name" { sensitive = true }   → hide variable value              ║
║  output "name" { sensitive = true }     → REQUIRED when showing sensitive   ║
║  sensitive(value)                       → mark any value as sensitive       ║
║  nonsensitive(value)                    → temporarily reveal for operations ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COLLECTION OPERATIONS                                                       ║
║  concat(list1, list2)   → combine lists into one                            ║
║  toset(list)            → convert list to set (removes duplicates)         ║
║  abs(number)            → remove negative sign                              ║
║  max(a, b, c...)        → highest value                                     ║
║  min(a, b, c...)        → lowest value                                      ║
║                                                                              ║
║  max(list...)           → use ... to expand list to individual args         ║
║  min(list...)           → same                                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DATE & TIME                                                                 ║
║  timestamp()            → current UTC time (known after apply!)             ║
║  formatdate("DD-MM-YYYY", timestamp()) → formatted date string              ║
║  Format codes: YYYY=year, MM=month, DD=day, hh=hour, mm=min, ss=sec        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  FILE OPERATIONS                                                             ║
║  file("./config.json")        → read file as string                         ║
║  fileexists("./config.json")  → true if file exists                        ║
║  dirname("./config/main.tf")  → "./config"                                  ║
║  jsondecode(string)           → parse JSON string into Terraform object     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  THREE-DOTS OPERATOR ...                                                     ║
║  max(my_list...)  → expands list into individual number arguments           ║
║  min(my_list...)  → same                                                    ║
║  Without ...: max([1,2,3]) → Error                                         ║
║  With ...:    max([1,2,3]...) → 3 ✓                                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMON ERRORS                                                               ║
║  "argument must be list..." → using contains() on a string → use strcontains║
║  "known after apply"         → timestamp() only resolves during apply       ║
║  "tuple with N elements"     → forgot ... when passing list to max/min      ║
║  "refers to sensitive values"→ forgot sensitive=true on output              ║
║  "must refer to var.name"   → used wrong prefix in validation condition     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL TESTING                                                          ║
║  terraform console            → open interactive test environment           ║
║  terraform plan               → preview (timestamps show unknown)           ║
║  terraform apply --auto-approve → real timestamps visible in outputs        ║
║  terraform output             → show all output values                      ║
║  terraform output -raw name   → show raw value (including sensitive)        ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
Functions = Power Tools for Your Data

lookup()    = a smart dictionary lookup with a safety net (fallback default)
              "If 'prod' is in the map, give me its value. Otherwise give me this."

strcontains() = a word-search inside a string
              "Does this string contain this smaller piece?"

contains()    = membership check in a collection
              "Is this value in my list/set?"

endswith()    = suffix check
              "Does this string end with this specific ending?"

sensitive    = a privacy screen
              value is still there, just hidden from logs and terminal output

toset()      = a deduplication machine
              "Take this list, remove duplicates, give me only unique values."

concat()     = list glue
              "Stick these two lists together end to end."

abs()        = sign stripper
              "Take this number, always give me the positive version."

max(...) / min(...) = value extremes
              "From all these numbers, give me the highest / lowest."
              Remember: use ... to expand a list before passing to max/min!

timestamp()  = a time capsule — sealed at apply time, not plan time
              "Tell me what time it is" — but only once we actually start!
```

---

*Guide covers: Terraform built-in functions part 2, lookup function with fallback,
environment config mapping, variable validation with contains vs strcontains,
strcontains for string substring checking, length validation on strings, sensitive
keyword for variables and outputs, endswith for suffix validation, startswith,
fileexists for path validation, dirname, concat for list combination, toset for
deduplication, unique location management, abs for absolute values, max and min
with lists, three-dots expansion operator ..., timestamp function and known after
apply behaviour, formatdate format codes, file reading with file(), jsondecode,
sensitive() wrapper function, nonsensitive(), jsondecode for JSON parsing,
PowerShell terraform console, ARM credential management, terraform plan validation
errors, all 12 assignment solutions.*
