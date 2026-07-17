# Terraform Mastery Guide
## `for_each` and `dynamic` Blocks — From Zero to Confident
**A Standalone Learning Guide — No Azure Knowledge Required First**

---

## Before We Start — The One Sentence to Remember

```
for_each on a RESOURCE   →  creates MULTIPLE SEPARATE RESOURCES
dynamic inside a RESOURCE →  creates MULTIPLE BLOCKS inside ONE RESOURCE
```

Everything in this guide is just unpacking that one sentence slowly,
with examples, until it feels obvious. Read it again. Then keep going.

---

## PART 1 — Understanding `for_each` on Resources

### Step 1: The Problem Without `for_each`

Imagine you need to create 3 folders on your computer.
Without any looping tool, you would type:

```powershell
mkdir folder1
mkdir folder2
mkdir folder3
```

Three commands. Fine for 3. Painful for 30. Terraform has the
exact same problem — without `for_each`, one resource block
creates exactly one resource. If you need 3 similar resources,
you write 3 nearly-identical resource blocks.

### Step 2: The Old (Bad) Way in Terraform

```hcl
resource "azurerm_storage_container" "container_1" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "container_2" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "container_3" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}
```

Notice: 90% of this is identical. Only the `name` changes.
This is exactly the kind of repetition programming languages
exist to eliminate. Terraform gives you `for_each` for this.

### Step 3: The Same Thing, With `for_each`

```hcl
resource "azurerm_storage_container" "containers" {
  for_each              = toset(["logs", "backups", "uploads"])
  name                  = each.value
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}
```

One block. Three resources created. Let's break down every
single piece of this so nothing is a mystery.

---

### Step 4: Breaking Down Every Piece

```hcl
resource "azurerm_storage_container" "containers" {
```
This line is unchanged from normal Terraform. `"containers"` is
just a label — Terraform's internal nickname for this block.
It does NOT become the resource name in Azure. That comes later.

```hcl
  for_each = toset(["logs", "backups", "uploads"])
```
This is the new part. `for_each` tells Terraform:
*"Don't create one resource. Create one resource FOR EACH item
in this list."*

`toset(...)` converts the list `["logs", "backups", "uploads"]`
into a **set** — a collection where order doesn't matter and
every item is unique. `for_each` requires a `set` or a `map` —
it will refuse to accept a plain `list`. We will explain why
later in this guide.

```hcl
  name = each.value
```
This is where the magic happens. Inside a `for_each` block,
Terraform gives you a special variable called `each`. For every
resource it creates, `each.value` holds the current item from
your set. On the first pass, `each.value = "logs"`. On the
second pass, `each.value = "backups"`. On the third,
`each.value = "uploads"`.

```hcl
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
```
These two lines are identical for every resource created —
they don't use `each` at all. Not every line inside a `for_each`
block needs to reference `each`. Only the lines that should
differ per resource.

---

### Step 5: What Terraform Actually Does Behind the Scenes

When you run `terraform plan` with the code above, Terraform
shows you this:

```
# azurerm_storage_container.containers["logs"] will be created
# azurerm_storage_container.containers["backups"] will be created
# azurerm_storage_container.containers["uploads"] will be created
```

Notice the square brackets: `containers["logs"]`. Terraform
tracks each resource individually using the value as its key.
This matters enormously — if you later remove `"backups"` from
your list and run `terraform apply` again, Terraform destroys
ONLY that one container. The other two are completely untouched.

```
Before: ["logs", "backups", "uploads"]
After:  ["logs", "uploads"]              ← removed "backups"

Terraform plan shows:
# azurerm_storage_container.containers["backups"] will be destroyed
# (0 resources changed, 1 destroyed, 0 created)
```

This is the entire value proposition of `for_each`: **each item
is independently tracked.** Nothing else gets touched when you
change one entry.

---

## PART 2 — `for_each` with a Map (Key AND Value)

### Step 1: When a Set Isn't Enough

The `toset(["logs", "backups", "uploads"])` example above only
gives you a NAME for each resource. But what if each resource
also needs its own unique VALUE alongside the name?

**Real example:** You want to create 3 storage containers,
and each one needs a different access level.

```
logs     → private
backups  → private
uploads  → blob     (publicly readable, like product images)
```

A `set` can't hold two pieces of information per item. You need
a `map` — a collection of `key = value` pairs.

### Step 2: The Map Syntax

```hcl
variable "containers_config" {
  type = map(string)
}
```

```hcl
# terraform.tfvars
containers_config = {
  "logs"    = "private"
  "backups" = "private"
  "uploads" = "blob"
}
```

Think of a map exactly like a dictionary or an address book:
```
Name (key)    →  Phone Number (value)
"Alice"       →  "555-1234"
"Bob"         →  "555-5678"
```

### Step 3: Using the Map in `for_each`

```hcl
resource "azurerm_storage_container" "containers" {
  for_each              = var.containers_config
  name                  = each.key      # "logs", "backups", "uploads"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = each.value    # "private", "private", "blob"
}
```

### Step 4: The Critical Difference — `each.key` vs `each.value`

This is the single most common point of confusion. Here is the
rule, memorize it:

```
When for_each = a SET        →  each.key  ==  each.value  (they are the SAME)
When for_each = a MAP        →  each.key  !=  each.value  (key is different from value)
```

**Visual comparison:**

```
SET example:
  for_each = toset(["logs", "backups", "uploads"])

  Iteration 1: each.key = "logs"     each.value = "logs"     (identical)
  Iteration 2: each.key = "backups"  each.value = "backups"  (identical)

MAP example:
  for_each = { "logs" = "private", "uploads" = "blob" }

  Iteration 1: each.key = "logs"     each.value = "private"  (different!)
  Iteration 2: each.key = "uploads"  each.value = "blob"     (different!)
```

**The practical rule for which one to use:**

```
Does each item need ONLY a name?          → use a SET, use each.value
Does each item need a name AND a value?   → use a MAP, use each.key + each.value
```

---

## PART 3 — `for_each` with Complex Objects (Multiple Fields Per Item)

### Step 1: When Even a Map Isn't Enough

Sometimes each item needs THREE, FOUR, or more pieces of
information — not just one key and one value.

**Real example:** Creating firewall rules where each rule needs
a name, a priority, and an action.

### Step 2: The `map(object({...}))` Type

```hcl
variable "firewall_rules" {
  type = map(object({
    priority = number
    action   = string
    port     = number
  }))
}
```

Read this out loud slowly: *"firewall_rules is a MAP. Each value
in that map is an OBJECT. Each object has three fields: priority
(a number), action (a string), and port (a number)."*

```hcl
# terraform.tfvars
firewall_rules = {
  "allow-ssh" = {
    priority = 100
    action   = "Allow"
    port     = 22
  }
  "allow-https" = {
    priority = 110
    action   = "Allow"
    port     = 443
  }
  "deny-all" = {
    priority = 4096
    action   = "Deny"
    port     = 0
  }
}
```

### Step 3: Using It in a Resource

```hcl
resource "azurerm_network_security_rule" "rules" {
  for_each  = var.firewall_rules
  name      = each.key                    # "allow-ssh", "allow-https", "deny-all"
  priority  = each.value.priority         # 100, 110, 4096
  access    = each.value.action           # "Allow", "Allow", "Deny"
  dest_port = each.value.port             # 22, 443, 0
}
```

Notice: `each.key` still gives you the map key (the rule name).
But now `each.value` is not a simple string — it is a whole
object, so you reach INTO it using dots: `each.value.priority`,
`each.value.action`, `each.value.port`.

### Step 4: The Mental Model to Hold Onto

```
each.value                  → the WHOLE object for this iteration
each.value.priority         → ONE FIELD inside that object
each.value.action           → ANOTHER FIELD inside that object
```

Think of `each.value` as a small filing cabinet, and each field
name (`.priority`, `.action`, `.port`) as a labeled drawer inside
that cabinet. You open the cabinet (`each.value`), then pick the
drawer you want (`.priority`).

---

## PART 4 — `dynamic` Blocks (The Concept That Trips Everyone Up)

### Step 1: Why `for_each` on a Resource Isn't Always Enough

Everything so far has used `for_each` to create MULTIPLE
SEPARATE RESOURCES. But sometimes you don't want multiple
resources — you want ONE resource that has multiple REPEATED
SECTIONS inside it.

**Real example:** One Network Security Group needs 3 different
rules inside it. You don't want 3 separate NSGs — you want
1 NSG with 3 rule blocks inside it.

### Step 2: The Problem, Illustrated

Compare these two completely different situations:

```
SITUATION A — for_each on a resource:
"I need 3 separate storage containers"
  → 3 independent Azure resources
  → each shows up separately in terraform plan
  → each can be destroyed independently

SITUATION B — dynamic block:
"I need 1 Network Security Group with 3 rules inside it"
  → 1 single Azure resource
  → the 3 rules are just configuration WITHIN that one resource
  → you cannot destroy "just one rule" without touching the NSG
```

This is the fundamental distinction. `for_each` on a resource
answers "how many resources." `dynamic` answers "how many
repeated sections inside one resource."

### Step 3: The Old (Bad) Way — Without `dynamic`

```hcl
resource "azurerm_network_security_group" "nsg" {
  name                = "my-nsg"
  location            = "East US"
  resource_group_name = "my-rg"

  security_rule {
    name                    = "allow-ssh"
    priority                = 100
    direction               = "Inbound"
    access                  = "Allow"
    protocol                = "Tcp"
    destination_port_range  = "22"
  }

  security_rule {
    name                    = "allow-https"
    priority                = 110
    direction               = "Inbound"
    access                  = "Allow"
    protocol                = "Tcp"
    destination_port_range  = "443"
  }

  security_rule {
    name                    = "deny-all"
    priority                = 4096
    direction               = "Inbound"
    access                  = "Deny"
    protocol                = "*"
    destination_port_range  = "*"
  }
}
```

This works. But look at the repetition. Every `security_rule`
block has the same structure with different values. This is
exactly the pattern `dynamic` was built to eliminate.

### Step 4: The Same Thing, With `dynamic`

```hcl
resource "azurerm_network_security_group" "nsg" {
  name                = "my-nsg"
  location            = "East US"
  resource_group_name = "my-rg"

  dynamic "security_rule" {
    for_each = var.firewall_rules    # the map(object) from Part 3

    content {
      name                    = security_rule.key
      priority                = security_rule.value.priority
      direction               = "Inbound"
      access                  = security_rule.value.action
      protocol                = "Tcp"
      destination_port_range  = tostring(security_rule.value.port)
    }
  }
}
```

One `dynamic` block. Terraform generates 3 `security_rule`
sections inside the ONE NSG resource, using your
`var.firewall_rules` map from Part 3.

---

### Step 5: Breaking Down Every Piece of the `dynamic` Block

```hcl
dynamic "security_rule" {
```
The word `dynamic` tells Terraform: *"I am about to generate
multiple copies of a block."* The word in quotes —
`"security_rule"` — must exactly match the name of the real
block type that this resource normally accepts. You are not
inventing a new name; you are telling Terraform which repeated
block type to generate multiples of.

```hcl
  for_each = var.firewall_rules
```
Exactly the same `for_each` syntax you already know from Part 1-3.
It can be a set, a map, or a map of objects. The rules are identical
to resource-level `for_each` — only WHERE it's used is different.

```hcl
  content {
```
This is new. Every `dynamic` block MUST contain a `content {}`
block. This defines what each generated `security_rule` block
should actually contain. Without `content {}`, Terraform will
throw an error — it doesn't know what to put inside each
generated block.

```hcl
    name = security_rule.key
```
Here is the part that confuses almost everyone the first time.
Inside `content {}`, you do NOT use `each.key`. You use
`security_rule.key` — matching the LABEL you gave the `dynamic`
block at the very top (`dynamic "security_rule"`).

```
dynamic "security_rule" { ... }     ← label is "security_rule"
                                      ↓
content {
  name = security_rule.key          ← must match the label exactly
}
```

If you named your dynamic block `dynamic "my_rule"` instead,
you would need to write `my_rule.key` inside `content {}` —
not `each.key`, and not `security_rule.key` either.

---

### Step 6: Why Does It Work This Way? (The Reasoning)

This design exists because you can have MULTIPLE `dynamic`
blocks inside the same resource. If they all used the generic
name `each`, Terraform would have no way to know which `each`
belongs to which loop.

**Example — two dynamic blocks in the same resource:**

```hcl
resource "azurerm_network_security_group" "nsg" {
  # ... other config ...

  dynamic "security_rule" {
    for_each = var.inbound_rules
    content {
      name = security_rule.key       # refers to inbound_rules
      # ...
    }
  }

  dynamic "some_other_block" {
    for_each = var.other_config
    content {
      name = some_other_block.key    # refers to other_config
      # ...
    }
  }
}
```

Each `dynamic` block's `content {}` refers back to its OWN
label. This is why the label matters — it disambiguates between
multiple loops happening in the same resource.

---

## PART 5 — Side-by-Side Comparison Table (Your Cheat Sheet)

| | `for_each` on a Resource | `dynamic` Block |
|---|---|---|
| **What it creates** | Multiple separate resources | Multiple nested blocks in ONE resource |
| **Shows up in `terraform plan` as** | `resource_type.label["key"]` (separate entries) | One resource, with repeated sections inside |
| **Can destroy one independently?** | Yes — remove from the map/set, only that resource is destroyed | No — it's all part of one resource's state |
| **Iterator syntax** | `each.key` / `each.value` | `<dynamic_label>.key` / `<dynamic_label>.value` |
| **Requires** | `for_each = ...` directly on the resource | `dynamic "block_name" { for_each = ... content { } }` |
| **When to use** | You need N separate Azure resources | One resource needs N repeated config sections |

---

## PART 6 — A Complete Worked Example Combining Everything

Let's build one realistic example using every concept in this
guide, so you can see them work together.

**Scenario:** You need 2 separate storage accounts (for_each on
a resource), and EACH storage account needs a Network Security
Group with multiple firewall rules inside it (dynamic block).

```hcl
# ── Variables ──────────────────────────────────────────────────

variable "storage_accounts" {
  type = map(object({
    location = string
    tier     = string
  }))
}

variable "firewall_rules" {
  type = map(object({
    priority = number
    action   = string
    port     = number
  }))
}
```

```hcl
# ── terraform.tfvars ─────────────────────────────────────────

storage_accounts = {
  "logs-storage" = {
    location = "East US"
    tier     = "Standard"
  }
  "backup-storage" = {
    location = "West US"
    tier     = "Standard"
  }
}

firewall_rules = {
  "allow-ssh" = {
    priority = 100
    action   = "Allow"
    port     = 22
  }
  "allow-https" = {
    priority = 110
    action   = "Allow"
    port     = 443
  }
}
```

```hcl
# ── main.tf ──────────────────────────────────────────────────

# STEP 1: for_each on a RESOURCE — creates 2 separate storage accounts
resource "azurerm_storage_account" "accounts" {
  for_each                 = var.storage_accounts
  name                     = each.key                    # "logs-storage", "backup-storage"
  location                 = each.value.location          # from the object
  account_tier              = each.value.tier              # from the object
  resource_group_name      = azurerm_resource_group.rg.name
  account_replication_type = "LRS"
}

# STEP 2: dynamic block — EACH nsg gets multiple rules inside it
resource "azurerm_network_security_group" "nsgs" {
  for_each             = var.storage_accounts    # one NSG per storage account
  name                 = "${each.key}-nsg"
  location             = each.value.location
  resource_group_name  = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.firewall_rules      # every NSG gets the SAME set of rules

    content {
      name                    = security_rule.key
      priority                = security_rule.value.priority
      direction               = "Inbound"
      access                  = security_rule.value.action
      protocol                = "Tcp"
      destination_port_range  = tostring(security_rule.value.port)
      source_port_range       = "*"
      source_address_prefix   = "*"
      destination_address_prefix = "*"
    }
  }
}
```

**What Terraform actually creates:**
```
2 Storage Accounts:
  azurerm_storage_account.accounts["logs-storage"]
  azurerm_storage_account.accounts["backup-storage"]

2 Network Security Groups (from for_each):
  azurerm_network_security_group.nsgs["logs-storage"]
  azurerm_network_security_group.nsgs["backup-storage"]

Each NSG has 2 rules INSIDE it (from dynamic):
  logs-storage-nsg   → rules: allow-ssh, allow-https
  backup-storage-nsg → rules: allow-ssh, allow-https
```

This is `for_each` and `dynamic` working together — one creating
resources, the other creating repeated config within each resource.

---

## PART 7 — Common Mistakes (And Why They Happen)

### Mistake 1: Using `each.key` Inside a `dynamic` Block

```hcl
# WRONG
dynamic "security_rule" {
  for_each = var.firewall_rules
  content {
    name = each.key    # ← WRONG, should be security_rule.key
  }
}
```

**Why this happens:** You already know `each.key` from resource-level
`for_each`, so your fingers type it out of habit. Inside a `dynamic`
block, the iterator is always named after the dynamic block's label —
never the generic word `each`.

---

### Mistake 2: Passing a List Instead of a Set or Map

```hcl
# WRONG
for_each = ["logs", "backups", "uploads"]    # this is a LIST

# CORRECT
for_each = toset(["logs", "backups", "uploads"])   # converted to a SET
```

**Why this happens:** Lists feel like the natural choice because
they're the simplest collection type. But `for_each` specifically
needs a set or map because it uses the VALUES as unique tracking
keys — a list allows duplicates and has an order, which conflicts
with how Terraform tracks each resource independently.

---

### Mistake 3: Forgetting `content {}` Inside a `dynamic` Block

```hcl
# WRONG — missing content block
dynamic "security_rule" {
  for_each = var.firewall_rules
  name     = security_rule.key    # this is not valid here
}

# CORRECT
dynamic "security_rule" {
  for_each = var.firewall_rules
  content {
    name = security_rule.key      # must be inside content {}
  }
}
```

**Why this happens:** With resource-level `for_each`, you put
arguments directly in the resource body. With `dynamic`, everything
must be wrapped inside `content {}` — this extra layer is easy to
forget because it feels redundant at first.

---

### Mistake 4: Mismatched Type Between Variable and tfvars

```hcl
# variables.tf says:
variable "metric_alerts" {
  type = map(object({
    severity = number
  }))
}

# terraform.tfvars has a typo — severity as a STRING not a number:
metric_alerts = {
  "high-cpu" = {
    severity = "2"    # ← WRONG, should be 2 (no quotes)
  }
}
```

**Why this happens:** Numbers and strings look almost identical
in casual reading. Terraform is strict about types — if you
declared `number`, quoting the value turns it into a string and
causes a type mismatch error at `terraform plan`.

---

## PART 8 — Practice Exercises (Do These Before Moving On)

Try these on paper or in a scratch `.tf` file before your next
real project. Answers are below — but attempt them first.

### Exercise 1
You need to create 4 Azure regions' worth of resource groups:
`"eastus"`, `"westus"`, `"northeurope"`, `"southeastasia"`.
Each just needs a name — no other differing values.

**Question:** Set, map, or map(object)? Write the `for_each` line.

### Exercise 2
You need 3 Key Vault secrets. Each secret has a different NAME
and a different VALUE.

**Question:** Set, map, or map(object)? Write the variable
declaration and one example `terraform.tfvars` entry.

### Exercise 3
You need ONE storage account that has 5 different lifecycle
management rules inside it (a nested block type, similar to
`security_rule`). Each rule has a name, a number of days, and
an action.

**Question:** `for_each` on the resource, or `dynamic` block?
Why?

---

### Answers

**Exercise 1:**
```hcl
for_each = toset(["eastus", "westus", "northeurope", "southeastasia"])
# Use each.value for the name — a SET is correct because
# each item only needs ONE piece of information (its name).
```

**Exercise 2:**
```hcl
variable "kv_secrets" {
  type = map(string)
}

# terraform.tfvars
kv_secrets = {
  "db-password"  = "SuperSecret123!"
  "api-key"      = "abc123xyz789"
  "jwt-secret"   = "myjwtsecretvalue"
}
# A MAP is correct — each item needs a name (key) AND a value.
```

**Exercise 3:**
```
dynamic block — because you need ONE storage account resource
with 5 repeated lifecycle rule SECTIONS inside it, not 5 separate
storage accounts. This is exactly the NSG + security_rule pattern
from Part 4.
```

---

## Quick Reference Card — Keep This Nearby

```
┌─────────────────────────────────────────────────────────────┐
│  DECISION TREE                                               │
│                                                               │
│  Do you need multiple SEPARATE resources?                    │
│    YES → use for_each on the resource                        │
│    NO, I need multiple SECTIONS inside ONE resource           │
│      → use a dynamic block                                   │
│                                                               │
│  Does each item need ONLY a name?                             │
│    YES → use a set:  toset([...])                            │
│    NO, it needs a name AND a value                            │
│      → use a map:  { "key" = "value" }                        │
│  Does each item need MULTIPLE fields (name + several values)? │
│      → use map(object({ field1 = type, field2 = type }))     │
│                                                               │
│  Inside for_each on a resource:                               │
│    each.key    → the map key (or same as value, for a set)   │
│    each.value  → the map value (or same as key, for a set)   │
│                                                               │
│  Inside a dynamic block's content {}:                         │
│    <label>.key    → NOT each.key                              │
│    <label>.value  → NOT each.value                            │
│    <label> = whatever you named the dynamic block             │
└─────────────────────────────────────────────────────────────┘
```

---

*This guide is a standalone reference — revisit it any time
`for_each` or `dynamic` feel unclear again. Mastery comes from
using these patterns repeatedly across different resources,
not from reading once.*
