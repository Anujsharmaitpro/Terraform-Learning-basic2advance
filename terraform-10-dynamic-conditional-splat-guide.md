# Terraform Dynamic Expressions, Conditional Expressions & Splat Expressions
## Deep-Dive Learning Guide — Day 10 / Lecture 28 | Beginner-Friendly Edition

---

## Before You Start — Read This First

This guide assumes you know **absolutely nothing** beyond the very basics of Terraform.
Every concept is explained from scratch, with plain-English analogies before the code.
If a word sounds unfamiliar, it will be explained right there — no jumping around.

---

## Table of Contents

1. What Are "Expressions" in Terraform? (The Big Picture)
2. Quick Recap — Data Types You Need to Know First
3. What Are We Building in This Lecture? (The Azure NSG)
4. Dynamic Blocks — The Problem They Solve
5. Dynamic Blocks — How They Work Step by Step
6. locals — What They Are and Why We Use Them
7. The Nested Map — Dissected Line by Line
8. How `dynamic` Iterates — The Full Mental Model
9. Conditional Expressions — Plain English First
10. Conditional Expressions — Syntax Breakdown
11. Variable Precedence — The Debugging Lesson from the Video
12. Splat Expressions — What They Are
13. Splat vs For Loop — Side-by-Side
14. Splat with Lists vs Maps — The Key Difference
15. What the Instructor Demo Showed — Step by Step
16. Common Mistakes Beginners Make
17. Practice Exercises (Beginner → Intermediate)
18. Everything in One Cheat Sheet

---

## 1. What Are "Expressions" in Terraform? (The Big Picture)

Before writing any code, let's agree on what the word "expression" means.

In Terraform, an **expression** is anything that produces a value. The simplest expression is a plain string:

```hcl
name = "my-server"
```

`"my-server"` is an expression — it produces the value `my-server`.

A slightly more complex expression is a variable reference:

```hcl
name = var.server_name
```

`var.server_name` is an expression — it produces whatever value is stored in the variable.

This lecture covers three types of **advanced expressions**:

| Expression Type | What It Does in Plain English |
|---|---|
| Dynamic Block | "Repeat this block of config for every item in my list" |
| Conditional Expression | "Use value A if condition is true, otherwise use value B" |
| Splat Expression | "Give me this one field from every item in my collection" |

Think of these as **power tools** — you don't always need them, but when you do, they save enormous amounts of repetitive code.

---

## 2. Quick Recap — Data Types You Need to Know First

The entire lecture builds on these. Make sure you're solid on them.

### String
A piece of text wrapped in double quotes.
```hcl
"hello"
"dev"
"t2.micro"
```

### Number
A plain number, no quotes.
```hcl
100
443
3
```

### Boolean
True or false, no quotes.
```hcl
true
false
```

### List
An ordered collection of items. Uses square brackets `[ ]`. Items are accessed by position (0, 1, 2…).
```hcl
["alice", "bob", "charlie"]
# alice is at position [0]
# bob   is at position [1]
```

### Map
A collection of key → value pairs. Uses curly braces `{ }`. Items are accessed by name (the key).
```hcl
{
  name     = "web-server"
  env      = "dev"
  port     = "80"
}
```

### Nested Map (what the video uses)
A map where the values are themselves maps. Think of it like a folder inside a folder.
```hcl
{
  allow_http = {           # outer key
    priority = 100         # inner key-value
    port     = "80"        # inner key-value
  }
  allow_https = {          # outer key
    priority = 110         # inner key-value
    port     = "443"       # inner key-value
  }
}
```
To get the port of allow_http, you navigate: `allow_http` → `port` → `"80"`.

---

## 3. What Are We Building in This Lecture?

The instructor builds an **Azure Network Security Group (NSG)** with two rules:
- Allow HTTP traffic on port 80
- Allow HTTPS traffic on port 443

### What is a Network Security Group?

Think of an NSG as a **bouncer at a nightclub door**. It checks every person (network packet) trying to enter or leave and decides: "Does this person follow our rules? Yes → let them in. No → turn them away."

The rules say things like:
- "Allow anyone coming to port 80 (HTTP traffic)"
- "Allow anyone coming to port 443 (HTTPS traffic)"
- "Block everything else"

### Why is this a good teaching example?

Because an NSG can have **many rules**, and every rule has the **same set of fields** (priority, port, direction, action, description). This is the perfect situation to use a Dynamic Block — instead of copy-pasting the rule block for every new rule, you define it once and let Terraform repeat it automatically.

### The resources created:
```
1. azurerm_resource_group      → a container for all resources (like a project folder)
2. azurerm_network_security_group → the NSG itself, containing security rules
```

---

## 4. Dynamic Blocks — The Problem They Solve

### The repetitive way (without dynamic)

Suppose you need to define three security rules. Without dynamic blocks, you write:

```hcl
resource "azurerm_network_security_group" "example" {
  name                = "my-nsg"
  location            = "East US"
  resource_group_name = "my-rg"

  security_rule {
    name                       = "allow_http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "80"
    description                = "Allow HTTP"
  }

  security_rule {
    name                       = "allow_https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "443"
    description                = "Allow HTTPS"
  }

  security_rule {
    name                       = "allow_ssh"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "22"
    description                = "Allow SSH"
  }
}
```

**The problems:**
- If you need 10 rules, you copy this block 10 times
- If you want to change `direction` from `"Inbound"` to `"Outbound"` on all rules, you change it in 10 places
- If you get a new rule from a config file or database, you have to manually add a new block
- This is the opposite of what Terraform is for

### The dynamic block way

Define the rule structure **once**. Store the actual values in a data structure (a local map). Let Terraform iterate automatically.

```
Data (local map)     +    Template (dynamic block)    =    3 security_rule blocks
```

This is exactly what the video demonstrates.

---

## 5. Dynamic Blocks — How They Work Step by Step

Here is the complete code from the video, broken into understandable parts.

### Step 1 — The locals file (`local.tf`)

```hcl
locals {
  nsg_rules = {
    allow_http = {
      priority             = 100
      destination_port     = "80"
      description          = "Allow HTTP"
    }
    allow_https = {
      priority             = 110
      destination_port     = "443"
      description          = "Allow HTTPS"
    }
  }
}
```

Think of `locals` as a **scratchpad inside your Terraform project**. You define values here that you want to reuse without making them user-facing variables.

`nsg_rules` is the name of this local. It is a nested map with two entries.

### Step 2 — The main resource with a dynamic block (`main.tf`)

```hcl
resource "azurerm_network_security_group" "example" {
  name                = "my-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
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

### Understanding every new keyword

**`dynamic "security_rule"`**

The word after `dynamic` is the name of the block you are generating. In the Azure documentation, the block is called `security_rule`. So you write `dynamic "security_rule"` — you are saying "dynamically generate `security_rule` blocks."

**`for_each = local.nsg_rules`**

This is the instruction to iterate. It says: "Go through every entry in `local.nsg_rules` and run the `content` block once for each entry."

Since `nsg_rules` has two entries (`allow_http` and `allow_https`), the `content` block will run **twice** — once for HTTP and once for HTTPS.

**`content { ... }`**

This is required when using dynamic blocks. Everything inside `content { }` is what one single `security_rule` block looks like. Terraform uses this as a template and fills in the values on each iteration.

**`security_rule.key`**

`security_rule` here is the **iterator name** — it is automatically set to the name you gave in `dynamic "security_rule"`. On the first iteration, `security_rule.key` is `"allow_http"`. On the second iteration, it is `"allow_https"`.

Think of it like this: if `for_each` were a for loop, `security_rule.key` is the loop variable holding the current key.

**`security_rule.value.priority`**

`security_rule.value` is the entire inner map for the current entry:
```
{ priority = 100, destination_port = "80", description = "Allow HTTP" }
```

Adding `.priority` drills into that map to get just `100`.

### How the two iterations play out

**First pass — allow_http:**
```
security_rule.key               → "allow_http"
security_rule.value.priority    → 100
security_rule.value.destination_port → "80"
security_rule.value.description → "Allow HTTP"
```
→ Produces one `security_rule` block for HTTP

**Second pass — allow_https:**
```
security_rule.key               → "allow_https"
security_rule.value.priority    → 110
security_rule.value.destination_port → "443"
security_rule.value.description → "Allow HTTPS"
```
→ Produces one `security_rule` block for HTTPS

**Final result — what Terraform actually creates in Azure:**
Two security rules. Exactly what you'd get if you'd written them out manually, but with zero duplication.

---

## 6. locals — What They Are and Why We Use Them

### What is a `local`?

A `local` is a **value you calculate or define once inside your Terraform code** and reuse in multiple places.

Compare these three ways to store data:

| Type | Defined by | Can user change it? | Use case |
|---|---|---|---|
| `variable` | User / tfvars file | Yes | Values that change per environment |
| `local` | You, in the code | No (it's computed) | Intermediate values, complex structures |
| Hard-coded string | You, inline | No | Simple, one-time values |

### Syntax

```hcl
locals {
  # a simple local
  region = "eastus"

  # a local that computes from a variable
  full_name = "${var.project}-${var.environment}"

  # a complex local (a nested map, as used in this lecture)
  nsg_rules = {
    allow_http = {
      priority = 100
      port     = "80"
    }
  }
}
```

### How to reference a local

Always use `local.` (singular, no "s"):

```hcl
location = local.region
name     = local.full_name
for_each = local.nsg_rules
```

> Note: You define locals inside `locals { }` (with an "s"), but you reference them with `local.` (without the "s"). This trips up many beginners.

---

## 7. The Nested Map — Dissected Line by Line

The data structure from the video is the heart of everything. Let's read it together very carefully:

```hcl
locals {
  nsg_rules = {           # nsg_rules is the name of this local variable
                          # Its value is a map (notice the outer { } )

    allow_http = {        # "allow_http" is the KEY of the first entry
                          # Its VALUE is another map (the inner { } )
      priority         = 100
      destination_port = "80"
      description      = "Allow HTTP"
    }                     # end of allow_http's value

    allow_https = {       # "allow_https" is the KEY of the second entry
                          # Its VALUE is another map
      priority         = 110
      destination_port = "443"
      description      = "Allow HTTPS"
    }                     # end of allow_https's value

  }                       # end of nsg_rules map
}                         # end of locals block
```

### Visualising it as a table

| Outer Key | priority | destination_port | description |
|---|---|---|---|
| allow_http | 100 | "80" | "Allow HTTP" |
| allow_https | 110 | "443" | "Allow HTTPS" |

When `dynamic` iterates over this, it processes one row at a time.

### How to navigate this structure in code

```hcl
# Get the outer key:
security_rule.key                    → "allow_http" (first iteration)

# Get the entire inner map:
security_rule.value                  → { priority=100, destination_port="80", ... }

# Get a specific field from the inner map:
security_rule.value.priority         → 100
security_rule.value.destination_port → "80"
security_rule.value.description      → "Allow HTTP"
```

---

## 8. How `dynamic` Iterates — The Full Mental Model

Think of Terraform running the dynamic block like a human filling out a form multiple times:

```
Terraform picks up the template (content block)
Terraform looks at local.nsg_rules
Terraform says: "I see 2 entries. I will fill out the form 2 times."

--- FORM FILL #1 ---
Current entry: allow_http
name               = "allow_http"        (security_rule.key)
priority           = 100                 (security_rule.value.priority)
destination_port   = "80"               (security_rule.value.destination_port)
description        = "Allow HTTP"        (security_rule.value.description)
→ Create one security_rule block with these values

--- FORM FILL #2 ---
Current entry: allow_https
name               = "allow_https"       (security_rule.key)
priority           = 110                 (security_rule.value.priority)
destination_port   = "443"              (security_rule.value.destination_port)
description        = "Allow HTTPS"       (security_rule.value.description)
→ Create one security_rule block with these values

Done. Two security rules created.
```

If you add a third entry `allow_ssh` to `nsg_rules`, Terraform will automatically do a third form fill and create a third rule — you change only the data, never the template.

### The warning from the instructor — Don't overuse dynamic

Dynamic blocks are powerful but they make code harder to read when overused. Use them only when:
- You have a repeating sub-block (like `security_rule`, `ingress`, `egress`)
- The number of repetitions is data-driven (comes from a variable or local)
- The alternative is copy-pasting the same block multiple times

Do NOT use dynamic for simple attribute values — use `for_each` on the resource itself instead.

---

## 9. Conditional Expressions — Plain English First

### The everyday version

You already use conditional logic every day without realising it:

> "If it's raining, I'll take an umbrella. Otherwise, I'll leave it at home."

In code terms:
```
condition ? value_if_true : value_if_false
```

This is called a **ternary expression** in most programming languages. Terraform calls it a **conditional expression**.

### Why you need this in Terraform

Imagine you're deploying the same infrastructure to two environments:
- `dev` — you name things `dev-nsg`, `dev-server`, etc.
- `staging` — you name things `stage-nsg`, `stage-server`, etc.

Instead of maintaining two separate Terraform files, you write ONE file and use a conditional to pick the right name based on the environment variable.

---

## 10. Conditional Expressions — Syntax Breakdown

### The syntax

```
condition ? true_value : false_value
```

Read it as: "If condition is true → use true_value, else → use false_value"

### The exact example from the video

```hcl
variable "environment" {
  default = "dev"
}

resource "azurerm_network_security_group" "example" {
  name = var.environment == "dev" ? "dev-nsg" : "stage-nsg"
  # ...
}
```

Breaking it down:

```
var.environment == "dev"    ← CONDITION: "Is the environment variable equal to 'dev'?"
?                           ← "If yes..."
"dev-nsg"                   ← TRUE VALUE: use this name
:                           ← "If no..."
"stage-nsg"                 ← FALSE VALUE: use this name instead
```

### Tracing both scenarios

**Scenario A — environment = "dev"**
```
var.environment == "dev"   → true
name = "dev-nsg"           ✓
```

**Scenario B — environment = "staging" or anything else**
```
var.environment == "dev"   → false
name = "stage-nsg"         ✓
```

### More conditional expression examples

```hcl
# Conditional instance type
instance_type = var.environment == "prod" ? "t3.large" : "t2.micro"

# Conditional count (create resource only in prod)
count = var.environment == "prod" ? 1 : 0

# Conditional tag
tags = {
  Backup = var.environment == "prod" ? "true" : "false"
}

# Nested conditional (use carefully — it hurts readability)
name = var.env == "prod" ? "prod-nsg" : var.env == "dev" ? "dev-nsg" : "stage-nsg"
```

---

## 11. Variable Precedence — The Debugging Lesson from the Video

This section is based on the live debugging the instructor did when the NSG was getting the name `stage-nsg` even though the variable file said `dev`.

### The problem

The instructor had `environment = "dev"` in `variables.tf` but the plan showed `stage-nsg`. Why?

### The answer: Terraform's variable precedence order

Terraform reads variable values from multiple sources. When the same variable appears in more than one source, Terraform uses the one with the **highest precedence** (the one that "wins").

From lowest priority to highest:

```
1. Default value in variable block          ← lowest priority (loses to everything)
   variable "environment" { default = "dev" }

2. terraform.tfvars file
   environment = "dev"

3. *.auto.tfvars files
   environment = "dev"

4. -var flag on the command line
   terraform plan -var="environment=staging"

5. Environment variables (TF_VAR_*)         ← highest priority (wins over everything)
   export TF_VAR_environment=command_line
```

### What happened in the video

The instructor had previously run `export TF_VAR_environment=command_line` in the terminal (or something similar had set it). Even though the file said `dev`, the shell environment variable overrode it.

He confirmed this by running:
```bash
env | grep -i env
```
And found `TF_VAR_environment=command_line` in the output.

**The fix:**
```bash
unset TF_VAR_environment   # removes the environment variable from the shell
```

After unsetting, `terraform plan` correctly showed `dev-nsg`.

### Why this matters

This is one of the most confusing bugs beginners hit. When your Terraform plan shows something different from what's in your file, **always check:**
1. Are there any `TF_VAR_` environment variables set in your shell?
2. Are there any `-var` flags being passed by a CI/CD pipeline?
3. Is there a `terraform.tfvars` file with a conflicting value?

**How to debug variable values** (exactly as shown in the video):

```hcl
# Add a temporary output to see what Terraform thinks a variable is
output "debug_env" {
  value = var.environment
}
```

Run `terraform plan` and read the output — it will show you exactly what value Terraform is using. Remove the output block once debugging is done.

---

## 12. Splat Expressions — What They Are

### The plain English version

Imagine you have a bag of 5 apples. You want to know the weight of each apple. You could:

**Option A (For Loop):** Pick up each apple one by one, weigh it, write it down.

**Option B (Splat):** Put them all on the scale at once and get all 5 weights in one shot.

Splat expressions are **Option B** — they let you extract one specific field from every item in a collection in a single, compact expression.

### The symbol

Splat uses `[*]` — a star inside square brackets.

```hcl
# With a list of instances:
aws_instance.web[*].public_ip
# → gives you ALL public IPs from ALL instances, as a list
```

---

## 13. Splat vs For Loop — Side by Side

Both accomplish the same thing. Splat is just a shorter syntax for the most common case.

### Goal: get the description field from every NSG rule

**Using a for loop (longer but flexible):**
```hcl
output "demo" {
  value = [for rule in local.nsg_rules : rule.description]
}
# Result: ["Allow HTTP", "Allow HTTPS"]
```

**Using splat (shorter, works on lists):**
```hcl
output "demo" {
  value = var.account_names[*]   # gets every element
}
```

### When to use which

| Situation | Use |
|---|---|
| Get one field from every item | Splat `[*].field_name` |
| Transform or filter items | For loop |
| Complex condition per item | For loop |
| Just need all items quickly | Splat `[*]` |

---

## 14. Splat with Lists vs Maps — The Key Difference

This is the specific confusion that came up in the video. Pay attention here.

### Splat works with LISTS

A list is ordered and uses numeric indexes.

```hcl
variable "account_names" {
  type    = list(string)
  default = ["account-a", "account-b", "account-c"]
}

# Get all account names
output "all_accounts" {
  value = var.account_names[*]
}
# Result: ["account-a", "account-b", "account-c"]

# Get just the first element
output "first_account" {
  value = var.account_names[0]
}
# Result: "account-a"

# Get just the second element
output "second_account" {
  value = var.account_names[1]
}
# Result: "account-b"
```

### Splat does NOT work with MAPS (in most cases)

A map uses named keys, not numeric indexes. You cannot use `[0]` on a map.

```hcl
locals {
  nsg_rules = {
    allow_http  = { port = "80" }
    allow_https = { port = "443" }
  }
}

# This ERRORS:
output "bad" {
  value = local.nsg_rules[0]   # ❌ maps have no numeric index
}

# Error: "An object only supports looking up attributes by name,
#          not by numeric index"
```

To work with maps, use a for loop:

```hcl
output "good" {
  value = [for k, v in local.nsg_rules : v.port]
  # Result: ["80", "443"]
}
```

### How the instructor demonstrated this

He had `account_names` as a set, tried `[*]` on it, got an error. Changed it to `type = list(string)`, and then `[*]` worked correctly. The distinction:

```
set   → unordered, unique values, no numeric index → splat doesn't work
list  → ordered, allows duplicates, has numeric index → splat works
map   → key-value pairs, named keys only → splat doesn't work
```

---

## 15. What the Instructor Demo Showed — Step by Step

### Part 1 — Dynamic Block Demo

1. Created `local.tf` with `nsg_rules` (a nested map with two entries)
2. Created `main.tf` with an `azurerm_network_security_group` resource
3. Inside it, used `dynamic "security_rule"` with `for_each = local.nsg_rules`
4. Used `content { }` block with `security_rule.key` and `security_rule.value.*` references
5. Ran `terraform init` → `terraform plan` → `terraform apply --auto-approve`
6. Verified in Azure Portal: Resource Group → NSG → saw 2 custom inbound rules (HTTP port 80, HTTPS port 443) alongside the Azure defaults

### Part 2 — Conditional Expression Demo

1. Added a `variable "environment"` with default `"dev"` in `variables.tf`
2. Changed the NSG `name` attribute to: `var.environment == "dev" ? "dev-nsg" : "stage-nsg"`
3. First `terraform plan` errored because of square brackets (syntax fix needed)
4. Fixed it and re-ran — got `stage-nsg` unexpectedly
5. Debugged by adding an output variable to print `var.environment`
6. Discovered a shell environment variable `TF_VAR_environment` was overriding the default
7. Ran `unset TF_VAR_environment` to clear it
8. Re-ran plan — now correctly showed `dev-nsg`
9. Tested by passing `-var="environment=stage"` → showed `stage-nsg` ✓
10. Applied changes — Azure Portal confirmed `dev-nsg`

### Part 3 — Splat Expression Demo

1. Created an `output "demo"` that used a for loop to extract descriptions from `local.nsg_rules`
2. Created an `output "splat"` using `local.nsg_rules[*]` to get all values
3. Drilled deeper with `local.nsg_rules.allow_http` to get one entry's values
4. Drilled even deeper with `local.nsg_rules.allow_http.description` for a single field
5. Demonstrated numeric index access (`[0]`, `[1]`) on a list variable `account_names`
6. Showed the error when trying numeric index on a map/object
7. Fixed it by changing the variable type from `set` to `list`

---

## 16. Common Mistakes Beginners Make

### Mistake 1 — Forgetting the `content { }` block inside `dynamic`

```hcl
# WRONG
dynamic "security_rule" {
  for_each = local.nsg_rules
  name     = security_rule.key   # ❌ direct field, not inside content
}

# CORRECT
dynamic "security_rule" {
  for_each = local.nsg_rules
  content {
    name = security_rule.key     # ✅ inside content block
  }
}
```

---

### Mistake 2 — Using `each.key` inside a dynamic block instead of the iterator name

```hcl
# WRONG
dynamic "security_rule" {
  for_each = local.nsg_rules
  content {
    name = each.key   # ❌ 'each' is for resource-level for_each, not dynamic
  }
}

# CORRECT
dynamic "security_rule" {
  for_each = local.nsg_rules
  content {
    name = security_rule.key   # ✅ use the dynamic block's name as the iterator
  }
}
```

---

### Mistake 3 — Referencing a local with `locals.` (plural)

```hcl
# WRONG
for_each = locals.nsg_rules   # ❌ "locals" (plural) doesn't work

# CORRECT
for_each = local.nsg_rules    # ✅ "local" (singular)
```

---

### Mistake 4 — Using `[0]` on a map

```hcl
# WRONG
local.nsg_rules[0]   # ❌ maps don't have numeric indexes

# CORRECT
local.nsg_rules["allow_http"]  # ✅ use the named key
# Or use a for loop to iterate all entries
```

---

### Mistake 5 — Forgetting `"dev"` needs quotes in a conditional

```hcl
# WRONG — comparing with an unquoted word
var.environment == dev ? "dev-nsg" : "stage-nsg"   # ❌

# CORRECT — string values must be in double quotes
var.environment == "dev" ? "dev-nsg" : "stage-nsg"  # ✅
```

---

### Mistake 6 — Overusing dynamic blocks

```hcl
# DO NOT do this for a single, never-changing block
dynamic "security_rule" {
  for_each = ["only-one-rule"]
  content { ... }
}

# Just write it directly — dynamic is overkill here
security_rule {
  ...
}
```

---

### Mistake 7 — Shell variable overriding your variable file silently

If your plan shows unexpected values, always run:

```bash
env | grep TF_VAR
```

If you see any `TF_VAR_` entries, they are overriding your files. Use `unset TF_VAR_varname` to remove them.

---

## 17. Practice Exercises (Beginner → Intermediate)

### Exercise 1 — Beginner: Read a nested map
Given this local:

```hcl
locals {
  servers = {
    web = { port = "80",  os = "Ubuntu" }
    db  = { port = "5432", os = "CentOS" }
  }
}
```

Write the expressions to get:
- The OS of the `web` server
- The port of the `db` server
- All entries in `servers`

**Answers:**
```hcl
local.servers["web"].os        → "Ubuntu"
local.servers["db"].port       → "5432"
local.servers              → the full map
```

---

### Exercise 2 — Beginner: Write a conditional expression

Write a conditional that sets `instance_type` to `"t3.large"` if `var.environment` is `"prod"`, and `"t2.micro"` for everything else.

**Answer:**
```hcl
instance_type = var.environment == "prod" ? "t3.large" : "t2.micro"
```

---

### Exercise 3 — Intermediate: Write a dynamic block

You have this local:
```hcl
locals {
  ports = {
    http  = { number = "80",   priority = 100 }
    https = { number = "443",  priority = 110 }
    ssh   = { number = "22",   priority = 120 }
  }
}
```

Write the `dynamic "security_rule"` block that creates one rule per entry.

**Answer:**
```hcl
dynamic "security_rule" {
  for_each = local.ports
  content {
    name                       = security_rule.key
    priority                   = security_rule.value.priority
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = security_rule.value.number
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
```

---

### Exercise 4 — Intermediate: Debug a variable problem

Your `variables.tf` has:
```hcl
variable "region" {
  default = "eastus"
}
```

But `terraform plan` shows `westus` as the region. What are the possible causes and how do you investigate?

**Answer:**
- Check for a `TF_VAR_region` shell variable: `env | grep TF_VAR`
- Check for a `terraform.tfvars` file with `region = "westus"`
- Check for a `-var="region=westus"` flag being passed by a script or CI/CD
- Add `output "debug_region" { value = var.region }` and run plan to confirm the value Terraform is using

---

### Exercise 5 — Intermediate: Splat vs For Loop

Given:
```hcl
variable "server_names" {
  type    = list(string)
  default = ["web1", "web2", "web3"]
}
```

Write:
- A splat expression to get all server names
- An expression to get just the first server name
- A for loop to get all names as uppercase (hint: use `upper()` function)

**Answer:**
```hcl
# Splat — all names
var.server_names[*]

# First element
var.server_names[0]

# For loop with transformation
[for name in var.server_names : upper(name)]
# Result: ["WEB1", "WEB2", "WEB3"]
```

---

## 18. Everything in One Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║         TERRAFORM DYNAMIC / CONDITIONAL / SPLAT — QUICK REFERENCE          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DYNAMIC BLOCK                                                               ║
║                                                                              ║
║  dynamic "block_name" {                                                      ║
║    for_each = local.my_map        ← iterate over this map/set               ║
║    content {                      ← required wrapper — template goes here   ║
║      field = block_name.key       ← the current map key                     ║
║      field = block_name.value.X   ← a field from the current map value      ║
║    }                                                                         ║
║  }                                                                           ║
║                                                                              ║
║  Rules:                                                                      ║
║  - block_name must match the real block name from docs (e.g. security_rule) ║
║  - content { } is mandatory                                                  ║
║  - use block_name.key and block_name.value (NOT each.key / each.value)      ║
║  - don't overuse — only for repeating sub-blocks                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CONDITIONAL EXPRESSION                                                      ║
║                                                                              ║
║  condition ? true_value : false_value                                        ║
║                                                                              ║
║  Examples:                                                                   ║
║  var.env == "prod"   ? "prod-nsg"   : "stage-nsg"                           ║
║  var.env == "prod"   ? "t3.large"   : "t2.micro"                            ║
║  var.enabled == true ? 1            : 0                                      ║
║                                                                              ║
║  String comparisons MUST use double quotes:  "dev"  not  dev                ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SPLAT EXPRESSION                                                            ║
║                                                                              ║
║  list_var[*]              → all elements of a list                           ║
║  list_var[*].field        → one field from every element                     ║
║  list_var[0]              → first element                                    ║
║  list_var[1]              → second element                                   ║
║                                                                              ║
║  ONLY works on lists. Does NOT work on maps or sets.                        ║
║  For maps → use a for loop:  [for k, v in my_map : v.field]                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LOCALS                                                                      ║
║                                                                              ║
║  Define:    locals { my_val = "hello" }    ← plural "locals"                ║
║  Reference: local.my_val                   ← singular "local"               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  VARIABLE PRECEDENCE (highest wins)                                          ║
║                                                                              ║
║  5. TF_VAR_* environment variables   ← WINS (check with: env | grep TF_VAR) ║
║  4. -var flag on command line                                                ║
║  3. *.auto.tfvars files                                                      ║
║  2. terraform.tfvars file                                                    ║
║  1. default in variable block        ← LOSES to everything above            ║
║                                                                              ║
║  Debug: output "check" { value = var.myvar }  then run terraform plan       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  NESTED MAP ACCESS                                                           ║
║                                                                              ║
║  local.nsg_rules                          → entire map                      ║
║  local.nsg_rules["allow_http"]            → inner map for allow_http        ║
║  local.nsg_rules["allow_http"].priority   → value 100                       ║
║                                                                              ║
║  Inside dynamic:                                                             ║
║  security_rule.key          → "allow_http"                                   ║
║  security_rule.value        → { priority=100, port="80", ... }              ║
║  security_rule.value.port   → "80"                                           ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Three Core Mental Models — Summarised

**Dynamic Block** = A photocopier for resource sub-blocks. You give it one template and a list of data. It makes one copy per data item, filling in the template with that item's values.

**Conditional Expression** = A traffic light. Green (true) → go one way. Red (false) → go another way. Always exactly two possible outcomes.

**Splat Expression** = A magnet sweeping across a table of items. `[*].fieldname` pulls that one field out of every single item in one sweep, giving you a list of all those values.

---

*Guide covers: Terraform dynamic blocks, content block, for_each inside dynamic, locals vs variables, nested maps, security_rule iteration, conditional expressions, ternary syntax, variable precedence, TF_VAR_ shell variables, splat expressions [*], list vs map indexing, for loop vs splat, debugging variable values with outputs.*
