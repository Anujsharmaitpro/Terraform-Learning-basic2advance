# Terraform Type Constraints — Every Data Type Explained
## Deep-Dive Learning Guide — Day 7 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure VM Examples | PowerShell Commands Throughout

---

## Before You Start

This is Day 7. By now you know:
- Day 1: What Terraform is and why it exists
- Day 2: Providers and version constraints
- Day 3: Resources, dependencies, authentication
- Day 4: State file and remote backends
- Day 5: Input, output, and local variables
- Day 6: Professional file structure

Today is about **type constraints** — the rules that define what KIND
of value a variable can hold. You have already used `string` many times.
Now you will learn ALL seven types, when each one is appropriate, and
exactly how to use them in real Azure infrastructure code.

---

## Table of Contents

1. What Is a Type Constraint and Why Does It Matter?
2. The Complete Type System — Map of All Types
3. PRIMITIVE Type 1 — `string`
4. PRIMITIVE Type 2 — `number`
5. PRIMITIVE Type 3 — `bool`
6. COMPLEX Type 4 — `list`
7. COMPLEX Type 5 — `set`
8. COMPLEX Type 6 — `map`
9. COMPLEX Type 7 — `object`
10. COMPLEX Type 8 — `tuple`
11. The `any` Type — When to Use It and When Not To
12. How to Access Values from Each Type
13. The Azure VM Demo — All Types in One Real Example
14. The Complete Working Code — All Files
15. Reading Terraform Documentation for Resource Arguments
16. Common Mistakes for Each Type
17. Practice Exercises
18. Complete Cheat Sheet

---

## 1. What Is a Type Constraint and Why Does It Matter?

### The plain English definition

A **type constraint** tells Terraform: "This variable must hold THIS kind
of value — and nothing else."

Without type constraints:

```hcl
variable "disk_size" {}   # No type — accepts anything

# Someone passes:
disk_size = "eighty"      # String — valid per Terraform, fails in Azure
disk_size = true          # Boolean — valid per Terraform, fails in Azure
disk_size = 80            # Number — this is what Azure needs
```

With type constraint:

```hcl
variable "disk_size" {
  type = number           # Only numbers allowed
}

# Someone passes:
disk_size = "eighty"      # ❌ Terraform rejects immediately — clear error
disk_size = true          # ❌ Terraform rejects immediately — clear error
disk_size = 80            # ✅ Accepted — correct type
```

Type constraints catch mistakes early — before Terraform even contacts
Azure — with a clear, specific error message.

### The two categories

```
PRIMITIVE types — hold ONE single value
  string  → text:    "West Europe"
  number  → numeric: 80
  bool    → binary:  true / false

COMPLEX types — hold MULTIPLE values (collections)
  list    → ordered sequence, duplicates allowed
  set     → unordered, unique values only
  map     → key → value pairs
  object  → named attributes with defined types
  tuple   → ordered sequence of MIXED types
```

---

## 2. The Complete Type System — Map of All Types

```
ALL TERRAFORM TYPES
│
├── PRIMITIVE (single value)
│   ├── string    "text"          → for names, locations, descriptions
│   ├── number    42 or 3.14      → for sizes, counts, ports
│   └── bool      true / false    → for on/off switches, feature flags
│
└── COMPLEX (collection of values)
    ├── list(type)   ["a","b","c"]      → ordered, duplicates OK
    ├── set(type)    {"a","b","c"}      → unordered, UNIQUE only
    ├── map(type)    {k="v", k2="v2"}  → key-value pairs
    ├── object({})   {name=string,...} → named fields with specific types
    └── tuple([])    [string,number]   → mixed types, fixed structure
```

### The `any` catch-all

```
any    → accepts any type — use sparingly
```

---

## 3. PRIMITIVE Type 1 — `string`

### What it is

A string is any piece of text wrapped in double quotes. It is the most
common type in Terraform and the default when no type is specified.

### When to use it

- Resource names: `"my-resource-group"`
- Azure region names: `"West Europe"`, `"East US"`
- Environment names: `"dev"`, `"staging"`, `"production"`
- Any configuration that is text

### Syntax

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "staging"
}
```

### Using it in an Azure resource

```hcl
resource "azurerm_resource_group" "example" {
  name     = "${var.environment}-resources"   # string interpolation
  location = "West Europe"
}
```

### String interpolation

You can embed variables inside strings using `${ }`:

```hcl
name = "${var.environment}-vm"
# If environment = "staging" → name = "staging-vm"

name = "${var.project}-${var.environment}-rg"
# If project = "bankapp", environment = "prod" → "bankapp-prod-rg"
```

### Type validation in action

```hcl
variable "environment" {
  type = string
}

# ✅ Valid
environment = "staging"

# ❌ Invalid — Terraform errors immediately
environment = 42
environment = true
```

---

## 4. PRIMITIVE Type 2 — `number`

### What it is

A number holds any numeric value — integers (whole numbers) or decimals.
No quotes around it.

### When to use it

- Disk size in GB: `80`
- VM count: `3`
- Port numbers: `443`
- Timeout in seconds: `300`
- Any configuration that is a quantity

### Syntax

```hcl
variable "storage_disk" {
  type        = number
  description = "Size of the OS disk in GB"
  default     = 80
}
```

### Using it in an Azure VM resource

```hcl
resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-${var.environment}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_DS1_v2"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.storage_disk    # ← number variable
  }
  # ...
}
```

### Why the instructor used number here

The `disk_size_gb` field in Azure expects a number — not the string `"80"`.
If you write `"80"` (with quotes), it's a string. Terraform might accept
it (coercing it), but it's cleaner and safer to use the correct type.

### Numbers vs strings — the subtle difference

```hcl
# These look similar but are different types:
disk_size_gb = 80       # number — correct
disk_size_gb = "80"     # string — may cause issues

# Terraform can sometimes coerce string "80" to number 80
# but this is not reliable for all providers and fields
# Always use the correct type
```

---

## 5. PRIMITIVE Type 3 — `bool`

### What it is

A boolean holds exactly one of two values: `true` or `false`. No quotes.
It is an on/off switch.

### When to use it

- Delete disk on VM termination: `true` / `false`
- Enable public IP: `true` / `false`
- Enable HTTPS only: `true` / `false`
- Enable monitoring: `true` / `false`
- Any configuration that is a yes/no decision

### Syntax

```hcl
variable "is_delete" {
  type        = bool
  description = "Default behaviour to delete OS disk upon VM termination"
  default     = true
}
```

### Using it in an Azure VM resource

```hcl
resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-${var.environment}"
  # ...

  delete_os_disk_on_termination = var.is_delete    # ← bool variable
}
```

### The instructor's warning about this field

When `delete_os_disk_on_termination = true`, deleting the VM also
permanently deletes its disk. For VMs with critical data, set this to
`false` to keep the disk for recovery.

```hcl
# Production VM with important data — keep the disk
variable "is_delete" {
  type    = bool
  default = false    # ← disk survives VM deletion
}

# Dev VM — clean up everything on deletion
variable "is_delete" {
  type    = bool
  default = true     # ← disk deleted with VM (saves storage cost)
}
```

### Bool values must NOT have quotes

```hcl
# ✅ Correct
delete_os_disk_on_termination = true
delete_os_disk_on_termination = false

# ❌ Wrong — these are strings, not booleans
delete_os_disk_on_termination = "true"
delete_os_disk_on_termination = "false"
```

---

## 6. COMPLEX Type 4 — `list`

### What it is

A list is an **ordered collection** of values, all of the same type.
Think of it as a numbered sequence — item 0, item 1, item 2, and so on.
Lists CAN have duplicate values.

### The structure

```hcl
["West Europe", "North Europe", "East US"]
#  index [0]       index [1]     index [2]
```

Items are accessed by their **index number**, starting at 0 (zero-based indexing).

### When to use it

- A list of allowed Azure locations
- A list of allowed VM sizes
- A sequence of availability zones
- Any ordered collection where position matters

### Syntax

```hcl
variable "allowed_locations" {
  type        = list(string)
  description = "List of allowed Azure regions for deployment"
  default     = ["West Europe", "North Europe", "East US"]
}
```

Note the format: `list(string)` — list OF string. You specify what TYPE
the list items are.

Other list types:
```hcl
type = list(string)    # list of text values
type = list(number)    # list of numbers
type = list(bool)      # list of booleans
```

### Accessing items from a list — index notation

```hcl
var.allowed_locations[0]    # "West Europe"  ← first item (index 0)
var.allowed_locations[1]    # "North Europe" ← second item (index 1)
var.allowed_locations[2]    # "East US"      ← third item (index 2)
```

### Using it in an Azure resource

```hcl
variable "allowed_locations" {
  type    = list(string)
  default = ["West Europe", "North Europe", "East US"]
}

resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = var.allowed_locations[0]    # "West Europe"
}

resource "azurerm_linux_virtual_machine" "example" {
  name     = "vm-example"
  location = var.allowed_locations[2]    # "East US"
  # ...
}
```

### The instructor's index experiment

The instructor tried `var.allowed_locations[-1]` (which works in Python
to get the last element). Terraform rejected it:

```
Error: Invalid index
The given key does not identify an element in this collection value:
a negative number is not valid index.
```

In Terraform, you must use explicit positive indexes. To get the last
element, you can use the `length()` function:

```hcl
# Get the last element
var.allowed_locations[length(var.allowed_locations) - 1]
# length(["West Europe","North Europe","East US"]) = 3
# 3 - 1 = 2 → index 2 = "East US"
```

### List vs Set — the key difference (preview)

```
list → ordered, duplicates allowed, accessed by index [0], [1], [2]
set  → unordered, NO duplicates, cannot access by index
```

---

## 7. COMPLEX Type 5 — `set`

### What it is

A set is like a list but with two important differences:
1. **No duplicates** — every value must be unique
2. **No ordering** — items have no index number, no guaranteed order

### When to use it

- A set of ALLOWED values (for validation)
- A collection where you need to guarantee uniqueness
- Converting to use with `for_each` on resources
- A pool of valid VM sizes where duplicates would be nonsensical

### Syntax

```hcl
variable "allowed_vm_sizes" {
  type        = set(string)
  description = "Set of approved VM sizes (unique values only)"
  default     = ["Standard_DS1_v2", "Standard_DS2_v2", "Standard_DS3_v2"]
}
```

### The critical limitation — you cannot access by index

This is what the instructor discovered during the demo:

```hcl
# ❌ This FAILS — sets have no index
var.allowed_vm_sizes[0]       # Error: element of a set has no index
var.allowed_vm_sizes["first"] # Error: sets use no keys

# The error you see:
# Error: Invalid index
# Elements of a set are identified only by their values and don't
# have any separate index or ordinal key to select with.
```

### So how DO you use a set?

Sets are used differently from lists. The instructor explained that sets
are primarily used for:

**Use case 1: With `for_each` to create multiple resources**
```hcl
resource "azurerm_resource_group" "envs" {
  for_each = toset(["dev", "staging", "prod"])
  name     = "rg-${each.key}"
  location = "West Europe"
}
# Creates three resource groups, one per unique value
```

**Use case 2: Validation — checking if a value is in the set**
```hcl
variable "vm_size" {
  type = string
  validation {
    condition = contains(
      toset(["Standard_DS1_v2", "Standard_DS2_v2"]),
      var.vm_size
    )
    error_message = "VM size must be Standard_DS1_v2 or Standard_DS2_v2."
  }
}
```

**Use case 3: Converting a list to remove duplicates**
```hcl
locals {
  unique_locations = toset(["East US", "West Europe", "East US"])
  # Result: {"East US", "West Europe"}  ← duplicate "East US" removed
}
```

### What the instructor concluded

Sets are NOT for accessing individual elements like a list. They are
for iteration (for_each), validation, and uniqueness enforcement. The
instructor rightfully noted this belongs to a lifecycle/validation topic
and converted the variable back to a list for the demo.

---

## 8. COMPLEX Type 6 — `map`

### What it is

A map is a collection of **key-value pairs**. Each key is a string, and
each value is the same specified type. It's like a dictionary or a lookup
table — you look up a value BY its name (key), not by a number index.

### When to use it

- Resource tags (key=tag name, value=tag value)
- Environment-specific configuration (key=env name, value=config)
- A lookup table of settings
- Any key-value configuration data

### Syntax

```hcl
variable "resource_tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default = {
    environment  = "staging"
    managed_by   = "terraform"
    department   = "devops"
  }
}
```

Note: `map(string)` means a map where all VALUES are strings. The keys
are always strings in Terraform maps.

### Accessing map values — key notation

```hcl
var.resource_tags["environment"]   # "staging"
var.resource_tags["managed_by"]    # "terraform"
var.resource_tags["department"]    # "devops"
```

### Using it in Azure resources — two patterns

**Pattern 1: Reference individual keys**

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "West Europe"
  tags = {
    Environment = var.resource_tags["environment"]   # "staging"
    ManagedBy   = var.resource_tags["managed_by"]    # "terraform"
    Department  = var.resource_tags["department"]    # "devops"
  }
}
```

**Pattern 2: Use the whole map directly as tags**

When the map structure matches what the resource expects (like `tags`
which also takes key-value pairs), you can pass the whole map:

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "West Europe"
  tags     = var.resource_tags    # ← pass entire map directly
}
```

### The error the instructor hit

He tried `var.resource_tags.environment` (dot notation) and got:

```
Error: The reference to resource must be followed by at least one
attribute access, specifying the resource name.
```

For maps, use bracket notation with the key in DOUBLE QUOTES:
```hcl
var.resource_tags["environment"]    # ✅ correct bracket notation
var.resource_tags.environment       # ❌ dot notation doesn't work for map lookups
```

### Map of string vs Map of number

```hcl
# Map where values are strings
variable "env_names" {
  type = map(string)
  default = {
    dev  = "Development"
    prod = "Production"
  }
}

# Map where values are numbers (e.g., port numbers per environment)
variable "app_ports" {
  type = map(number)
  default = {
    http  = 80
    https = 443
    ssh   = 22
  }
}
# Access: var.app_ports["https"] → 443
```

---

## 9. COMPLEX Type 7 — `object`

### What it is

An object is like a map but EACH field (key) can have its OWN specified
type. While a map requires all values to be the same type, an object
lets different keys hold different types.

Think of it like a structured configuration block where:
- `name` is a string
- `size` is a string
- `disk_size_gb` is a number
- `enabled` is a bool

All different types — all in one variable.

### When to use it

- VM configuration (size + image + disk all together)
- Network configuration (address + subnet mask + port)
- Any grouped configuration where fields have mixed types

### Syntax

```hcl
variable "vm_config" {
  type = object({
    size      = string
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "Virtual machine configuration including image details"
  default = {
    size      = "Standard_DS1_v2"
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
```

### Accessing object fields — dot notation

With objects, dot notation DOES work (unlike maps):

```hcl
var.vm_config.size        # "Standard_DS1_v2"
var.vm_config.publisher   # "Canonical"
var.vm_config.offer       # "UbuntuServer"
var.vm_config.sku         # "18.04-LTS"
var.vm_config.version     # "latest"
```

### Using it in an Azure VM resource

```hcl
resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-${var.environment}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = var.vm_config.size            # ← object field

  source_image_reference {
    publisher = var.vm_config.publisher               # ← object field
    offer     = var.vm_config.offer                   # ← object field
    sku       = var.vm_config.sku                     # ← object field
    version   = var.vm_config.version                 # ← object field
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_username = "adminuser"
  admin_password = "Password1234!"
}
```

### Map vs Object — the key distinction

```
map(string):
  ALL values must be the same type (all strings)
  Fields don't have predefined names
  Used for tags, lookups, arbitrary key-value data

object({ name=type, ... }):
  EACH field can have a DIFFERENT type
  Fields have predefined, known names
  Used for structured configuration groups
```

---

## 10. COMPLEX Type 8 — `tuple`

### What it is

A tuple is an **ordered, fixed-length sequence of values where each
position can have a different type**. Like a list, it uses index numbers.
Unlike a list, the type of each position is fixed and can differ.

Think of a tuple as "a small, structured row of data" — position 0 is
always a string, position 1 is always a string, position 2 is always a number.

### When to use it

- Network configuration (IP address string + subnet string + mask number)
- Any fixed-structure sequence of mixed-type values
- When you want to group a small, related set of differently-typed values

### Syntax

```hcl
variable "network_config" {
  type = tuple([string, string, number])
  # position 0 → string (VNet address CIDR range)
  # position 1 → string (subnet address)
  # position 2 → number (subnet mask)

  description = "Network configuration: [vnet_cidr, subnet_address, subnet_mask]"
  default     = ["10.0.0.0/16", "10.0.1.0", 24]
}
```

### Accessing tuple elements — `element()` function

Unlike lists which use `var.name[index]`, the instructor found that tuples
in the context of resource attributes need the `element()` function:

```hcl
# element(tuple_variable, index)
element(var.network_config, 0)    # "10.0.0.0/16"
element(var.network_config, 1)    # "10.0.1.0"
element(var.network_config, 2)    # 24
```

### Using it in Azure VNet and Subnet resources

```hcl
variable "network_config" {
  type    = tuple([string, string, number])
  default = ["10.0.0.0/16", "10.0.1.0", 24]
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-${var.environment}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [element(var.network_config, 0)]   # ["10.0.0.0/16"]
  # Note: address_space expects a list, so wrap in [ ]
}

resource "azurerm_subnet" "example" {
  name                 = "subnet-${var.environment}"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name

  # Combine subnet address and mask into CIDR notation
  address_prefixes = [
    "${element(var.network_config, 1)}/${element(var.network_config, 2)}"
  ]
  # Results in: ["10.0.1.0/24"]
}
```

### The instructor's string concatenation with tuple elements

To combine the subnet address and mask into proper CIDR notation like
`"10.0.1.0/24"`, the instructor used string interpolation:

```hcl
"${element(var.network_config, 1)}/${element(var.network_config, 2)}"
# "${10.0.1.0}/${24}"
# = "10.0.1.0/24"
```

This requires:
1. Dollar sign + curly braces around each `element()` call
2. A literal `/` between them
3. The whole expression inside double quotes

### Tuple vs List — the key distinction

```
list(string):
  All elements must be the SAME type
  Any length — can have as many items as you want
  Used when you have a variable number of same-type values

tuple([string, string, number]):
  Elements can be DIFFERENT types
  FIXED length — exactly the declared number of elements
  Used for small, structured groups of mixed-type values
```

---

## 11. The `any` Type — When to Use It and When Not To

### What it is

`any` is the catch-all type. A variable with `type = any` accepts any
value — string, number, list, map, anything.

```hcl
variable "flexible_config" {
  type    = any
  default = "staging"   # could be a string
  # or: default = 80    # could be a number
  # or: default = ["a"] # could be a list
}
```

### When it's acceptable

- When writing generic modules that must accept multiple types
- During rapid prototyping when you haven't decided on the exact type
- When the type genuinely varies based on context

### When NOT to use it (most of the time)

```hcl
# ❌ Too loose — no validation, easy to pass wrong values
variable "environment" {
  type    = any
  default = "staging"
}

# ✅ Better — clear expectation, catches mistakes early
variable "environment" {
  type    = string
  default = "staging"
}
```

The instructor's recommendation (implied throughout the video): always
specify the correct type. Use `any` only when you genuinely need it.

---

## 12. How to Access Values from Each Type

This is the most practical reference — how you retrieve a value from
each variable type:

```
TYPE         | ACCESS SYNTAX                        | EXAMPLE RESULT
─────────────┼──────────────────────────────────────┼─────────────────────
string       | var.name                             | "staging"
number       | var.name                             | 80
bool         | var.name                             | true
─────────────┼──────────────────────────────────────┼─────────────────────
list         | var.name[index]                      | var.locs[0] = "West"
             | element(var.name, index)             | element(var.locs, 0)
─────────────┼──────────────────────────────────────┼─────────────────────
set          | Cannot access individual elements    | Use for_each or
             | Use tolist(var.name)[index] if order | contains() instead
             | doesn't matter                       |
─────────────┼──────────────────────────────────────┼─────────────────────
map          | var.name["key"]                      | var.tags["env"]
             | (NOT var.name.key — use brackets)    |
─────────────┼──────────────────────────────────────┼─────────────────────
object       | var.name.field                       | var.vm.size
             | (dot notation works for objects)     |
─────────────┼──────────────────────────────────────┼─────────────────────
tuple        | element(var.name, index)             | element(var.net, 0)
             | or var.name[index] (for simple types)|
```

---

## 13. The Azure VM Demo — All Types in One Real Example

The instructor used an Azure Virtual Machine as the teaching resource
because VMs require many different configuration fields — perfect for
demonstrating all type constraints in one real scenario.

### What a VM needs and which type satisfies each need

```
VM Configuration Requirement        Type Used     Variable Name
─────────────────────────────────────────────────────────────────────
Environment name (dev/staging/prod) string        var.environment
OS disk size in GB                  number        var.storage_disk
Delete disk on termination          bool          var.is_delete
List of allowed Azure locations     list(string)  var.allowed_locations
Set of approved VM sizes            set(string)   var.allowed_vm_sizes
Resource tags (key-value pairs)     map(string)   var.resource_tags
VM image + size configuration       object({})    var.vm_config
Network address configuration       tuple([])     var.network_config
```

This is realistic — a production VM deployment touches all these types.

---

## 14. The Complete Working Code — All Files

Here is the full, clean code demonstrating all type constraints:

**`variables.tf`** — all variable type constraints

```hcl
# ── PRIMITIVE TYPES ────────────────────────────────────────────────

# Type: string — environment name
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "staging"
}

# Type: number — OS disk size
variable "storage_disk" {
  type        = number
  description = "Size of the OS disk in GB"
  default     = 80
}

# Type: bool — disk deletion behaviour on VM termination
variable "is_delete" {
  type        = bool
  description = "Delete OS disk automatically upon VM termination"
  default     = true
  # WARNING: set to false for production VMs with important data
}

# ── COMPLEX TYPES ──────────────────────────────────────────────────

# Type: list(string) — ordered, duplicates allowed, indexed from 0
variable "allowed_locations" {
  type        = list(string)
  description = "Ordered list of allowed Azure regions"
  default     = ["West Europe", "North Europe", "East US"]
  # Access: var.allowed_locations[0] = "West Europe"
  #         var.allowed_locations[1] = "North Europe"
  #         var.allowed_locations[2] = "East US"
}

# Type: set(string) — unordered, unique values only
# NOTE: Cannot be accessed by index — use for_each or contains()
variable "allowed_vm_sizes" {
  type        = list(string)    # Using list here for direct access
  description = "Approved VM sizes"
  default     = ["Standard_DS1_v2", "Standard_DS2_v2", "Standard_DS3_v2"]
}

# Type: map(string) — key-value pairs, all values same type
variable "resource_tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default = {
    environment = "staging"
    managed_by  = "terraform"
    department  = "devops"
  }
  # Access: var.resource_tags["environment"] = "staging"
}

# Type: object — named fields with DIFFERENT types per field
variable "vm_config" {
  type = object({
    size      = string
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "VM size and image configuration"
  default = {
    size      = "Standard_DS1_v2"
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  # Access: var.vm_config.size = "Standard_DS1_v2"
  #         var.vm_config.sku  = "18.04-LTS"
}

# Type: tuple — fixed-length, DIFFERENT types per position
variable "network_config" {
  type        = tuple([string, string, number])
  description = "Network config: [vnet_cidr, subnet_address, subnet_mask]"
  default     = ["10.0.0.0/16", "10.0.1.0", 24]
  # Access: element(var.network_config, 0) = "10.0.0.0/16"
  #         element(var.network_config, 1) = "10.0.1.0"
  #         element(var.network_config, 2) = 24
}
```

---

**`resource_group.tf`**

```hcl
resource "azurerm_resource_group" "example" {
  name     = "${var.environment}-resources"          # string variable
  location = var.allowed_locations[0]                # list variable (index 0)
  tags     = var.resource_tags                       # map variable (whole map)
}
```

---

**`virtual_network.tf`**

```hcl
resource "azurerm_virtual_network" "example" {
  name                = "${var.environment}-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [element(var.network_config, 0)]   # tuple index 0
  tags                = var.resource_tags
}
```

---

**`subnet.tf`**

```hcl
resource "azurerm_subnet" "example" {
  name                 = "${var.environment}-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes = [
    "${element(var.network_config, 1)}/${element(var.network_config, 2)}"
    # "10.0.1.0/24"
  ]
}
```

---

**`network_interface.tf`**

```hcl
resource "azurerm_network_interface" "example" {
  name                = "${var.environment}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  tags                = var.resource_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}
```

---

**`virtual_machine.tf`**

```hcl
resource "azurerm_linux_virtual_machine" "example" {
  name                = "${var.environment}-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = var.allowed_vm_sizes[0]      # list variable (index 0)
  tags                = var.resource_tags            # map variable

  admin_username = "adminuser"
  admin_password = "P@ssword1234!"

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.example.id
  ]

  os_disk {
    caching                   = "ReadWrite"
    storage_account_type      = "Standard_LRS"
    disk_size_gb              = var.storage_disk     # number variable
    delete_data_disks_on_termination = var.is_delete # bool variable
  }

  source_image_reference {
    publisher = var.vm_config.publisher              # object field
    offer     = var.vm_config.offer                  # object field
    sku       = var.vm_config.sku                    # object field
    version   = var.vm_config.version                # object field
  }
}
```

---

**`outputs.tf`**

```hcl
output "vm_name" {
  description = "Name of the created virtual machine"
  value       = azurerm_linux_virtual_machine.example.name
}

output "vm_size_used" {
  description = "VM size selected from the allowed_vm_sizes list"
  value       = var.allowed_vm_sizes[0]
}

output "location_used" {
  description = "Azure region selected from allowed_locations"
  value       = azurerm_resource_group.example.location
}

output "network_cidr" {
  description = "VNet address space from network_config tuple"
  value       = element(var.network_config, 0)
}

output "tags_applied" {
  description = "All tags applied to resources"
  value       = var.resource_tags
}
```

---

**`terraform.tfvars`**

```hcl
environment   = "staging"
storage_disk  = 80
is_delete     = true

allowed_locations = ["West Europe", "North Europe", "East US"]

resource_tags = {
  environment = "staging"
  managed_by  = "terraform"
  department  = "devops"
}

vm_config = {
  size      = "Standard_DS1_v2"
  publisher = "Canonical"
  offer     = "UbuntuServer"
  sku       = "18.04-LTS"
  version   = "latest"
}

network_config = ["10.0.0.0/16", "10.0.1.0", 24]

allowed_vm_sizes = ["Standard_DS1_v2", "Standard_DS2_v2", "Standard_DS3_v2"]
```

---

**PowerShell — full workflow:**

```powershell
# Navigate to project folder
Set-Location "day07"

# Set Azure authentication
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# Initialise
terraform init

# Validate all files
terraform validate

# Preview — uses index 0 (West Europe) for location
terraform plan

# Preview — switch to index 1 (North Europe)
# Temporarily override just the location index in variables.tf
# or use a different tfvars file:
terraform plan -var-file="northeurope.tfvars"

# Apply
terraform apply --auto-approve

# Check what was created
terraform output

# Clean up — always destroy after learning exercises
terraform destroy --auto-approve

# Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 15. Reading Terraform Documentation for Resource Arguments

The instructor spent time showing how to navigate the Azure provider docs.
Here is the systematic approach:

### Step 1: Find your resource

```
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
→ Resources → azurerm_linux_virtual_machine
```

### Step 2: Check the Example Usage section

Copy the example as your starting point. It includes only the minimum
required fields.

### Step 3: Read the Argument Reference section

```
Argument Reference
├── Required Arguments (MUST provide these)
│   ├── name          (string) Required.
│   ├── location      (string) Required.
│   └── size          (string) Required.
│
└── Optional Arguments (can add if needed)
    ├── tags          (map of string) Optional.
    ├── zone          (string) Optional.
    └── ...
```

### Step 4: Check nested block arguments

Some arguments are entire blocks (like `os_disk`). Click on them to see
their sub-arguments:

```
os_disk block:
  ├── caching              (string) Required.
  ├── storage_account_type (string) Required.
  ├── disk_size_gb         (number) Optional.  ← number type!
  └── name                 (string) Optional.
```

### Step 5: Check the Attributes Reference section

These are values Azure generates AFTER the resource is created — you
cannot set them, but you CAN reference them in outputs or other resources:

```
Attributes Reference (generated after creation):
  ├── id                         → unique Azure resource path
  ├── private_ip_address         → assigned IP
  └── public_ip_address          → if public IP is configured
```

---

## 16. Common Mistakes for Each Type

### String mistakes

```hcl
# ❌ Missing quotes
name = West Europe    # Error: unexpected token

# ❌ Single quotes (Terraform uses double quotes)
name = 'West Europe'  # Error in HCL

# ✅ Correct
name = "West Europe"
```

---

### Number mistakes

```hcl
# ❌ Number in quotes
disk_size_gb = "80"   # This is a string, not a number

# ✅ Correct
disk_size_gb = 80     # No quotes for numbers
```

---

### Bool mistakes

```hcl
# ❌ Bool in quotes (becomes string "true", not boolean true)
delete_on_termination = "true"

# ✅ Correct
delete_on_termination = true    # No quotes for booleans
```

---

### List mistakes

```hcl
# ❌ Missing square brackets
variable "locations" {
  type    = list(string)
  default = "West Europe"    # Error: needs to be a list
}

# ✅ Correct
variable "locations" {
  type    = list(string)
  default = ["West Europe", "North Europe"]
}

# ❌ Out of bounds index (list has 3 items, index 3 doesn't exist)
var.locations[3]    # Error: index out of range

# ❌ Negative index (not supported in Terraform)
var.locations[-1]   # Error: negative index not valid
```

---

### Map mistakes

```hcl
# ❌ Using dot notation for map access (works for objects, NOT maps)
var.resource_tags.environment    # May error in some contexts

# ✅ Use bracket notation with quoted key for maps
var.resource_tags["environment"]

# ❌ Missing quotes around key
var.resource_tags[environment]   # Error: unquoted key

# ✅ Correct
var.resource_tags["environment"]
```

---

### Object mistakes

```hcl
# ❌ Forgetting a required field in the object
variable "vm_config" {
  type = object({
    size      = string
    publisher = string
    # offer, sku, version are declared in type but missing from default!
  })
  default = {
    size      = "Standard_DS1_v2"
    publisher = "Canonical"
    # Error: offer, sku, version are required by the object type
  }
}

# ✅ All declared fields must have values
default = {
  size      = "Standard_DS1_v2"
  publisher = "Canonical"
  offer     = "UbuntuServer"
  sku       = "18.04-LTS"
  version   = "latest"
}
```

---

### Tuple mistakes

```hcl
# ❌ Wrong number of elements
variable "network_config" {
  type    = tuple([string, string, number])
  default = ["10.0.0.0/16", "10.0.1.0"]    # Missing the number!
}

# ✅ Exact number of elements required
default = ["10.0.0.0/16", "10.0.1.0", 24]  # string, string, number ✓

# ❌ Wrong type at a position
default = ["10.0.0.0/16", "10.0.1.0", "24"]  # "24" is string, not number!

# ✅ Correct types at each position
default = ["10.0.0.0/16", "10.0.1.0", 24]
```

---

## 17. Practice Exercises

### Exercise 1 — Type Identification

For each Azure configuration need below, which type is most appropriate?

```
a) The name of a resource group
b) The number of VM instances to create
c) Whether HTTPS-only is enforced on a storage account
d) A list of availability zones: ["1", "2", "3"]
e) Tags: { env = "prod", team = "platform" }
f) VM image details: size, publisher, offer, sku (all strings)
g) Network info: [vnet_cidr (string), subnet_cidr (string), mask (number)]
h) Unique set of allowed VM sizes
```

**Answers:**
```
a) string
b) number
c) bool
d) list(string)
e) map(string)
f) object({ size=string, publisher=string, offer=string, sku=string })
g) tuple([string, string, number])
h) set(string)
```

---

### Exercise 2 — Write the Variable and Access It

Write a `map(string)` variable for Azure resource tags with keys:
`environment`, `cost_centre`, `owner`. Then write the expression to
access just the `cost_centre` value.

**Answer:**
```hcl
variable "tags" {
  type = map(string)
  default = {
    environment  = "dev"
    cost_centre  = "IT-001"
    owner        = "platform-team"
  }
}

# Access cost_centre:
var.tags["cost_centre"]    # "IT-001"
```

---

### Exercise 3 — Fix the Type Errors

```hcl
variable "vm_config" {
  type = object({
    size = string
    port = number
    enabled = bool
  })
  default = {
    size    = Standard_DS1_v2      # Error 1
    port    = "443"                # Error 2
    enabled = "true"               # Error 3
  }
}
```

**Answer:**
```hcl
variable "vm_config" {
  type = object({
    size    = string
    port    = number
    enabled = bool
  })
  default = {
    size    = "Standard_DS1_v2"   # Fixed 1: added quotes (it's a string)
    port    = 443                  # Fixed 2: removed quotes (it's a number)
    enabled = true                 # Fixed 3: removed quotes (it's a bool)
  }
}
```

---

### Exercise 4 — Access All Types

Given these variables, write the expression to get each value:

```hcl
variable "locations" { default = ["East US", "West Europe"] }
variable "disk_gb"   { default = 128 }
variable "tags"      { default = { env = "prod", team = "sre" } }
variable "vm_cfg"    { default = { size = "Standard_D2s_v3", sku = "18.04-LTS" } }
variable "net_cfg"   { default = ["10.0.0.0/16", "10.0.1.0", 24] }
```

Get:
1. The second location
2. The disk size plus 20 (computed)
3. The team tag value
4. The VM size from the object
5. The subnet mask from the tuple

**Answers:**
```hcl
1. var.locations[1]                        # "West Europe"
2. var.disk_gb + 20                        # 148
3. var.tags["team"]                        # "sre"
4. var.vm_cfg.size                         # "Standard_D2s_v3"
5. element(var.net_cfg, 2)                 # 24
```

---

## 18. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║           TERRAFORM TYPE CONSTRAINTS — DAY 7 QUICK REFERENCE                ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PRIMITIVE TYPES                                                             ║
║                                                                              ║
║  string  "text"     → names, locations, environment names                   ║
║  number  42         → sizes, counts, ports (NO quotes)                      ║
║  bool    true/false → on/off switches (NO quotes, NOT "true")               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMPLEX TYPES                                                               ║
║                                                                              ║
║  list(string)     ["a","b","c"]    ordered, duplicates OK                   ║
║  set(string)      {"a","b","c"}    unordered, unique only                   ║
║  map(string)      {k="v",k2="v2"} key-value, all values same type          ║
║  object({f=type}) {f=val,f2=val2} named fields, each can differ            ║
║  tuple([t1,t2])   [v1, v2]        fixed length, positions typed             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  ACCESS PATTERNS                                                             ║
║                                                                              ║
║  string/number/bool → var.name                                              ║
║  list               → var.name[index]        var.locs[0]                   ║
║  set                → Cannot index! Use for_each or contains()              ║
║  map                → var.name["key"]        var.tags["env"]               ║
║  object             → var.name.field         var.vm.size                   ║
║  tuple              → element(var.name, idx) element(var.net, 0)           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LIST vs SET vs MAP vs OBJECT vs TUPLE                                       ║
║                                                                              ║
║  list   → ordered, indexed [0][1][2], duplicates OK                        ║
║  set    → unordered, no index, unique values only                           ║
║  map    → key-value, access by string key, all values same type            ║
║  object → named fields with DIFFERENT types, access by .fieldname          ║
║  tuple  → ordered positions with DIFFERENT types, use element()            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMON GOTCHAS                                                              ║
║                                                                              ║
║  "true"   → string (WRONG for bool fields)                                  ║
║  "80"     → string (WRONG for number fields)                                ║
║  var.map.key   → use var.map["key"] instead for maps                       ║
║  var.list[-1]  → INVALID in Terraform (no negative indexes)                ║
║  set[0]        → INVALID in Terraform (sets have no index)                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL — COMMON COMMANDS                                                ║
║                                                                              ║
║  Set auth:   $env:ARM_CLIENT_ID = "your-id"                                 ║
║  Init:       terraform init                                                  ║
║  Validate:   terraform validate                                              ║
║  Plan:       terraform plan                                                  ║
║  Apply:      terraform apply --auto-approve                                 ║
║  Destroy:    terraform destroy --auto-approve                               ║
║  Outputs:    terraform output                                                ║
║  Unset auth: Remove-Item Env:ARM_CLIENT_ID                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
Think of types as CONTAINERS of different shapes:

string  → a label on a jar          "West Europe"
number  → a measuring cup            80
bool    → a light switch             true / false

list    → a numbered shelf:
            [0]="West Europe"  [1]="North Europe"
            Access by NUMBER

set     → a bag of unique coins:
            {"West Europe","North Europe"}
            Cannot reach in and grab one by position

map     → a dictionary:
            "environment" → "staging"
            "department"  → "devops"
            Access by NAME (key)

object  → a form with named fields:
            .size      = "Standard_DS1_v2"
            .publisher = "Canonical"
            Access by FIELD NAME with dot

tuple   → a fixed box with labelled slots:
            slot 0: string "10.0.0.0/16"
            slot 1: string "10.0.1.0"
            slot 2: number 24
            Access by POSITION with element()
```

---

*Guide covers: Terraform type constraints, primitive types (string, number, bool),
complex types (list, set, map, object, tuple), any type, list indexing, zero-based
indexing, element() function, map bracket notation, object dot notation, set
uniqueness constraint, set vs list differences, tuple fixed-length mixed-type
sequences, string interpolation with ${}, type validation, accessing nested type
values, Azure Linux VM resource, os_disk block, source_image_reference block,
disk_size_gb, delete_os_disk_on_termination, address_space, address_prefixes,
network interface, VNet, subnet, Terraform documentation argument reference,
PowerShell ARM credential management, terraform init/validate/plan/apply/destroy.*
