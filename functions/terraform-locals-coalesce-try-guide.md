# Terraform Local Values — A Complete Beginner Deep Dive
### Plus a focused look at `coalesce()` and `try()` (with Azure examples throughout)

> Verified against the official HashiCorp docs (`terraform/language/block/locals`, `terraform/tutorials/configuration-language/locals`) so the rules below reflect current Terraform behavior, not just convention.

---

## 1. What Is a Local Variable — Explained Like You've Never Coded Before

Imagine you're writing a long letter, and you keep needing to mention "the deadline of March 15th, 2026." Instead of retyping that full date every time, you write at the top: *"From now on, I'll call this date 'D-Day.'"* Then every time you write "D-Day," everyone reading knows exactly what you mean — and if the deadline ever changes, you fix it in **one place** at the top instead of hunting through the whole letter.

A **local value** in Terraform (commonly called a "local") is exactly that: **a nickname you give to a value or to the result of a calculation**, so you can use that nickname repeatedly throughout your `.tf` files instead of retyping the same thing — or the same complicated expression — over and over.

```hcl
locals {
  environment = "production"
}
```

That's it. You've created a nickname called `environment` that means `"production"`. From now on, anywhere in this module, you write `local.environment` and Terraform substitutes `"production"` in.

### The two keywords that confuse every beginner once

- `locals` (**plural**) — used only when you're *declaring/defining* values, inside the block: `locals { ... }`
- `local` (**singular**) — used only when you're *reading/referencing* a value elsewhere: `local.environment`

This trips up almost everyone in their first week. Just remember: **block = plural, reference = singular.**

### Where do locals live, and who can see them?

Locals are **scoped to the module they're defined in** — meaning if you define `local.environment` in your root module's `main.tf`, only code in that same module can see it. A child module you call cannot reach into your locals directly; you'd have to explicitly pass it in as an input variable. This matters in real Azure projects once you start breaking infrastructure into reusable modules (a "networking module," a "VM module," etc.) — locals don't leak across module boundaries by accident, which keeps modules predictable and self-contained.

---

## 2. The Core Question: What Can I Actually Put Inside a `locals` Block?

This is the part most beginners get wrong by assuming locals are just for plain text. In reality, a local can be **any valid Terraform expression** — which is a much bigger category than it sounds. Let's go through every type, one at a time, with Azure context.

### 2.1 A literal value (the simplest case)

```hcl
locals {
  environment = "production"
  vm_count    = 3
  is_prod     = true
}
```

Just like assigning a value to a labeled box. Nothing computed, nothing referenced — just a plain value with a name.

### 2.2 A reference to an input variable

```hcl
variable "project_name" {
  type    = string
  default = "Payments App"
}

locals {
  project = var.project_name
}
```

Why bother? Usually you don't do this *alone* — you do it as a stepping stone toward step 2.3.

### 2.3 An expression that transforms a variable (this is where locals really earn their keep)

```hcl
locals {
  # Combine, calculate, reshape — anything goes
  clean_name = lower(replace(var.project_name, " ", "-"))
}
```

This is the single most common real-world use of locals: **taking a raw input and computing a derived, ready-to-use value**, exactly like the Azure naming examples in our earlier guides (`lower`, `replace`, `format`, `substr`, etc. all live happily inside locals).

### 2.4 A reference to a resource's attribute

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-payments-prod"
  location = "eastus"
}

locals {
  rg_location = azurerm_resource_group.rg.location
}
```

Locals can reach into resources you've already defined and pull out one of their computed attributes (an ID, a name, a generated IP address) to reuse elsewhere — handy when several other resources all need to reference the same resource group's location, without each one repeating `azurerm_resource_group.rg.location` directly.

### 2.5 A reference to a data source

```hcl
data "azurerm_resource_group" "existing" {
  name = "rg-shared-networking"
}

locals {
  shared_vnet_location = data.azurerm_resource_group.existing.location
}
```

`data` blocks pull in information about *existing* Azure infrastructure (things Terraform didn't create itself). Locals can wrap and rename those lookups too.

### 2.6 A reference to another local (chaining)

```hcl
locals {
  project     = "payments"
  environment = "prod"

  # this local references the two above
  name_prefix = "${local.project}-${local.environment}"

  # and this one references name_prefix
  rg_name = "rg-${local.name_prefix}"
}
```

Locals can build on top of each other freely, and **Terraform automatically figures out the correct order to evaluate them in** — you don't need to declare them top-to-bottom in dependency order; Terraform resolves the dependency graph itself. The only hard rule: **no circular references**. `local.a` cannot depend on `local.b` if `local.b` also depends on `local.a` — Terraform will error out immediately if you try.

### 2.7 A function call (any function from our previous guides works here)

```hcl
locals {
  common_tags = merge(
    { ManagedBy = "Terraform", Environment = "Production" },
    { Project = "Payments" }
  )

  subnet_cidrs = cidrsubnets("10.0.0.0/16", 8, 8, 8)

  total_disk_gb = sum([100, 250, 500])
}
```

Literally **every built-in function** Terraform offers (`merge`, `lower`, `cidrsubnet`, `coalesce`, `try`, `jsonencode`, all ~100 of them) is fair game inside a local. This is the natural home for function calls — you rarely call a function directly inside a `resource` block's argument if the logic is more than trivially simple; you compute it once as a local, give it a clear name, then reference that name.

### 2.8 A conditional (`if/else` style, written as a ternary)

```hcl
locals {
  is_production  = var.environment == "production"
  vm_size        = local.is_production ? "Standard_D4s_v5" : "Standard_B2s"
  instance_count = local.is_production ? 3 : 1
}
```

The `condition ? value_if_true : value_if_false` syntax is Terraform's version of an if/else statement, squeezed into one line. This pattern — sizing VMs differently per environment — is extremely common in real Azure modules.

### 2.9 A loop that builds a new list or map (a "for expression")

```hcl
variable "subnet_names" {
  default = ["web", "app", "db"]
}

locals {
  # builds a NEW list by transforming each item
  subnet_display_names = [for name in var.subnet_names : "snet-${name}"]
  # -> ["snet-web", "snet-app", "snet-db"]

  # builds a NEW map, keyed by name
  subnet_map = { for idx, name in var.subnet_names : name => "10.0.${idx}.0/24" }
  # -> { web = "10.0.0.0/24", app = "10.0.1.0/24", db = "10.0.2.0/24" }
}
```

This is hugely important once you start using `for_each` on Azure resources — locals are where you do the data-shaping *before* feeding it into a resource's `for_each` argument, instead of cramming the loop logic directly into the resource block.

### 2.10 A complex nested object

```hcl
locals {
  vm_config = {
    size           = "Standard_D2s_v5"
    admin_username = "azureadmin"
    os_disk = {
      caching = "ReadWrite"
      type    = "Premium_LRS"
    }
  }
}
```

Locals aren't limited to flat strings/numbers — they can hold deeply nested structures (objects containing objects, lists of objects, maps of lists), exactly like a JSON document, which you then unpack piece by piece (`local.vm_config.os_disk.type`) wherever it's needed.

### So, to directly answer your question:

> "Can we make a custom name and store any values against them?"

**Yes — exactly that.** You pick any valid name (a "valid identifier": letters, numbers, underscores, no spaces, must start with a letter or underscore), and you can assign it literally any Terraform-valid value or expression: plain text, numbers, booleans, lists, maps, nested objects, function results, conditionals, loops, or references to variables/resources/data sources/other locals. There's no restriction beyond "it must be valid HCL." Beginners sometimes assume locals are only for plain strings — they're not; they're a general-purpose naming mechanism for *any* computed value in your configuration.

---

## 3. Multiple `locals` Blocks — You're Allowed More Than One

```hcl
locals {
  # Naming
  project     = "payments"
  environment = "prod"
  name_prefix = "${local.project}-${local.environment}"
}

locals {
  # Networking
  vnet_cidr    = "10.0.0.0/16"
  subnet_cidrs = cidrsubnets(local.vnet_cidr, 8, 8, 8)
}
```

Terraform treats every `locals` block in a module as if they were all one giant block merged together — splitting them is purely for human readability (grouping "naming locals" separately from "networking locals" separately from "tagging locals"), not a technical requirement. Many enterprise codebases keep a dedicated `locals.tf` file just for this purpose.

---

## 4. Locals vs. Variables vs. Outputs — The Distinction Every Beginner Must Nail

| | Input Variable (`variable`) | Local Value (`locals`) | Output (`output`) |
|---|---|---|---|
| Who sets it? | The **person running** Terraform (via `.tfvars`, CLI flags, env vars) | **You, the module author**, computed internally | Terraform, **exposing** a value after apply |
| Can it be changed from outside the module? | Yes — that's its whole purpose | **No** — it's fixed internal logic the user can't override | N/A (it's a result, not an input) |
| Typical use | "Let the caller decide the environment name, VM size, region" | "Compute a clean resource group name from the project name" | "Show me the resource group ID after deployment, or pass it to another module" |
| Mental model | A function's **parameter** | A function's **internal variable** | A function's **return value** |

A concrete way to think about it: if you want a value that the person deploying your code can override, that's a `variable`. If you want a value that's computed automatically and the deploying user should *never* directly control, that's a `local`. If you want to hand a finished value back out to whoever called your module (or to display it after `terraform apply`), that's an `output`.

```hcl
variable "project_name" {        # caller can override this
  type    = string
  default = "Payments App"
}

locals {                          # internal computation, caller can't touch this directly
  clean_name = lower(replace(var.project_name, " ", "-"))
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.clean_name}"
  location = "eastus"
}

output "resource_group_name" {    # exposed result, visible after apply
  value = azurerm_resource_group.rg.name
}
```

---

## 5. A Full Azure Example Putting It All Together

```hcl
variable "project_name" {
  type    = string
  default = "Customer Portal"
}

variable "environment" {
  type    = string
  default = "prod"
}

locals {
  # 2.3 — transformed string
  clean_name = lower(replace(var.project_name, " ", "-"))

  # 2.8 — conditional
  is_prod  = var.environment == "prod"
  vm_size  = local.is_prod ? "Standard_D4s_v5" : "Standard_B2s"

  # 2.7 — function call (merge)
  tags = merge(
    { ManagedBy = "Terraform", Project = local.clean_name },
    { Environment = var.environment }
  )

  # 2.6 — chained local referencing other locals
  rg_name = "rg-${local.clean_name}-${var.environment}"
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = "eastus"
  tags     = local.tags
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${local.clean_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = local.vm_size
  tags                = local.tags
  # ... other required arguments
}

output "resource_group_name" {
  value = local.rg_name
}
```

Notice how `local.rg_name`, `local.tags`, and `local.vm_size` each get computed once and reused across two resources — if a third Azure resource showed up tomorrow needing the same tags or naming pattern, you'd just reference the same locals again, with zero repetition.

---

## 6. Common Beginner Mistakes With Locals

1. **Writing `locals.environment` instead of `local.environment`** when referencing a value. Remember: block = plural (`locals`), reference = singular (`local`).
2. **Treating locals like mutable variables.** A local is computed **once per `plan`/`apply` run** and stays fixed for that run — you can't "update" a local mid-deployment the way you'd reassign a variable in Python or JavaScript. Each Terraform run recalculates from scratch, top to bottom, based on current inputs.
3. **Circular references.** `local.a` referencing `local.b` while `local.b` references `local.a` will produce an error — Terraform can't determine which to calculate first.
4. **Renaming a local used in a resource's `name` or `for_each`.** If you rename a local that feeds directly into something like a resource name or a `for_each` key, Terraform may interpret it as "this is now a completely different resource" and propose destroying and recreating it. Be deliberate about which locals feed naming/keys.
5. **Over-abstracting.** Wrapping a single, never-reused literal value in a local just to "look organized" can actually make code *harder* to read, because now someone has to go hunt down where `local.thing` is defined instead of seeing the value right there. Use locals when a value is reused multiple times, or when an expression is genuinely complex enough to deserve its own name — not for every single line.

---

## 7. Deep Dive: `coalesce()`

### Explain it like you've never coded

Imagine you're trying to figure out what to call someone, and you have three possible sources, in order of trust: their nickname, their first name, or "Unknown" as an absolute last resort. You check the nickname first — got something? Use it, stop looking. Nickname's empty? Check the first name. Still nothing? Fall back to "Unknown."

`coalesce(value1, value2, value3, ...)` does exactly that: **it checks each argument left to right, and returns the very first one that isn't `null` and isn't an empty string.** If every single argument turns out to be null/empty, `coalesce()` throws an error — it refuses to silently return nothing.

```hcl
> coalesce(null, "", "backup-value")
"backup-value"

> coalesce("primary-value", "backup-value")
"primary-value"

> coalesce(null, "")
Error: all coalesce arguments are null or empty
```

### Why enterprises (and you) need this with Azure

Configuration in real organizations is **layered**: a team might want to override a platform default, but if they don't provide one, you fall back to the platform's standard. `coalesce()` is the textbook tool for this "layered override" pattern.

```hcl
variable "team_vm_size" {
  type    = string
  default = null   # the team didn't specify one
}

variable "environment_default_vm_size" {
  type    = string
  default = "Standard_B2s"   # the platform team's standard for this environment
}

locals {
  # Use the team's choice if they gave one; otherwise fall back to the platform default
  vm_size = coalesce(var.team_vm_size, var.environment_default_vm_size, "Standard_B1s")
}

resource "azurerm_linux_virtual_machine" "vm" {
  size = local.vm_size
  # ...
}
```

If `var.team_vm_size` is `null`, Terraform moves on and checks `var.environment_default_vm_size` — which has a real value, `"Standard_B2s"` — so that wins. The third argument, `"Standard_B1s"`, is a final safety net in case *both* upstream values somehow ended up null.

### An important gotcha with `coalesce()`

`coalesce()` requires all its arguments to be the **same type** (or types Terraform can automatically convert between consistently) — mixing, say, a string and a number can cause type errors. Also, since Terraform 1.3+, `coalesce()` treats `null` as "skip this one," but it does **not** treat the number `0`, or the boolean `false`, as "empty" — only `null` and `""` (empty string) get skipped. This catches people off guard: if you're using `coalesce()` expecting it to skip `0` like it skips an empty string, it won't — `0` is a perfectly valid value as far as `coalesce()` is concerned.

```hcl
> coalesce(0, 5)
0   # 0 is NOT treated as "empty" — it's returned immediately
```

---

## 8. Deep Dive: `try()`

### Explain it like you've never coded

Imagine you're reaching into a few different drawers, in order, hoping to find your keys. `try(expression1, expression2, expression3, ...)` evaluates each expression in order, and **the moment one of them succeeds without error, that's your answer** — anything after that, including any drawers that would have thrown an error, never even gets touched. If every single expression errors out, then `try()` itself errors out too.

```hcl
> try(local.does_not_exist, "fallback")
"fallback"
```

### The crucial difference between `try()` and `coalesce()`

This is the single most important distinction to understand, and it's exactly what you asked about:

- **`coalesce()`** checks whether values are **null or empty** — all the values must exist and be valid expressions; it's just deciding *which one* to use based on their content.
- **`try()`** checks whether an expression **would error out entirely** — like referencing an attribute that doesn't exist, dividing by zero, or indexing into a list at a position beyond its length. It's a safety net for expressions that might *crash*, not just be empty.

```hcl
# coalesce(): all values are VALID expressions, just choosing the non-empty one
coalesce(var.optional_name, "default-name")

# try(): the first expression might literally ERROR (e.g., index out of range)
try(azurerm_public_ip.vm[0].ip_address, "No public IP assigned")
```

If `azurerm_public_ip.vm` has zero instances (maybe it's conditionally created), then `azurerm_public_ip.vm[0]` would normally crash your entire `plan` with an "index out of range" error. Wrapping it in `try()` catches that crash and quietly falls back to `"No public IP assigned"` instead.

### Real Azure example: conditional resources

A very common Azure pattern is creating a public IP **only if a variable says so**:

```hcl
variable "create_public_ip" {
  type    = bool
  default = false
}

resource "azurerm_public_ip" "vm" {
  count               = var.create_public_ip ? 1 : 0
  name                = "pip-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

output "vm_public_ip" {
  # Without try(), this output would CRASH whenever create_public_ip = false,
  # because azurerm_public_ip.vm[0] simply wouldn't exist
  value = try(azurerm_public_ip.vm[0].ip_address, "No public IP assigned")
}
```

### Another real Azure example: safely reading optional nested data

```hcl
locals {
  # Imagine this comes from a jsondecode() of an external config file,
  # where the "backup" key might or might not be present
  app_config = jsondecode(file("${path.module}/config.json"))

  backup_retention_days = try(local.app_config.backup.retention_days, 7)
}
```

If `app_config` doesn't have a `backup` key at all, directly writing `local.app_config.backup.retention_days` would error out immediately ("attribute not found"). `try()` catches that and falls back to a sensible default of `7` days.

### Important limitation — what `try()` does NOT protect you from

`try()` only catches errors in **Terraform's own expression evaluation** (missing map keys, bad indexes, type mismatches). It does **not** catch real-world failures from the actual Azure API — if your credentials are wrong, your subscription has hit a quota, or Azure rejects a resource for a policy violation, `try()` won't rescue you from that; those are genuine deployment failures that need fixing, not values to silently fall back from.

---

## 9. Combining Everything: `locals` + `coalesce()` + `try()` in One Realistic Azure Module

```hcl
variable "team_tags" {
  type    = map(string)
  default = null
}

variable "create_public_ip" {
  type    = bool
  default = true
}

locals {
  # try(): safely read an optional external config file, fall back if missing
  external_config = try(jsondecode(file("${path.module}/team-config.json")), {})

  # coalesce(): layered fallback — team variable, then config file value, then hard default
  environment = coalesce(
    try(local.external_config.environment, null),
    "dev"
  )

  # locals chaining + functions: build the final, clean tag set
  base_tags = {
    ManagedBy   = "Terraform"
    Environment = local.environment
  }
  final_tags = merge(local.base_tags, coalesce(var.team_tags, {}))
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-app-${local.environment}"
  location = "eastus"
  tags     = local.final_tags
}

resource "azurerm_public_ip" "vm" {
  count               = var.create_public_ip ? 1 : 0
  name                = "pip-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

output "public_ip" {
  # try(): protects against the public IP not existing when create_public_ip = false
  value = try(azurerm_public_ip.vm[0].ip_address, "Not assigned")
}
```

Walk through the logic once more: `try()` first protects the optional config-file read from crashing if the file or key doesn't exist; `coalesce()` then picks the best available environment value from a chain of fallbacks; `locals` give every intermediate step (`base_tags`, `final_tags`, `environment`) a clean, reusable name; and a second `try()` at the very end protects the output from a conditionally-created resource that might not exist. This is genuinely how layered, production-grade Azure modules are written.

---

## 10. Quick Reference

| Concept | One-line summary |
|---|---|
| `locals { name = expr }` | Defines a named, reusable internal value/expression |
| `local.name` | References a previously defined local (singular keyword) |
| Scope | Locals are visible only within the module that defines them |
| Allowed values | Anything: literals, variables, resource/data attributes, other locals, function calls, conditionals, for-loops, nested objects |
| `coalesce(a, b, c)` | First non-null, non-empty **value** wins; errors if all are null/empty |
| `try(a, b, c)` | First expression that **doesn't error** wins; errors if all error |
| Locals vs variables | Locals = internal computation; variables = external input the caller controls |

---

## 11. Practice Plan

1. In `terraform console`, type `locals` blocks aren't directly testable there (console only evaluates expressions, not full configs) — so instead, build a tiny `main.tf` with 4-5 locals from section 2 (a string transform, a conditional, a merge, a for-loop) and run `terraform plan` repeatedly, tweaking the variable defaults each time to watch the locals recompute.
2. Take the section 9 example, deploy it (or `terraform plan` it) with `create_public_ip = true` and then `false`, and watch the `public_ip` output change correctly without erroring, thanks to `try()`.
3. Deliberately break `coalesce()` by passing only `null` and `""` arguments, and read the exact error Terraform gives you — recognizing that error instantly will save you real debugging time later.
4. Try replacing a `coalesce()` call with a `try()` call (or vice versa) in a scenario where it doesn't actually fit, and observe how the error messages differ — this cements the core distinction between "value is empty" (`coalesce`) and "expression would crash" (`try`).
