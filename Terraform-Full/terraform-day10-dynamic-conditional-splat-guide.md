# Terraform Dynamic Blocks, Conditional Expressions & Splat Expressions
## Deep-Dive Learning Guide — Day 10 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure NSG Examples | PowerShell Commands Throughout

---

## Before You Start

This is Day 10. By now you know:
- Day 1–3: Fundamentals, providers, resources, dependencies
- Day 4: State file and remote backends
- Day 5: Input, output, and local variables
- Day 6: Professional file structure
- Day 7: All type constraints
- Day 8: `count`, `for_each`, and `for` loops
- Day 9: Lifecycle meta-arguments

Today covers three powerful expression types that make your Terraform
code dramatically more flexible and readable:

1. **Dynamic Blocks** — repeat a sub-block inside a resource automatically
2. **Conditional Expressions** — if-else logic in a single line
3. **Splat Expressions** — shorthand to extract one field from every item

The teaching resource today is an **Azure Network Security Group (NSG)**
— perfect for demonstrating dynamic blocks because NSGs have repeating
security rule sub-blocks.

---

## Table of Contents

1. What Is an Azure Network Security Group? (The Teaching Resource)
2. The Problem Dynamic Blocks Solve — Repeated Sub-Blocks
3. What Is a Dynamic Block? — Plain English First
4. The `locals.tf` Nested Map — The Data Source for Dynamic Blocks
5. Dynamic Block Syntax — Every Part Explained
6. How the Dynamic Block Iterator Works — Step by Step
7. `security_rule.key` and `security_rule.value` — Accessing Nested Map Data
8. Running the NSG Demo — What Gets Created
9. Conditional Expressions — If-Else in One Line
10. Conditional Expression Syntax — The Ternary Operator
11. The Variable Precedence Bug — A Real Debugging Lesson
12. How to Debug Variable Values in Terraform
13. Splat Expressions — The Shorthand For Loop
14. Splat with Lists vs Maps/Objects — The Critical Difference
15. `for` Loop vs Splat — When to Use Which
16. The Complete Working Code — All Files
17. Common Mistakes Beginners Make
18. Practice Exercises
19. Complete Cheat Sheet

---

## 1. What Is an Azure Network Security Group?

Before writing any code, you need to understand what you're building —
otherwise the code has no context.

### The bouncer analogy

An **Azure Network Security Group (NSG)** is a security filter for your
Azure network. Think of it as a bouncer at the door of your infrastructure.

Every time network traffic tries to enter or leave:
- The bouncer (NSG) checks each rule in order of priority
- If the traffic matches a rule: Allow or Deny as the rule says
- Lower priority number = checked first (100 is checked before 200)

### What an NSG contains

```
NSG: "my-security-group"
├── Rule 1: Priority 100 — Allow HTTP traffic on port 80  (Inbound)
├── Rule 2: Priority 110 — Allow HTTPS traffic on port 443 (Inbound)
├── Rule 3: Priority 200 — Allow SSH on port 22           (Inbound)
└── Rule 4: Priority 65000 — Deny everything else         (default rule)
```

### Why NSGs are perfect for teaching dynamic blocks

Every security rule has the SAME set of fields:
- `name` — the rule's label
- `priority` — evaluation order
- `direction` — Inbound or Outbound
- `access` — Allow or Deny
- `protocol` — TCP, UDP, etc.
- `destination_port_range` — the port number
- `description` — what this rule does

When you have 5 rules, you'd normally copy-paste this structure 5 times.
Dynamic blocks let you define the structure ONCE and inject the data
from a local variable automatically.

---

## 2. The Problem Dynamic Blocks Solve — Repeated Sub-Blocks

### What a sub-block is

Inside a Terraform resource, sometimes you need to declare a BLOCK
(not just a key-value attribute) that can appear multiple times.
For an NSG, the `security_rule` block can appear many times:

```hcl
resource "azurerm_network_security_group" "example" {
  name                = "example-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  # Without dynamic blocks — copy this entire block for every rule:
  security_rule {
    name                       = "allow_http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Allow HTTP traffic"
  }

  security_rule {
    name                       = "allow_https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Allow HTTPS traffic"
  }

  # Add allow_ssh → copy-paste a 3rd block
  # Add allow_rdp → copy-paste a 4th block
  # Add allow_sql → copy-paste a 5th block
  # ... this becomes unmaintainable fast
}
```

**The problems:**
- Copy-pasting 10 rules = 10 identical block structures with slightly different values
- Adding a field (like `source_address_prefix`) means editing all 10 blocks
- Reviewing pull requests becomes tedious — can't see what actually changed

### The dynamic block solution

Define the rule data in a local variable. Write the block structure ONCE.
Let Terraform repeat it automatically for each entry in the data:

```hcl
# Define data in locals
locals {
  nsg_rules = {
    allow_http  = { priority = 100, port = "80",  description = "Allow HTTP" }
    allow_https = { priority = 110, port = "443", description = "Allow HTTPS" }
    allow_ssh   = { priority = 120, port = "22",  description = "Allow SSH" }
  }
}

# Write the block ONCE with dynamic
resource "azurerm_network_security_group" "example" {
  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                   = security_rule.key
      priority               = security_rule.value.priority
      destination_port_range = security_rule.value.port
      description            = security_rule.value.description
      # other fields...
    }
  }
}
```

Add a 4th rule? Just add one line to `local.nsg_rules`. The dynamic block
handles the rest automatically.

---

## 3. What Is a Dynamic Block? — Plain English First

### The photocopier analogy

Imagine you have a form (the security rule block structure) and a stack
of data cards (each NSG rule's values).

**Without dynamic blocks:** You manually fill out one form per data card.
10 data cards = 10 manually filled forms.

**With dynamic blocks:** You feed all data cards into a photocopier-filler
machine. It stamps out one filled form per card automatically.

The `dynamic` keyword is the machine. The local variable is your stack
of data cards. The `content` block is the form template.

### What dynamic blocks are NOT for

Dynamic blocks are for repeating **sub-blocks** within a resource. They
are NOT for:
- Creating multiple copies of an entire resource (use `count` or `for_each`)
- Conditional logic (use conditional expressions)
- Transforming output values (use `for` loops in outputs)

---

## 4. The `locals.tf` Nested Map — The Data Source for Dynamic Blocks

### The instructor's data structure

```hcl
# locals.tf
locals {
  nsg_rules = {
    # OUTER KEY     INNER KEY-VALUE PAIRS
    allow_http = {
      priority             = 100
      destination_port     = "80"
      description          = "Allow HTTP traffic"
    }
    allow_https = {
      priority             = 110
      destination_port     = "443"
      description          = "Allow HTTPS traffic"
    }
  }
}
```

### Understanding the nesting level by level

**Level 0 — The locals block:**
```hcl
locals { ... }
```

**Level 1 — The named local variable:**
```hcl
nsg_rules = { ... }
# This is a MAP whose keys are rule names
```

**Level 2 — Each rule entry (outer key → inner map):**
```hcl
allow_http  = { priority = 100, destination_port = "80",  description = "..." }
allow_https = { priority = 110, destination_port = "443", description = "..." }
# Each outer key maps to an INNER MAP of the rule's attributes
```

**Level 3 — Each rule's attributes (inner key → value):**
```hcl
priority         = 100
destination_port = "80"
description      = "Allow HTTP traffic"
```

### Visualising the structure as a table

| Outer Key | priority | destination_port | description |
|---|---|---|---|
| `allow_http` | 100 | "80" | "Allow HTTP traffic" |
| `allow_https` | 110 | "443" | "Allow HTTPS traffic" |

When the dynamic block iterates, it processes one ROW at a time.

### Why locals instead of variables?

The instructor chose `locals` because:
- NSG rule definitions don't change per deployment — they're structural
- No user should override them from outside
- Locals can use complex nested maps; input variables need more careful type definitions
- It's an internal configuration detail, not an external input

---

## 5. Dynamic Block Syntax — Every Part Explained

### The complete syntax

```hcl
resource "azurerm_network_security_group" "example" {
  name                = "example-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  dynamic "security_rule" {              # Part 1: dynamic keyword + block name
    for_each = local.nsg_rules           # Part 2: collection to iterate over
    content {                            # Part 3: required content wrapper
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.destination_port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = security_rule.value.description
    }
  }
}
```

### Part 1 — `dynamic "security_rule"`

The word after `dynamic` is the **iterator label** — it becomes the
name you use to access each item during iteration.

```
dynamic "security_rule"
          │
          └── This name ("security_rule") is used inside content as:
              security_rule.key   → current item's key
              security_rule.value → current item's value
```

The name must match the actual block name in the Azure documentation.
For NSG, the block is called `security_rule`. So you write `dynamic "security_rule"`.

If you were creating an ingress block in a Kubernetes resource, you'd write
`dynamic "ingress"`. The name tells Terraform WHAT TYPE of block to generate.

### Part 2 — `for_each = local.nsg_rules`

This is the collection to iterate over. The dynamic block creates one
`security_rule` block for EACH entry in this collection.

```
local.nsg_rules has 2 entries:
  allow_http  → { priority=100, ... }
  allow_https → { priority=110, ... }

for_each = local.nsg_rules

→ 2 iterations = 2 security_rule blocks generated
```

### Part 3 — `content { ... }`

The `content` block is **mandatory** for dynamic blocks. It defines the
template — what each generated block looks like.

**Important:** When you look at Azure Terraform documentation, the resource
page shows `security_rule { ... }` WITHOUT a `content` wrapper. You only
add `content` when using `dynamic`. Without `dynamic`, it's just a plain block.

```hcl
# In Azure documentation (NOT using dynamic):
security_rule {
  name     = "allow_http"
  priority = 100
  ...
}

# When using dynamic (YOUR code):
dynamic "security_rule" {
  for_each = local.nsg_rules
  content {                    # ← content wrapper required
    name     = security_rule.key
    priority = security_rule.value.priority
    ...
  }
}
```

---

## 6. How the Dynamic Block Iterator Works — Step by Step

Let's trace through exactly what Terraform does with the dynamic block:

```
Input data (local.nsg_rules):
{
  "allow_http"  = { priority=100, destination_port="80",  description="Allow HTTP" }
  "allow_https" = { priority=110, destination_port="443", description="Allow HTTPS" }
}
```

### Iteration 1 — allow_http

```
Current item:
  security_rule.key   = "allow_http"
  security_rule.value = { priority=100, destination_port="80", description="Allow HTTP" }

Template filled in:
  security_rule {
    name                       = "allow_http"         ← security_rule.key
    priority                   = 100                   ← security_rule.value.priority
    direction                  = "Inbound"             ← hardcoded
    access                     = "Allow"               ← hardcoded
    protocol                   = "Tcp"                 ← hardcoded
    source_port_range          = "*"                   ← hardcoded
    destination_port_range     = "80"                  ← security_rule.value.destination_port
    source_address_prefix      = "*"                   ← hardcoded
    destination_address_prefix = "*"                   ← hardcoded
    description                = "Allow HTTP traffic"  ← security_rule.value.description
  }
```

### Iteration 2 — allow_https

```
Current item:
  security_rule.key   = "allow_https"
  security_rule.value = { priority=110, destination_port="443", description="Allow HTTPS" }

Template filled in:
  security_rule {
    name                       = "allow_https"          ← security_rule.key
    priority                   = 110                    ← security_rule.value.priority
    direction                  = "Inbound"              ← hardcoded (unchanged)
    access                     = "Allow"                ← hardcoded (unchanged)
    protocol                   = "Tcp"                  ← hardcoded (unchanged)
    source_port_range          = "*"                    ← hardcoded (unchanged)
    destination_port_range     = "443"                  ← security_rule.value.destination_port
    source_address_prefix      = "*"                    ← hardcoded (unchanged)
    destination_address_prefix = "*"                    ← hardcoded (unchanged)
    description                = "Allow HTTPS traffic"  ← security_rule.value.description
  }
```

### Final result

Terraform generates TWO `security_rule` blocks inside the NSG — exactly
as if you had written them both out manually, but from a single template.

### Adding a third rule

To create a third security rule (e.g., for SSH), you only change the data:

```hcl
locals {
  nsg_rules = {
    allow_http  = { priority = 100, destination_port = "80",  description = "Allow HTTP" }
    allow_https = { priority = 110, destination_port = "443", description = "Allow HTTPS" }
    allow_ssh   = { priority = 120, destination_port = "22",  description = "Allow SSH" }  # ← just add this
  }
}
```

The dynamic block automatically runs a third iteration. No changes needed
to the resource block itself.

---

## 7. `security_rule.key` and `security_rule.value` — Accessing Nested Map Data

### The iterator label is the dynamic block's name

```
dynamic "security_rule" ← the label is "security_rule"
  → security_rule.key   = the current outer key ("allow_http")
  → security_rule.value = the current inner map ({ priority=100, ... })
```

### Drilling into the nested value

Since `security_rule.value` is itself a map, you drill into it with dot notation:

```hcl
security_rule.value.priority         # → 100 (first iteration)
security_rule.value.destination_port # → "80" (first iteration)
security_rule.value.description      # → "Allow HTTP traffic" (first iteration)
```

### Why NOT `each.key` / `each.value` inside dynamic blocks

This is a common confusion. When you use `for_each` in a RESOURCE block:
```hcl
resource "azurerm_storage_account" "example" {
  for_each = var.names   # use each.key / each.value
  name = each.value
}
```

But when you use `for_each` inside a DYNAMIC block, you use the label name:
```hcl
dynamic "security_rule" {
  for_each = local.nsg_rules   # use security_rule.key / security_rule.value
  content {
    name = security_rule.key   # NOT each.key
  }
}
```

The iterator is named after the dynamic label, not "each". This is a
critical distinction.

### Reference cheat sheet for this example

```
local.nsg_rules                           → the whole nested map
local.nsg_rules["allow_http"]             → the inner map for allow_http
local.nsg_rules["allow_http"].priority    → 100
local.nsg_rules["allow_http"].destination_port → "80"

Inside dynamic content block:
security_rule.key                         → "allow_http" (current iteration)
security_rule.value                       → { priority=100, destination_port="80", ... }
security_rule.value.priority              → 100
security_rule.value.destination_port      → "80"
security_rule.value.description           → "Allow HTTP traffic"
```

---

## 8. Running the NSG Demo — What Gets Created

After running `terraform apply`, the instructor verified the result in
the Azure Portal:

```
Resource Group: day10-rg
└── Network Security Group: example-nsg
    └── Inbound Security Rules:
        ├── allow_http   — Port 80,  Priority 100, Allow, TCP  ← created by dynamic
        ├── allow_https  — Port 443, Priority 110, Allow, TCP  ← created by dynamic
        ├── AllowVnetInBound  — Priority 65000  (Azure default)
        ├── AllowAzureLoadBalancerInBound — Priority 65001 (Azure default)
        └── DenyAllInBound   — Priority 65500  (Azure default)
```

The three rules with priority 65000+ are Azure defaults added to every NSG.
The two rules with priority 100 and 110 were created by the dynamic block.

**PowerShell — run the demo:**

```powershell
Set-Location "C:\projects\day10"

$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

---

## 9. Conditional Expressions — If-Else in One Line

### What a conditional expression is

A **conditional expression** is Terraform's way of writing an if-else
statement on a single line. You use it when you want to choose between
two values based on a condition.

### The everyday analogy

```
"If it's raining, take an umbrella. Otherwise, leave it at home."

In code:
weather == "raining" ? "take umbrella" : "leave at home"
```

### When you need this in Terraform

You want to name resources differently based on the environment:
- If environment is `"dev"` → NSG name = `"dev-nsg"`
- If environment is anything else → NSG name = `"stage-nsg"`

Without conditional expressions, you'd need two separate resource blocks
or complex variable logic. With a conditional expression, it's one line.

---

## 10. Conditional Expression Syntax — The Ternary Operator

### The syntax

```
condition ? true_value : false_value
```

Read it as: "If condition is true, use true_value. Otherwise, use false_value."

The three parts:

```
var.environment == "dev"    ← CONDITION: is environment equal to "dev"?
?                           ← separator: "if yes, use..."
"dev-nsg"                   ← TRUE VALUE: use this if condition is true
:                           ← separator: "if no, use..."
"stage-nsg"                 ← FALSE VALUE: use this if condition is false
```

### The instructor's NSG naming example

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

resource "azurerm_network_security_group" "example" {
  name = var.environment == "dev" ? "dev-nsg" : "stage-nsg"
  #      └── condition ──┘   └── true ──┘   └── false ──┘

  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content { ... }
  }
}
```

### Tracing both scenarios

**Scenario A — `var.environment = "dev"`:**
```
condition: "dev" == "dev"  → true
result:    name = "dev-nsg"
```

**Scenario B — `var.environment = "staging"` or anything else:**
```
condition: "staging" == "dev"  → false
result:    name = "stage-nsg"
```

### More conditional expression examples

```hcl
# Choose instance type based on environment
size = var.environment == "prod" ? "Standard_D4s_v3" : "Standard_B1s"

# Conditional count — create resource only in prod
count = var.environment == "prod" ? 1 : 0

# Conditional replication type
account_replication_type = var.environment == "prod" ? "GRS" : "LRS"

# Nested conditional (use sparingly — hurts readability)
name = var.env == "prod" ? "prod-nsg" : var.env == "dev" ? "dev-nsg" : "stage-nsg"
```

### String values MUST be in double quotes

The instructor initially forgot quotes around `"dev"` in the condition
and got an error. Always put string values in double quotes:

```hcl
# ❌ No quotes around the compared value
var.environment == dev    # Error: "dev" is not a recognised value

# ✅ Double quotes required for string comparison
var.environment == "dev"  # Correct
```

---

## 11. The Variable Precedence Bug — A Real Debugging Lesson

This section covers the most educational part of the video — when the
instructor's conditional expression showed `"stage-nsg"` even though
`variables.tf` clearly said `environment = "dev"`.

### What happened

The instructor had previously set a shell environment variable:

```
TF_VAR_environment = "command-line"
```

He had set this during an earlier video demo and never unset it. Even
though his `variables.tf` file said `default = "dev"`, the shell environment
variable overrode it because `TF_VAR_*` variables have HIGHER precedence
than `default` values in variable blocks BUT LOWER precedence than `terraform.tfvars`.

Wait — why did `TF_VAR_environment = "command-line"` win over the file default
but NOT show `"dev"` (the file default)?

Because the precedence order is:

```
1. TF_VAR_* environment variables        ← LOWEST active method
2. terraform.tfvars / *.auto.tfvars      ← higher
3. -var-file flag                         ← higher
4. -var flag on command line              ← HIGHEST
```

And `variable { default = "dev" }` is the FALLBACK — it only applies when
NO other method provides a value. Since `TF_VAR_environment` was set to
`"command-line"`, that value was used instead of `"dev"`.

### The conditional expression evaluation

```
var.environment = "command-line"  ← actual value at runtime

Condition: var.environment == "dev"
Evaluation: "command-line" == "dev"
Result: false

→ name = "stage-nsg"   ← the false branch
```

This is why the NSG was named `stage-nsg` even though the file said `dev`.

### The PowerShell fix

```powershell
# Check if any TF_VAR_ variables are set
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }

# Output showed:
# Name                  Value
# TF_VAR_environment    command-line

# Remove the conflicting variable
Remove-Item Env:TF_VAR_environment

# Verify it's gone
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }
# (no output — clean)

# Now terraform plan uses the file default
terraform plan
# Shows: name = "dev-nsg"  ← correct
```

### Overriding from the command line (the instructor's demonstration)

After fixing the environment variable, the instructor showed that `-var`
flag still overrides the file:

```powershell
# Pass a different value via -var flag (highest precedence)
terraform plan -var="environment=staging"
# Shows: name = "stage-nsg"  ← -var overrides everything

# Without -var flag (uses variables.tf default)
terraform plan
# Shows: name = "dev-nsg"  ← file default applies
```

---

## 12. How to Debug Variable Values in Terraform

The instructor used a technique to diagnose the variable issue. This is
a general-purpose debugging pattern you should always know.

### Add a temporary output variable

```hcl
# Add this to outputs.tf temporarily
output "debug_env" {
  value = var.environment
}
```

Run `terraform plan` — it prints the output values, showing you exactly
what value Terraform is using:

```
Changes to Outputs:
  + debug_env = "command-line"   ← revealed the hidden value!
```

**Remove this output block once debugging is done.** Output variables that
show sensitive configuration details should not stay in production code.

### Complete debugging checklist

```powershell
# 1. Check current directory (most common issue)
Get-Location

# 2. List .tf files to confirm you're in the right place
Get-ChildItem *.tf

# 3. Check for TF_VAR_ environment variables
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }

# 4. Check state to see what Terraform thinks exists
terraform state list

# 5. Add a debug output variable and run plan to see variable values
# Add: output "debug_env" { value = var.environment }
terraform plan

# 6. Remove the debug output after investigation
```

---

## 13. Splat Expressions — The Shorthand For Loop

### What a splat expression is

A **splat expression** uses `[*]` to extract ONE specific attribute from
EVERY item in a collection — in one compact expression.

Think of it as a magnet that sweeps through all your resources and pulls
out one specific field from each.

```
collection[*].attribute
↑          ↑  ↑
│          │  └── which field to extract
│          └── "from every item"
└── the collection
```

### The instructor's output variable examples

```hcl
# Using for loop (longer, more flexible):
output "demo" {
  value = [for rule in local.nsg_rules : rule.description]
}

# Result: ["Allow HTTP traffic", "Allow HTTPS traffic"]
```

```hcl
# Using splat (shorter, for simple extractions):
output "splat_demo" {
  value = local.nsg_rules[*]
}

# Result: everything inside nsg_rules
```

### Drilling deeper with splat

```hcl
# Get everything inside allow_http
output "http_rule" {
  value = local.nsg_rules.allow_http
}
# Result: { priority=100, destination_port="80", description="Allow HTTP traffic" }

# Get just the description of allow_http
output "http_description" {
  value = local.nsg_rules.allow_http.description
}
# Result: "Allow HTTP traffic"
```

### Splat with resource outputs

```hcl
resource "azurerm_storage_account" "example" {
  count = 3
  name  = "account${count.index}"
  # ...
}

# Get all storage account names with splat
output "all_names" {
  value = azurerm_storage_account.example[*].name
}
# Result: ["account0", "account1", "account2"]

# Get all primary blob endpoints
output "all_endpoints" {
  value = azurerm_storage_account.example[*].primary_blob_endpoint
}
# Result: ["https://account0.blob.core.windows.net/", ...]
```

---

## 14. Splat with Lists vs Maps/Objects — The Critical Difference

### Splat and numeric indexing work with LISTS only

The instructor demonstrated this explicitly. He tried `[*]` on a map,
then tried numeric index (`[0]`) on a map/object — and got errors.

**With a list — works:**

```hcl
variable "account_names" {
  type    = list(string)
  default = ["account-a", "account-b", "account-c"]
}

# Splat — all elements
output "all" {
  value = var.account_names[*]
}
# Result: ["account-a", "account-b", "account-c"]

# Numeric index
output "first" {
  value = var.account_names[0]
}
# Result: "account-a"

output "second" {
  value = var.account_names[1]
}
# Result: "account-b"
```

**With a map/object — does NOT work with numeric index:**

```hcl
locals {
  nsg_rules = {
    allow_http  = { priority = 100 }
    allow_https = { priority = 110 }
  }
}

# ❌ FAILS — maps don't have numeric indexes
output "first_rule" {
  value = local.nsg_rules[0]   # Error!
}

# Error: "An object only supports looking up attributes by name,
#          not by numeric index"

# ✅ Access by key name instead
output "http_rule" {
  value = local.nsg_rules["allow_http"]   # Correct
}
```

### The `set` vs `list` issue the instructor demonstrated

The instructor had a `set(string)` variable and tried `[*]` on it:

```hcl
variable "account_names" {
  type    = set(string)
  default = ["account-a", "account-b", "account-c"]
}

output "all" {
  value = var.account_names[*]   # ← might error on a set
}
```

**Error:**
```
Error: Invalid expression

  var.account_names is a set of string.
  Splat expressions can only be applied to lists, not sets.
```

**Fix — change variable type from `set` to `list`:**

```hcl
variable "account_names" {
  type    = list(string)   # ← changed from set to list
  default = ["account-a", "account-b", "account-c"]
}

output "all" {
  value = var.account_names[*]   # ✅ Now works
}
```

### Type summary for splat and index access

```
Type        [*] Splat    [0] Index    Named key access
──────────  ──────────   ──────────   ────────────────
list        ✅ Works     ✅ Works     ❌ (no named keys)
set         ❌ Error     ❌ Error     ❌ (no keys)
map         ❌ Error     ❌ Error     ✅ map["key"]
object      ❌ Error     ❌ Error     ✅ object.field
```

---

## 15. `for` Loop vs Splat — When to Use Which

Both extract data from a collection. Here is when to choose each one:

### Use SPLAT when:

```
✅ You want ONE field from ALL items
✅ The collection is a list (not a set or map)
✅ No transformation or filtering needed
✅ Quick, readable shorthand
```

```hcl
# Simple — get all names from count-based resources
azurerm_storage_account.example[*].name
```

### Use FOR LOOP when:

```
✅ You need to transform values (e.g., uppercase the names)
✅ You need to filter (e.g., only accounts with Standard tier)
✅ You need to build a map (key → value output)
✅ The collection is a map or object (not a list)
✅ You need to iterate over local map variables
```

```hcl
# Transform — get all names in uppercase
[for sa in azurerm_storage_account.example : upper(sa.name)]

# Filter — only get Standard tier accounts
[for sa in azurerm_storage_account.example : sa.name if sa.account_tier == "Standard"]

# Build a map
{for sa in azurerm_storage_account.example : sa.name => sa.primary_blob_endpoint}

# Iterate over a local map (splat doesn't work on maps)
[for rule in local.nsg_rules : rule.description]
```

### Side-by-side on the same data

```hcl
# Goal: list all NSG rule descriptions

# Splat — DOESN'T WORK on maps
local.nsg_rules[*].description   # ❌ Error: maps don't support splat

# For loop — WORKS on maps
[for rule in local.nsg_rules : rule.description]
# Result: ["Allow HTTP traffic", "Allow HTTPS traffic"]
```

This is exactly what the instructor demonstrated — splat doesn't work
directly on map locals, so you need a for loop there.

---

## 16. The Complete Working Code — All Files

**`locals.tf`**
```hcl
# locals.tf
# Nested map containing all NSG security rules
# Outer key = rule name, Inner map = rule attributes

locals {
  nsg_rules = {
    allow_http = {
      priority         = 100
      destination_port = "80"
      description      = "Allow inbound HTTP traffic on port 80"
    }
    allow_https = {
      priority         = 110
      destination_port = "443"
      description      = "Allow inbound HTTPS traffic on port 443"
    }
    allow_ssh = {
      priority         = 120
      destination_port = "22"
      description      = "Allow inbound SSH traffic on port 22"
    }
  }
}
```

---

**`variables.tf`**
```hcl
# variables.tf
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure region for deployment"
  default     = "West Europe"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group"
  default     = "day10-rg"
}

# Used to demonstrate splat expression
variable "account_names" {
  type        = list(string)
  description = "List of storage account names for splat demo"
  default     = ["account-alpha", "account-beta", "account-gamma"]
}
```

---

**`resource_group.tf`**
```hcl
# resource_group.tf
resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

---

**`nsg.tf`** — Network Security Group with dynamic block + conditional expression
```hcl
# nsg.tf
resource "azurerm_network_security_group" "example" {

  # CONDITIONAL EXPRESSION — name changes based on environment
  # If environment is "dev" → "dev-nsg"
  # If environment is anything else → "stage-nsg"
  name = var.environment == "dev" ? "dev-nsg" : "stage-nsg"

  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # DYNAMIC BLOCK — generates one security_rule block per entry in local.nsg_rules
  dynamic "security_rule" {
    for_each = local.nsg_rules    # iterates over the nested map

    content {
      # security_rule.key = the outer map key ("allow_http", "allow_https", etc.)
      name = security_rule.key

      # security_rule.value = the inner map ({ priority=100, destination_port="80", ... })
      priority    = security_rule.value.priority
      description = security_rule.value.description

      # These values are the same for all rules — hardcoded in the template
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.destination_port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
```

---

**`outputs.tf`**
```hcl
# outputs.tf

# NSG name — shows conditional expression result
output "nsg_name" {
  description = "Name of the created Network Security Group"
  value       = azurerm_network_security_group.example.name
}

# NSG ID — generated by Azure after creation
output "nsg_id" {
  description = "Azure Resource ID of the NSG"
  value       = azurerm_network_security_group.example.id
}

# FOR LOOP — iterate over the local map to get all rule descriptions
output "nsg_rule_descriptions" {
  description = "Descriptions of all NSG rules (via for loop)"
  value       = [for rule in local.nsg_rules : rule.description]
}

# FOR LOOP — produce a map of rule name → priority
output "nsg_rule_priorities" {
  description = "Map of rule name to priority (via for loop)"
  value       = { for name, rule in local.nsg_rules : name => rule.priority }
}

# SPLAT — all items from the account_names list variable
output "account_names_all" {
  description = "All account names from the list variable (via splat)"
  value       = var.account_names[*]
}

# INDEX — first element from the list variable
output "account_names_first" {
  description = "First account name (index 0)"
  value       = var.account_names[0]
}

# DEBUG — shows which environment value Terraform is actually using
# Remove this in production
output "debug_environment" {
  description = "Current environment value (for debugging)"
  value       = var.environment
}
```

---

**`terraform.tfvars`**
```hcl
# terraform.tfvars
environment         = "dev"
location            = "West Europe"
resource_group_name = "day10-rg"

account_names = ["account-alpha", "account-beta", "account-gamma"]
```

---

**`provider.tf`**
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
}
```

---

**PowerShell — full workflow:**

```powershell
# 1. Navigate to project folder
Set-Location "C:\projects\day10"

# 2. Verify you're in the right place
Get-Location
Get-ChildItem *.tf

# 3. IMPORTANT: Check for and clear any stale TF_VAR_ environment variables
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }
# If any appear, remove them:
# Remove-Item Env:TF_VAR_environment

# 4. Set Azure authentication
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# 5. Initialise
terraform init

# 6. Validate
terraform validate

# 7. Plan — should show dev-nsg (environment = "dev" from terraform.tfvars)
terraform plan

# 8. Test conditional expression — override environment via -var flag
terraform plan -var="environment=staging"
# Should show: name = "stage-nsg"

# 9. Apply
terraform apply --auto-approve

# 10. View outputs
terraform output

# 11. Clean up
terraform destroy --auto-approve

# 12. Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 17. Common Mistakes Beginners Make

### Mistake 1 — Using `each.key` instead of the dynamic label inside dynamic blocks

```hcl
# ❌ WRONG — each.key only works in resource-level for_each
dynamic "security_rule" {
  for_each = local.nsg_rules
  content {
    name = each.key   # Error: "each" not available in dynamic blocks
  }
}

# ✅ CORRECT — use the dynamic block label
dynamic "security_rule" {
  for_each = local.nsg_rules
  content {
    name = security_rule.key   # Use the label defined in dynamic "security_rule"
  }
}
```

---

### Mistake 2 — Forgetting the `content { }` wrapper inside dynamic blocks

```hcl
# ❌ WRONG — no content block
dynamic "security_rule" {
  for_each = local.nsg_rules
  name     = security_rule.key   # Error: attributes not allowed here
}

# ✅ CORRECT — content block is mandatory
dynamic "security_rule" {
  for_each = local.nsg_rules
  content {                        # required wrapper
    name = security_rule.key
  }
}
```

---

### Mistake 3 — String comparison without quotes

```hcl
# ❌ WRONG — comparing to an unquoted word
var.environment == dev     # Error: "dev" unrecognised

# ✅ CORRECT — string values need double quotes
var.environment == "dev"
```

---

### Mistake 4 — Trying to use numeric index on a map/object

```hcl
locals {
  nsg_rules = {
    allow_http = { priority = 100 }
  }
}

# ❌ WRONG — maps use named keys, not numeric indexes
local.nsg_rules[0]   # Error: object supports lookup by name, not index

# ✅ CORRECT — use the key name
local.nsg_rules["allow_http"]
local.nsg_rules["allow_http"].priority
```

---

### Mistake 5 — Using splat `[*]` on a set or map variable

```hcl
# ❌ WRONG — splat doesn't work on sets or maps
variable "names" { type = set(string) }
var.names[*]   # Error: splat can only be applied to lists

# ✅ CORRECT — change to list for splat
variable "names" { type = list(string) }
var.names[*]   # Works!

# OR use a for loop for sets/maps
[for name in var.names : name]   # Works for both sets and lists
```

---

### Mistake 6 — Stale `TF_VAR_*` environment variable overriding file values

```powershell
# You set this months ago and forgot about it:
# TF_VAR_environment = "command-line"

# Now your variables.tf says default = "dev"
# But terraform plan shows "command-line" ← the env var wins

# Check and fix:
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }
Remove-Item Env:TF_VAR_environment   # remove the stale variable
```

---

### Mistake 7 — Overusing dynamic blocks

```hcl
# ❌ BAD — using dynamic when you only have one item that never changes
dynamic "security_rule" {
  for_each = { one_rule = { priority = 100, port = "80" } }
  content { ... }
}

# ✅ BETTER — just write it directly
security_rule {
  priority               = 100
  destination_port_range = "80"
  ...
}
```

The instructor warned: "Do not overuse Dynamic otherwise it will negate
the purpose of code maintainability. Use it only where it is required."

---

## 18. Practice Exercises

### Exercise 1 — Add a New Security Rule

Add an SSH rule to the `nsg_rules` local map without touching the
`nsg.tf` dynamic block. The rule should allow port 22, priority 120.

**Answer:**
```hcl
locals {
  nsg_rules = {
    allow_http  = { priority = 100, destination_port = "80",  description = "Allow HTTP" }
    allow_https = { priority = 110, destination_port = "443", description = "Allow HTTPS" }
    allow_ssh   = { priority = 120, destination_port = "22",  description = "Allow SSH" }  # ← added
  }
}
# The dynamic block in nsg.tf automatically creates a third security_rule
```

---

### Exercise 2 — Write a Conditional Expression

Write a conditional expression that:
- If `var.environment` is `"prod"`, use replication type `"GRS"`
- Otherwise, use replication type `"LRS"`

**Answer:**
```hcl
account_replication_type = var.environment == "prod" ? "GRS" : "LRS"
```

---

### Exercise 3 — Predict the Output

Given:
```hcl
variable "environment" { default = "staging" }
name = var.environment == "dev" ? "dev-nsg" : "stage-nsg"
```

And this PowerShell command is run:
```powershell
terraform plan -var="environment=dev"
```

What is the NSG name?

**Answer:**
```
"dev-nsg"

Because:
- -var flag has highest precedence → environment = "dev"
- condition: "dev" == "dev" → true
- result: "dev-nsg"
```

---

### Exercise 4 — For Loop vs Splat

Given:
```hcl
locals {
  rules = {
    rule1 = { port = "80",  priority = 100 }
    rule2 = { port = "443", priority = 110 }
  }
}
```

Write:
a) A for loop output that returns all port numbers as a list
b) Why splat `[*]` would NOT work on `local.rules`

**Answers:**
```hcl
# a) For loop — works on maps
output "all_ports" {
  value = [for rule in local.rules : rule.port]
  # Result: ["80", "443"]
}

# b) Splat doesn't work on maps because:
# local.rules is a map/object — splat [*] only works on lists
# local.rules[*].port  → Error: maps don't support splat expressions
# You must use a for loop instead
```

---

### Exercise 5 — Debug a Variable Issue

You run `terraform plan` and see `nsg_name = "stage-nsg"` but your
`terraform.tfvars` has `environment = "dev"`. What are the possible
causes and how do you investigate?

**Answer:**
```powershell
# Investigation steps:

# 1. Check for stale TF_VAR_ environment variables
Get-ChildItem Env: | Where-Object { $_.Name -like "TF_VAR_*" }
# Look for: TF_VAR_environment with a non-dev value

# 2. Add a debug output variable to see the actual value
# In outputs.tf, add:
# output "debug_env" { value = var.environment }
terraform plan
# This shows exactly what value Terraform is using

# 3. If TF_VAR_environment is set and wrong:
Remove-Item Env:TF_VAR_environment

# 4. Rerun plan — should now show "dev-nsg"
terraform plan
```

---

## 19. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║     DYNAMIC BLOCKS, CONDITIONAL EXPRESSIONS, SPLAT — DAY 10 REFERENCE       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DYNAMIC BLOCK SYNTAX                                                        ║
║                                                                              ║
║  dynamic "block_name" {           ← block_name = real block name from docs  ║
║    for_each = local.collection    ← collection to iterate (map or set)      ║
║    content {                      ← REQUIRED wrapper around the template    ║
║      name     = block_name.key    ← current item's key                      ║
║      field    = block_name.value.field  ← field from current item's value   ║
║    }                                                                         ║
║  }                                                                           ║
║                                                                              ║
║  Inside dynamic blocks:                                                      ║
║    block_name.key   → outer map key ("allow_http")                          ║
║    block_name.value → inner map ({ priority=100, ... })                     ║
║    block_name.value.field → specific inner field (100, "80", etc.)          ║
║    DO NOT use each.key / each.value in dynamic blocks!                      ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CONDITIONAL EXPRESSION (TERNARY)                                            ║
║                                                                              ║
║  condition ? true_value : false_value                                        ║
║                                                                              ║
║  Examples:                                                                   ║
║  var.env == "dev"   ? "dev-nsg"  : "stage-nsg"                              ║
║  var.env == "prod"  ? "GRS"      : "LRS"                                    ║
║  var.enabled == true ? 1         : 0                                         ║
║                                                                              ║
║  String comparisons MUST use double quotes: "dev" not dev                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SPLAT EXPRESSION [*]                                                        ║
║                                                                              ║
║  collection[*]           → all elements of a LIST                           ║
║  collection[*].field     → one field from every element of a LIST           ║
║  collection[0]           → first element (list only)                        ║
║                                                                              ║
║  ONLY works on: list(type)                                                   ║
║  Does NOT work on: set, map, object → use for loop instead                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  FOR LOOP vs SPLAT                                                           ║
║                                                                              ║
║  Splat:    list[*].field         → quick, read-only, one field, lists only  ║
║  For loop: [for x in col : x.f]  → flexible, works on any type, filterable  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  VARIABLE PRECEDENCE REMINDER (highest wins)                                 ║
║                                                                              ║
║  7. -var flag                  ← HIGHEST                                    ║
║  6. -var-file flag                                                           ║
║  4. *.auto.tfvars                                                            ║
║  3. terraform.tfvars                                                         ║
║  1. TF_VAR_* env variables     ← below tfvars but above default             ║
║  0. variable { default = ... }  ← FALLBACK if nothing else set              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL DEBUGGING                                                        ║
║                                                                              ║
║  Check TF_VAR_ vars:  Get-ChildItem Env: | Where {$_.Name -like "TF_VAR_*"} ║
║  Remove TF_VAR_ var:  Remove-Item Env:TF_VAR_environment                    ║
║  Debug variable value: add output "debug" { value = var.name } + tf plan    ║
║  Check directory:     Get-Location                                           ║
║  List .tf files:      Get-ChildItem *.tf                                     ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
DYNAMIC BLOCK = a photocopier for resource sub-blocks
  You give it: a template (content { }) + a stack of data (local map)
  It produces: one filled-in copy of the template per data entry
  Use when: a resource has a repeating sub-block (security_rule, ingress, etc.)

CONDITIONAL EXPRESSION = a traffic light
  condition ? green_path : red_path
  Evaluates to ONE value based on whether the condition is true or false
  Use when: a field needs different values for different environments/conditions

SPLAT EXPRESSION = a magnet sweep
  collection[*].field  →  pulls one field from every item in the list
  Quick and readable — but ONLY works on lists
  Use when: you need one attribute from all items and the collection is a list
  For maps/sets → use a for loop instead

TOGETHER these three give you:
  Dynamic blocks    = loop over data to generate repeated config blocks
  Conditionals      = choose between values based on conditions
  Splat/for loops   = extract and transform values from collections
```

---

*Guide covers: Terraform dynamic blocks, dynamic keyword, content block, iterator
label, for_each inside dynamic, security_rule.key, security_rule.value, nested map
locals, two-level nested map, dynamic vs static blocks, Azure Network Security Group,
azurerm_network_security_group, security_rule sub-block, conditional expressions,
ternary operator, condition ? true : false, string comparison with double quotes,
TF_VAR_* environment variable precedence, variable debugging with output blocks,
splat expressions [*], list vs set vs map with splat, numeric index access on lists,
for loop vs splat comparison, PowerShell TF_VAR_ debugging commands, Remove-Item
Env:TF_VAR_name, Get-ChildItem Env: Where-Object, dynamic block overuse warning.*
