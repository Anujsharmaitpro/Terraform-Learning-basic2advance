# Terraform Lifecycle Meta-Arguments — Complete Guide
## Deep-Dive Learning Guide — Day 9 / 28 Days of Easy Terraform
### Beginner-First Edition | Azure Examples | PowerShell Commands Throughout

---

## Before You Start

This is Day 9. By now you know:
- Day 1–3: Terraform fundamentals, providers, resources, dependencies
- Day 4: State file and remote backends
- Day 5: Input, output, and local variables
- Day 6: Professional file structure
- Day 7: All type constraints
- Day 8: `count`, `for_each`, and `for` loops

Today covers the **last meta-argument category**: `lifecycle` rules.
These are the safety controls of Terraform — they let you say "never
destroy this," "create the replacement before deleting the old one,"
or "ignore changes to this field no matter what." In production these
are critical for zero-downtime deployments and protecting sensitive resources.

---

## Table of Contents

1. What Are Lifecycle Rules? — The Safety Controls of Terraform
2. The Complete List of Lifecycle Arguments
3. `create_before_destroy` — Zero Downtime Replacements
4. `prevent_destroy` — The Production Safety Net
5. `ignore_changes` — Telling Terraform to Look Away
6. `replace_triggered_by` — Cascading Replacements Between Resources
7. `precondition` — Validation Before Terraform Does Anything
8. `postcondition` — Validation After Resource Creation
9. The `contains()` Function — Used Inside Conditions
10. Where the `lifecycle` Block Goes — Syntax Rules
11. The Debugging Lesson from the Video — Wrong Directory
12. The Complete Working Code — All Files
13. Real-World Use Cases for Each Lifecycle Rule
14. Common Mistakes Beginners Make
15. Practice Exercises
16. Complete Cheat Sheet

---

## 1. What Are Lifecycle Rules? — The Safety Controls of Terraform

### The default Terraform behaviour

By default, when Terraform needs to replace a resource (because you
changed a field that forces replacement), it:

1. **Destroys** the old resource
2. **Creates** the new resource

That gap between step 1 and step 2 = **downtime**.

Also by default:
- You can destroy ANY resource with `terraform destroy`
- Terraform tracks ALL changes and applies ALL of them
- Changing a field in your config immediately applies when you run apply

Sometimes you don't want this default behaviour. That's where `lifecycle`
rules come in.

### The analogy — a building's safety systems

Think of your Azure infrastructure as a building:

```
create_before_destroy  → Build the new wing BEFORE demolishing the old one
                         (no time when tenants have nowhere to go)

prevent_destroy        → This load-bearing wall CANNOT be removed
                         (a hard rule that prevents dangerous mistakes)

ignore_changes         → This room's decor was customised by the tenant
                         (Terraform shouldn't reset it to default)

replace_triggered_by   → If the foundation changes, rebuild the whole building
                         (cascading dependency rules)

precondition           → Inspect the blueprint BEFORE starting construction
                         (validate inputs before spending money)

postcondition          → Inspect the finished work BEFORE handing over keys
                         (verify outputs meet requirements after creation)
```

### The `lifecycle` block syntax — where it lives

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "techtutorials11"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {                          # ← always inside the resource block
    create_before_destroy = true       # ← lifecycle arguments go here
    prevent_destroy       = false
    ignore_changes        = [tags]
  }
}
```

The `lifecycle` block is always a direct child of the resource block.
It cannot be placed outside the resource, and only ONE lifecycle block
is allowed per resource.

---

## 2. The Complete List of Lifecycle Arguments

```
lifecycle {
  ┌─────────────────────────────────────────────────────────────────┐
  │  create_before_destroy = true / false                           │
  │  → Create the new resource BEFORE destroying the old one        │
  ├─────────────────────────────────────────────────────────────────┤
  │  prevent_destroy = true / false                                 │
  │  → Block ALL destructive operations on this resource            │
  ├─────────────────────────────────────────────────────────────────┤
  │  ignore_changes = [field1, field2, ...]                         │
  │  → Tell Terraform to ignore changes to specific attributes      │
  ├─────────────────────────────────────────────────────────────────┤
  │  replace_triggered_by = [resource.name, resource.name.field]    │
  │  → Force replacement when a referenced resource changes         │
  ├─────────────────────────────────────────────────────────────────┤
  │  precondition {                                                  │
  │    condition     = expression                                    │
  │    error_message = "message shown when condition fails"         │
  │  }                                                               │
  │  → Validate inputs BEFORE creating the resource                 │
  ├─────────────────────────────────────────────────────────────────┤
  │  postcondition {                                                 │
  │    condition     = expression                                    │
  │    error_message = "message shown when condition fails"         │
  │  }                                                               │
  │  → Validate outputs AFTER the resource is created               │
  └─────────────────────────────────────────────────────────────────┘
}
```

---

## 3. `create_before_destroy` — Zero Downtime Replacements

### The problem it solves

When Terraform needs to replace a resource (because you changed an
immutable field like a storage account name), the default sequence is:

```
DEFAULT behaviour (no lifecycle rule):
  Step 1: DESTROY old storage account "techtutorials11"
          ← gap: storage account does not exist
  Step 2: CREATE new storage account "techtutorials12"

During Step 1 → Step 2: Applications trying to use the storage account
                         get connection errors. This is downtime.
```

With `create_before_destroy = true`:

```
WITH lifecycle create_before_destroy:
  Step 1: CREATE new storage account "techtutorials12"
          ← both exist simultaneously
  Step 2: DESTROY old storage account "techtutorials11"

During Step 1 → Step 2: Applications switch to the new resource.
                         No gap. No downtime.
```

### The syntax

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "techtutorials12"   # changed from techtutorials11
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    create_before_destroy = true
  }
}
```

### What the `terraform plan` output shows

Without `create_before_destroy`:
```
  # azurerm_storage_account.example must be replaced
  -/+ resource "azurerm_storage_account" "example" {
        ~ name = "techtutorials11" -> "techtutorials12" # forces replacement
      }

Plan: 1 to add, 0 to change, 1 to destroy.

Note: Objects are destroyed first and then re-created.
```

With `create_before_destroy = true`:
```
  # azurerm_storage_account.example must be replaced
  +/- resource "azurerm_storage_account" "example" {
        ~ name = "techtutorials11" -> "techtutorials12" # forces replacement
      }

Plan: 1 to add, 0 to change, 1 to destroy.

Note: Objects are created first and then destroyed (create_before_destroy is set).
```

The key difference: `-/+` (destroy then create) becomes `+/-` (create
then destroy). Small symbol change — massive operational difference.

### Important constraint

Some resources cannot have two instances running simultaneously (e.g.,
resources that require globally unique names). In that case,
`create_before_destroy = true` will fail because both the old and new
resource would have to exist at the same time with conflicting names.

```hcl
# This FAILS with create_before_destroy if the name doesn't change
# Both "techtutorials11" (old) and "techtutorials11" (new) can't coexist
lifecycle {
  create_before_destroy = true
}
```

For globally unique resources, make sure the new name is different so
both can temporarily coexist during the transition.

### The instructor's observation

The instructor applied `create_before_destroy` to the Resource Group but
noticed the storage account was still destroyed before being created —
because the lifecycle rule was on the WRONG resource (the Resource Group,
not the Storage Account). When he moved it to the storage account, the
behaviour changed to create-then-destroy as expected.

**Key lesson:** The lifecycle block must be on the resource you want to
protect — not on a related resource.

---

## 4. `prevent_destroy` — The Production Safety Net

### What it does

When `prevent_destroy = true` is set on a resource, Terraform REFUSES
to run any operation that would destroy that resource — including:
- `terraform destroy`
- Changing an immutable field that would force replacement
- Removing the resource block from your `.tf` file

### The syntax

```hcl
resource "azurerm_resource_group" "example" {
  name     = "staging-resources"
  location = "West Europe"

  lifecycle {
    prevent_destroy = true
  }
}
```

### What the error looks like

The instructor changed the location of the Resource Group (which forces
replacement) while `prevent_destroy = true` was set. Terraform plan gave:

```
Error: Instance cannot be destroyed

  on resource_group.tf line 1, in resource "azurerm_resource_group" "example":
   1: resource "azurerm_resource_group" "example" {

Resource azurerm_resource_group.example has lifecycle.prevent_destroy set,
but the plan calls for this resource to be destroyed. To avoid this error
and continue with the plan, either disable lifecycle.prevent_destroy or
reduce the scope of the plan using the -target flag.
```

Notice that it also blocked changes to the storage account — because
the storage account DEPENDS ON the resource group (implicit dependency).
If the resource group can't be destroyed, the storage account (which
would also need to be destroyed as part of the replacement) can't be
touched either.

### Real-world use cases

```
Resources you should almost always protect with prevent_destroy:

✅ Production databases (losing this = losing all data)
✅ Production storage accounts (losing this = losing all files)
✅ Key Vault instances (losing this = losing all secrets + keys)
✅ DNS zones (losing this = your domain stops working)
✅ Subscription-level resource groups containing critical resources

Resources where prevent_destroy is less necessary:
❌ Ephemeral compute (VMs that are disposable)
❌ Dev/test resources that are regularly rebuilt
❌ Resources that are stateless and easy to recreate
```

### Removing `prevent_destroy` to allow destruction

If you genuinely need to destroy a protected resource:

1. Change `prevent_destroy = true` to `prevent_destroy = false` in the code
2. Commit this change and get it reviewed (this is the safety gate)
3. Run `terraform destroy` or `terraform apply` as needed
4. Optionally restore the protection afterward

```hcl
# To allow temporary destruction:
lifecycle {
  prevent_destroy = false    # ← change to false, apply, destroy, change back
}
```

---

## 5. `ignore_changes` — Telling Terraform to Look Away

### What it does

`ignore_changes` tells Terraform: "Even if this field in Azure has a
different value than what's in my `.tf` file, do NOT consider that a
change that needs to be applied."

### When you need this

**Scenario 1 — External modification**
Your Azure resource has a tag added by an external process (like Azure
Policy or a compliance tool). If Terraform manages tags, it would try
to remove that external tag on every `terraform apply`. `ignore_changes`
on `tags` prevents this.

**Scenario 2 — Auto-scaling fields**
A VM's instance count is managed by Azure Auto-scaling. Terraform shouldn't
reset it to its starting value every time you run apply.

**Scenario 3 — Secrets updated externally**
A Key Vault secret's value is rotated by a rotation policy. Terraform
shouldn't reset it back to the original value.

### The syntax

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "techtutorials11"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [
      tags,                          # ignore ALL tag changes
      account_replication_type       # ignore replication type changes
    ]
  }
}
```

### Ignoring ALL tags

```hcl
lifecycle {
  ignore_changes = [tags]    # entire tags block is ignored
}
```

### Ignoring a specific tag key

```hcl
lifecycle {
  ignore_changes = [
    tags["ExternalTag"]    # only ignore this specific tag key
  ]
}
```

### Ignoring ALL changes (`ignore_changes = all`)

```hcl
lifecycle {
  ignore_changes = all    # Terraform will never modify this resource again
                           # after initial creation
}
```

Use `all` with extreme caution. If you use `ignore_changes = all`, your
`.tf` file becomes purely for documentation — Terraform will never update
the resource, even if you change its configuration.

### What the instructor demonstrated

He set `ignore_changes = [account_replication_type]` on the storage account,
then changed `account_replication_type` from `"GRS"` to `"LRS"` in the
`.tf` file and ran `terraform apply`. Result:

```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

Terraform detected the change in config but ignored it because of the
lifecycle rule. Then he removed the `ignore_changes` lifecycle and ran
apply again:

```
  # azurerm_storage_account.example will be updated in-place
  ~ resource "azurerm_storage_account" "example" {
      ~ account_replication_type = "GRS" -> "LRS"
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Now it applied the change. This confirmed that `ignore_changes` was working.

### Important: `ignore_changes` is about FIELD-LEVEL control

```hcl
# ignore_changes on a whole field
ignore_changes = [tags]

# ignore_changes on a nested field
ignore_changes = [source_image_reference]

# ignore_changes on multiple fields
ignore_changes = [
  tags,
  account_replication_type,
  access_tier
]
```

The fields inside `ignore_changes` are the ARGUMENT names from the
resource — the same names you use when configuring the resource.

---

## 6. `replace_triggered_by` — Cascading Replacements Between Resources

### What it does

`replace_triggered_by` forces a resource to be REPLACED (destroyed and
recreated) whenever a referenced resource or resource attribute changes.

This creates a cascading replacement dependency: "If X changes, force
Y to be replaced too."

### When you need this

**Scenario:** You have a VM that uses a custom script. The script is
stored as a separate resource. When the script changes, you want the VM
to be rebuilt from scratch — not just updated in place — to ensure it
picks up the new script.

Without `replace_triggered_by`, Terraform might just update the script
resource but leave the running VM using the old script.

### The syntax

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "techtutorials11"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    replace_triggered_by = [
      azurerm_resource_group.example.id
      # Whenever the Resource Group's ID changes,
      # force-replace this storage account too
    ]
  }
}
```

### Referencing a whole resource vs a specific attribute

```hcl
lifecycle {
  # Replace when ANY part of the resource group changes
  replace_triggered_by = [azurerm_resource_group.example]

  # Replace ONLY when the resource group's ID changes
  replace_triggered_by = [azurerm_resource_group.example.id]
}
```

### Combining with other lifecycle rules

```hcl
resource "azurerm_linux_virtual_machine" "app" {
  name = "app-vm"
  # ...

  lifecycle {
    create_before_destroy = true     # minimize downtime when replacing
    replace_triggered_by  = [
      azurerm_resource_group.example.id   # replace VM if RG changes
    ]
  }
}
```

---

## 7. `precondition` — Validation Before Terraform Does Anything

### What it does

A `precondition` is a validation check that runs BEFORE Terraform creates
or modifies the resource. If the condition fails, Terraform stops
immediately with your custom error message — before any cloud resources
are touched.

Think of it as a quality gate at the start of the construction process.

### When to use it

- Validate that a variable value is in an allowed list
- Ensure a resource name follows naming conventions
- Check that dependent configurations make sense together
- Enforce organizational policies in code

### The syntax

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-${var.environment}"
  location = var.location

  lifecycle {
    precondition {
      condition     = contains(var.allowed_locations, var.location)
      error_message = "Please enter a valid location from the allowed list."
    }
  }
}
```

### Breaking down every part

**`lifecycle { precondition { ... } }`**
The precondition block lives inside the lifecycle block, which lives
inside the resource block.

**`condition = contains(var.allowed_locations, var.location)`**
The condition is a boolean expression — it must evaluate to `true` for
the check to pass. If it evaluates to `false`, Terraform stops and shows
the error message.

The `contains()` function checks whether a value exists inside a collection:
```hcl
contains(["West Europe", "North Europe", "East US"], "West Europe")  # true
contains(["West Europe", "North Europe", "East US"], "Canada Central") # false
```

**`error_message = "Please enter a valid location..."`**
This is what Terraform shows when the condition fails. Make it helpful
and actionable — tell the user what to fix.

### The instructor's example — location validation

```hcl
variable "allowed_locations" {
  type    = list(string)
  default = ["West Europe", "North Europe", "East US"]
}

variable "location" {
  type    = string
  default = "West Europe"    # valid — passes precondition
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${var.environment}"
  location = var.location    # uses the location variable

  lifecycle {
    precondition {
      condition     = contains(var.allowed_locations, var.location)
      error_message = "Please enter a valid location from the allowed list."
    }
  }
}
```

### Testing the precondition — valid location

```powershell
# terraform.tfvars has: location = "West Europe"
terraform plan

# Output: Plan shows resource creation — precondition PASSED
# West Europe IS in the allowed_locations list → condition = true → OK
```

### Testing the precondition — INVALID location

```powershell
# terraform.tfvars has: location = "Canada Central"
terraform plan
```

```
Error: Resource precondition failed

  with azurerm_resource_group.example,
  on resource_group.tf line 8, in resource "azurerm_resource_group" "example":
   8:       condition     = contains(var.allowed_locations, var.location)
     ├────────────────
     │ var.allowed_locations is ["West Europe", "North Europe", "East US"]
     │ var.location           is "Canada Central"

Please enter a valid location from the allowed list.
```

Terraform shows:
- Which resource failed
- Which file and line number
- The values of the variables being evaluated
- Your custom error message

This happens BEFORE any Azure API calls — no resources are created or
modified.

### Multiple preconditions on one resource

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-${var.environment}"
  location = var.location

  lifecycle {
    precondition {
      condition     = contains(var.allowed_locations, var.location)
      error_message = "Please enter a valid Azure location."
    }

    precondition {
      condition     = contains(["dev", "staging", "prod"], var.environment)
      error_message = "Environment must be dev, staging, or prod."
    }

    precondition {
      condition     = length(var.environment) <= 10
      error_message = "Environment name must be 10 characters or fewer."
    }
  }
}
```

---

## 8. `postcondition` — Validation After Resource Creation

### What it does

A `postcondition` is a validation check that runs AFTER a resource is
created or updated. If the condition fails, Terraform returns an error.

Use postconditions to verify that the created resource actually meets
your requirements — not just that it was created without errors.

### When to use it

- Verify a VM got a public IP assigned (if required)
- Verify a storage account was created in the correct region
- Check that generated attributes meet your expectations
- Validate that Azure returned the values you expected

### The syntax

```hcl
resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_DS1_v2"
  # ...

  lifecycle {
    postcondition {
      condition     = self.public_ip_address != null
      error_message = "VM was created without a public IP address. Check network configuration."
    }
  }
}
```

### The `self` keyword

Inside a `postcondition`, you use `self` to refer to the resource being
checked (rather than the full resource reference):

```hcl
postcondition {
  condition     = self.location == "westeurope"
  error_message = "Resource was created in the wrong region."
}

# self.location refers to the location of THIS resource after creation
# equivalent to azurerm_linux_virtual_machine.example.location
```

### Precondition vs Postcondition — when each runs

```
Your .tf files are read
         ↓
    terraform plan
         ↓
PRECONDITION RUNS ← "Check inputs before creating anything"
         ↓
    terraform apply
         ↓
  Resource created
         ↓
POSTCONDITION RUNS ← "Verify outputs after creation"
         ↓
  State file updated
```

---

## 9. The `contains()` Function — Used Inside Conditions

The instructor used `contains()` inside the precondition. Since functions
are covered in a later video, here is just what you need to know for
lifecycle conditions:

### What `contains()` does

```hcl
contains(list, value)
# Returns true  if value is found in list
# Returns false if value is NOT found in list
```

### Examples

```hcl
contains(["West Europe", "North Europe"], "West Europe")   # true
contains(["West Europe", "North Europe"], "East US")       # false
contains(["dev", "staging", "prod"], "prod")               # true
contains(["dev", "staging", "prod"], "testing")            # false
```

### Using it in a precondition

```hcl
# Check if var.environment is one of the allowed values
condition = contains(["dev", "staging", "prod"], var.environment)

# Check if var.location is in the allowed locations list
condition = contains(var.allowed_locations, var.location)
```

---

## 10. Where the `lifecycle` Block Goes — Syntax Rules

### Rule 1 — Inside the resource block

```hcl
resource "azurerm_storage_account" "example" {
  # resource arguments
  name = "techtutorials11"
  ...

  lifecycle {           # ← inside the resource block
    ...
  }
}
```

### Rule 2 — Only one lifecycle block per resource

```hcl
# ❌ WRONG — two lifecycle blocks in one resource
resource "azurerm_storage_account" "example" {
  lifecycle {
    prevent_destroy = true
  }
  lifecycle {               # Error: duplicate lifecycle block
    ignore_changes = [tags]
  }
}

# ✅ CORRECT — combine everything in ONE lifecycle block
resource "azurerm_storage_account" "example" {
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}
```

### Rule 3 — Multiple lifecycle rules can coexist in one block

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "techtutorials11"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true           # minimize downtime
    prevent_destroy       = true           # protect from accidents
    ignore_changes        = [tags]         # don't reset external tags

    precondition {
      condition     = contains(var.allowed_locations, var.location)
      error_message = "Location must be in the approved list."
    }
  }
}
```

### Rule 4 — `precondition` and `postcondition` are sub-blocks

```hcl
lifecycle {
  # Simple arguments — flat key = value
  create_before_destroy = true
  prevent_destroy       = false
  ignore_changes        = [field1, field2]
  replace_triggered_by  = [resource.name]

  # Sub-blocks — have their own curly braces
  precondition {
    condition     = expression
    error_message = "message"
  }

  postcondition {
    condition     = self.field != null
    error_message = "message"
  }
}
```

---

## 11. The Debugging Lesson from the Video — Wrong Directory

The instructor spent a significant portion of the video confused about
why `terraform plan` was showing no changes even though he was clearly
modifying the configuration.

### What happened

He was editing files in the `day09/` folder but running Terraform commands
from the `day08/` folder. The state file from day08 reflected day08's
infrastructure. Day09's configuration changes were in a completely
different folder that Terraform wasn't reading.

### The error pattern

```
You edit files in: /projects/day09/main.tf
You run commands in: /projects/day08/

Terraform reads: /projects/day08/*.tf
Terraform compares against: /projects/day08/terraform.tfstate

Your day09 changes are completely invisible to Terraform.
Result: "No changes. Your infrastructure matches the configuration."
```

### How to avoid this

**PowerShell — always verify your current directory:**
```powershell
# Check which directory you're in
Get-Location

# Output should match where your .tf files are
# C:\projects\day09   ← correct
# C:\projects\day08   ← wrong if you're editing day09 files

# Navigate to the correct folder
Set-Location "C:\projects\day09"

# Verify your .tf files are here
Get-ChildItem *.tf
```

**Verify your state is correct:**
```powershell
# List all resources Terraform thinks exist
terraform state list

# If this is empty or shows wrong resources, you're in the wrong folder
```

### The lesson

Before running ANY Terraform command, ask:
1. "Am I in the same folder as my `.tf` files?"
2. "Does `terraform state list` show the resources I expect?"

This is one of the most common causes of confusing Terraform behaviour
for beginners.

---

## 12. The Complete Working Code — All Files

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
  type        = string
  description = "Azure region for deployment"
  default     = "West Europe"
}

variable "allowed_locations" {
  type        = list(string)
  description = "List of approved Azure regions"
  default     = ["West Europe", "North Europe", "East US"]
}

variable "storage_account_names" {
  type        = set(string)
  description = "Storage account names to create"
  default     = ["techtutorials11", "techtutorials12"]
}
```

---

**`resource_group.tf`**
```hcl
resource "azurerm_resource_group" "example" {
  name     = "${var.environment}-resources"
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    # Prevent accidental deletion of the resource group
    prevent_destroy = true

    # Validate location before creating
    precondition {
      condition     = contains(var.allowed_locations, var.location)
      error_message = "Please enter a valid location. Allowed: West Europe, North Europe, East US."
    }
  }
}
```

---

**`storage_account.tf`**
```hcl
resource "azurerm_storage_account" "example" {
  for_each = var.storage_account_names

  name                     = each.value
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    ExternalTag = "managed-by-azure-policy"  # this will be ignored
  }

  lifecycle {
    # Create new storage account BEFORE destroying the old one
    create_before_destroy = true

    # Don't reset tags changed by external tools (Azure Policy, etc.)
    ignore_changes = [tags]

    # Force replace if the resource group's ID changes
    replace_triggered_by = [
      azurerm_resource_group.example.id
    ]

    # Validate location before creating
    precondition {
      condition     = contains(var.allowed_locations, var.location)
      error_message = "Storage account location must be in the approved list."
    }

    # Verify account was created in the correct location
    postcondition {
      condition     = self.location == lower(replace(var.location, " ", ""))
      error_message = "Storage account was not created in the expected location."
    }
  }
}
```

---

**`outputs.tf`**
```hcl
output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.example.name
}

output "storage_account_names" {
  description = "All created storage account names"
  value       = [for sa in azurerm_storage_account.example : sa.name]
}

output "storage_account_endpoints" {
  description = "Primary blob endpoints for all storage accounts"
  value = {
    for sa in azurerm_storage_account.example :
    sa.name => sa.primary_blob_endpoint
  }
}
```

---

**`terraform.tfvars`**
```hcl
environment   = "staging"
location      = "West Europe"

allowed_locations = ["West Europe", "North Europe", "East US"]

storage_account_names = ["techtutorials11", "techtutorials12"]
```

---

**PowerShell — full workflow:**
```powershell
# Verify you're in the right directory
Get-Location

# Navigate to day09 project
Set-Location "C:\projects\day09"

# Verify .tf files exist here
Get-ChildItem *.tf

# Set Azure authentication
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# Step 1: Initialise
terraform init

# Step 2: Validate syntax
terraform validate

# Step 3: Plan — valid location, should succeed
terraform plan

# Step 4: Test precondition — use invalid location
# Edit terraform.tfvars: location = "Canada Central"
terraform plan
# Should fail with: "Please enter a valid location."

# Step 5: Restore valid location and apply
# Edit terraform.tfvars: location = "West Europe"
terraform apply --auto-approve

# Step 6: Test ignore_changes — change replication type in .tf file
# Edit storage_account.tf: account_replication_type = "LRS"
terraform plan
# Should show: "No changes" (because ignore_changes = [account_replication_type])

# Step 7: Test prevent_destroy — try to destroy
terraform destroy
# Should fail with: "Instance cannot be destroyed"

# Step 8: To actually destroy — temporarily disable prevent_destroy
# Edit resource_group.tf: prevent_destroy = false
terraform destroy --auto-approve

# Step 9: Restore prevent_destroy after cleanup
# Edit resource_group.tf: prevent_destroy = true

# Clear credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 13. Real-World Use Cases for Each Lifecycle Rule

### `create_before_destroy` — Production deployments

```hcl
# Azure Application Gateway certificate rotation
resource "azurerm_key_vault_certificate" "app_cert" {
  name         = "app-ssl-cert-v2"    # new version
  key_vault_id = azurerm_key_vault.example.id
  # ...

  lifecycle {
    create_before_destroy = true
    # Import new cert before deleting old one
    # Application stays secured throughout the transition
  }
}
```

### `prevent_destroy` — Database protection

```hcl
# Never accidentally delete the production database
resource "azurerm_postgresql_server" "prod" {
  name                = "prod-postgres"
  resource_group_name = azurerm_resource_group.prod.name
  location            = "West Europe"
  # ...

  lifecycle {
    prevent_destroy = true
    # terraform destroy will fail with a clear error
    # Forces engineer to explicitly remove this protection to proceed
  }
}
```

### `ignore_changes` — Azure Policy managed tags

```hcl
# Azure Policy automatically adds compliance tags to all resources
# Terraform shouldn't fight with Azure Policy by removing them
resource "azurerm_storage_account" "data" {
  # ...
  tags = {
    Environment = var.environment    # managed by Terraform
    # Azure Policy will add: CostCenter, DataClassification, etc.
  }

  lifecycle {
    ignore_changes = [
      tags    # don't remove tags added by Azure Policy
    ]
  }
}
```

### `replace_triggered_by` — Config-driven VM rebuilds

```hcl
# When the init script changes, force rebuild the VM
resource "azurerm_linux_virtual_machine" "app" {
  name = "app-vm"
  # ...

  lifecycle {
    replace_triggered_by = [
      azurerm_virtual_machine_extension.init_script.id
      # If the extension changes, the VM gets replaced
    ]
  }
}
```

### `precondition` — Environment policy enforcement

```hcl
# Enforce that prod resources only go to specific regions
resource "azurerm_storage_account" "prod_data" {
  location = var.location

  lifecycle {
    precondition {
      condition = var.environment != "prod" || contains(
        ["West Europe", "North Europe"],
        var.location
      )
      error_message = "Production resources must be deployed in West Europe or North Europe."
    }
  }
}
```

---

## 14. Common Mistakes Beginners Make

### Mistake 1 — Putting lifecycle outside the resource block

```hcl
# ❌ WRONG — lifecycle outside the resource block
resource "azurerm_storage_account" "example" {
  name = "techtutorials11"
}

lifecycle {              # Error: lifecycle is not valid at this level
  prevent_destroy = true
}

# ✅ CORRECT — lifecycle inside the resource block
resource "azurerm_storage_account" "example" {
  name = "techtutorials11"

  lifecycle {
    prevent_destroy = true
  }
}
```

---

### Mistake 2 — Using two lifecycle blocks in one resource

```hcl
# ❌ WRONG — duplicate lifecycle blocks
resource "azurerm_storage_account" "example" {
  lifecycle {
    prevent_destroy = true
  }
  lifecycle {            # Error: duplicate lifecycle block
    ignore_changes = [tags]
  }
}

# ✅ CORRECT — all rules in ONE lifecycle block
resource "azurerm_storage_account" "example" {
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}
```

---

### Mistake 3 — Adding lifecycle to the WRONG resource

```hcl
# ❌ You want storage account to use create_before_destroy
# But you put it on the resource group by mistake

resource "azurerm_resource_group" "example" {
  lifecycle {
    create_before_destroy = true    # ← wrong resource!
  }
}

resource "azurerm_storage_account" "example" {
  # No lifecycle here — storage account still uses destroy-then-create
}

# ✅ Put the lifecycle on the resource you want to protect
resource "azurerm_storage_account" "example" {
  lifecycle {
    create_before_destroy = true    # ← correct resource
  }
}
```

This is exactly the mistake the instructor made in the video.

---

### Mistake 4 — Forgetting `error_message` in precondition/postcondition

```hcl
# ❌ Missing required error_message
lifecycle {
  precondition {
    condition = contains(var.allowed_locations, var.location)
    # Error: attribute "error_message" is required
  }
}

# ✅ Both condition AND error_message are required
lifecycle {
  precondition {
    condition     = contains(var.allowed_locations, var.location)
    error_message = "Please enter a valid location."
  }
}
```

---

### Mistake 5 — Running commands from the wrong directory

```powershell
# ❌ WRONG — editing day09 files but running from day08
Set-Location "C:\projects\day08"   # wrong directory!
# Edit files in C:\projects\day09\...
terraform plan                     # reads day08 files — ignores day09 changes!

# ✅ CORRECT — always be in the same directory as your .tf files
Set-Location "C:\projects\day09"   # correct directory
terraform plan                     # reads day09 files correctly
```

Always run this check first:
```powershell
Get-Location             # confirm you're in the right folder
Get-ChildItem *.tf       # confirm your .tf files are here
terraform state list     # confirm the state matches your expectations
```

---

### Mistake 6 — Using `ignore_changes = all` without understanding consequences

```hcl
# ⚠️ VERY CAREFUL with this
lifecycle {
  ignore_changes = all    # Terraform will NEVER update this resource again
                           # Your .tf file becomes decoration — not authoritative
}

# This means:
# - You change account_tier from Standard to Premium in .tf
# - terraform plan says: "No changes"
# - The resource stays at Standard FOREVER until you remove this lifecycle rule
```

Use `ignore_changes = all` only when:
- An external system fully manages the resource after initial creation
- You want Terraform to create but not maintain a resource

---

## 15. Practice Exercises

### Exercise 1 — Add the Right Lifecycle Rule

A team member accidentally ran `terraform destroy` and deleted the
production database. Which lifecycle rule would have prevented this?
Write the lifecycle block.

**Answer:**
```hcl
resource "azurerm_postgresql_server" "prod" {
  name = "prod-postgres"
  # ...

  lifecycle {
    prevent_destroy = true
    # terraform destroy would now fail with:
    # "Error: Instance cannot be destroyed"
  }
}
```

---

### Exercise 2 — Write a Precondition

Write a precondition that validates the `var.environment` variable
must be one of: `"dev"`, `"staging"`, or `"prod"`. Display a helpful
error message if validation fails.

**Answer:**
```hcl
lifecycle {
  precondition {
    condition = contains(
      ["dev", "staging", "prod"],
      var.environment
    )
    error_message = "Environment must be one of: dev, staging, or prod. Got: ${var.environment}"
  }
}
```

---

### Exercise 3 — Identify the Lifecycle Rule

For each scenario, name the lifecycle rule and write the code:

a) "When the VM is replaced, build the new one first to avoid downtime"
b) "Azure Policy adds tags — don't let Terraform fight with Policy"
c) "This Key Vault must never be accidentally deleted"
d) "If the subnet changes, force-replace the VM too"

**Answers:**

```hcl
# a) create_before_destroy
lifecycle { create_before_destroy = true }

# b) ignore_changes
lifecycle { ignore_changes = [tags] }

# c) prevent_destroy
lifecycle { prevent_destroy = true }

# d) replace_triggered_by
lifecycle {
  replace_triggered_by = [azurerm_subnet.example.id]
}
```

---

### Exercise 4 — Debug the Lifecycle Error

Why does this lifecycle block cause an error?

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "West Europe"
}

lifecycle {
  prevent_destroy = true
  precondition {
    condition = true
  }
}
```

**Answer:**
```
Two errors:
1. The lifecycle block is OUTSIDE the resource block.
   It must be inside the resource { } block.

2. The precondition is missing the required error_message attribute.

Fixed code:
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "West Europe"

  lifecycle {                           # ← moved inside resource
    prevent_destroy = true

    precondition {
      condition     = true
      error_message = "This condition always passes."   # ← added error_message
    }
  }
}
```

---

### Exercise 5 — PowerShell Workflow

Write the PowerShell commands to:
1. Navigate to a `day09` project folder
2. Set ARM credentials
3. Verify you're in the right folder
4. Initialise, plan, and apply
5. Test the precondition by setting an invalid location temporarily
6. Clean up credentials

**Answer:**
```powershell
# 1. Navigate
Set-Location "C:\projects\day09"

# 2. Set credentials
$env:ARM_CLIENT_ID       = "your-client-id"
$env:ARM_CLIENT_SECRET   = "your-client-secret"
$env:ARM_TENANT_ID       = "your-tenant-id"
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"

# 3. Verify location
Get-Location
Get-ChildItem *.tf
terraform state list

# 4. Initialise, plan, apply
terraform init
terraform validate
terraform plan
terraform apply --auto-approve

# 5. Test precondition (edit terraform.tfvars first: location = "Canada Central")
terraform plan
# Should show: "Error: Resource precondition failed"
# Edit back: location = "West Europe"

# 6. Clean up credentials
Remove-Item Env:ARM_CLIENT_ID
Remove-Item Env:ARM_CLIENT_SECRET
Remove-Item Env:ARM_TENANT_ID
Remove-Item Env:ARM_SUBSCRIPTION_ID
```

---

## 16. Complete Cheat Sheet

```
╔══════════════════════════════════════════════════════════════════════════════╗
║         TERRAFORM LIFECYCLE META-ARGUMENTS — DAY 9 QUICK REFERENCE          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SYNTAX — lifecycle block goes INSIDE the resource block                     ║
║                                                                              ║
║  resource "type" "name" {                                                    ║
║    # resource arguments...                                                   ║
║    lifecycle {                   ← ONE lifecycle block per resource          ║
║      create_before_destroy = true                                            ║
║      prevent_destroy       = true                                            ║
║      ignore_changes        = [field1, field2]                                ║
║      replace_triggered_by  = [other_resource.name]                          ║
║      precondition  { condition = expr  error_message = "..." }              ║
║      postcondition { condition = self.x != null  error_message = "..." }    ║
║    }                                                                         ║
║  }                                                                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LIFECYCLE RULES SUMMARY                                                     ║
║                                                                              ║
║  create_before_destroy = true                                                ║
║  → Create replacement FIRST, then destroy old one                           ║
║  → Minimizes downtime during forced replacements                            ║
║  → Plan shows +/- instead of -/+                                            ║
║                                                                              ║
║  prevent_destroy = true                                                      ║
║  → Blocks ALL destructive operations (destroy, replace)                     ║
║  → terraform destroy fails with "Instance cannot be destroyed"              ║
║  → Change to false to allow destruction                                     ║
║                                                                              ║
║  ignore_changes = [field1, field2]                                           ║
║  → Terraform ignores changes to listed fields                               ║
║  → Use for: tags managed by Azure Policy, auto-scaled values                ║
║  → ignore_changes = all  →  NEVER update this resource                     ║
║                                                                              ║
║  replace_triggered_by = [resource.name.field]                               ║
║  → Force replace THIS resource when referenced resource changes             ║
║  → Creates cascading replacement dependency                                 ║
║                                                                              ║
║  precondition { condition=expr, error_message="..." }                        ║
║  → Validation BEFORE creating/modifying the resource                        ║
║  → Stops apply before any Azure API calls if condition = false              ║
║                                                                              ║
║  postcondition { condition=self.field!=null, error_message="..." }           ║
║  → Validation AFTER resource creation                                       ║
║  → Use self.field to reference the created resource's attributes            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  contains() FUNCTION (used in conditions)                                    ║
║                                                                              ║
║  contains(collection, value)  → true if value is in collection              ║
║  contains(["West Europe","East US"], "West Europe")  → true                 ║
║  contains(["West Europe","East US"], "Canada")       → false                ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PLAN OUTPUT SYMBOLS                                                         ║
║                                                                              ║
║  -/+  destroy then create (DEFAULT with forced replacement)                 ║
║  +/-  create then destroy (WITH create_before_destroy = true)               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMON ERRORS                                                               ║
║                                                                              ║
║  "Instance cannot be destroyed"                                              ║
║  → prevent_destroy = true is blocking the operation                         ║
║  → Set to false temporarily to allow destruction                            ║
║                                                                              ║
║  "Resource precondition failed"                                              ║
║  → Your condition expression evaluated to false                             ║
║  → Fix the input variable or update the condition                           ║
║                                                                              ║
║  "attribute error_message is required"                                       ║
║  → Every precondition/postcondition needs an error_message                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  POWERSHELL DEBUGGING COMMANDS                                               ║
║                                                                              ║
║  Get-Location                  # confirm you're in the right folder         ║
║  Get-ChildItem *.tf            # confirm .tf files exist here               ║
║  terraform state list          # see what Terraform thinks exists           ║
║  terraform init                # initialise providers and backend           ║
║  terraform validate            # check syntax before plan                   ║
║  terraform plan                # preview changes (runs preconditions)       ║
║  terraform apply --auto-approve # apply (runs preconditions + apply)        ║
║  terraform destroy --auto-approve # destroy (blocked by prevent_destroy)   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## The Core Mental Model for This Video

```
The lifecycle block = Terraform's rule enforcement system for a resource

Without lifecycle:    Terraform does whatever is needed — create, update,
                      destroy, replace — automatically and without restriction

With lifecycle rules:
  create_before_destroy → "Build the replacement before demolishing the old"
  prevent_destroy       → "This building is protected — it cannot be torn down"
  ignore_changes        → "Ignore this room — someone else is decorating it"
  replace_triggered_by  → "If the foundation changes, rebuild the whole building"
  precondition          → "Inspector signs off BEFORE construction begins"
  postcondition         → "Inspector signs off AFTER construction is complete"

Think of lifecycle rules as the policies and constraints an architect
places on a building project — they don't change WHAT gets built,
they control HOW and WHEN building operations are allowed to happen.
```

---

*Guide covers: Terraform lifecycle meta-arguments, lifecycle block syntax,
create_before_destroy, prevent_destroy, ignore_changes, ignore_changes = all,
replace_triggered_by, precondition, postcondition, self keyword, contains()
function, lifecycle block placement rules, duplicate lifecycle block error,
missing error_message error, wrong directory debugging, terraform state list
verification, plan output symbols +/- vs -/+, production safety patterns,
Azure Policy tag management, zero-downtime deployments, conditional resource
protection, PowerShell directory verification commands, ARM credential
management in PowerShell, Get-Location, Get-ChildItem.*
